import Accelerate
import AVFoundation
import Combine
import os

/// Apple-API boundary for audio capture (plan §3): captures the selected device, extracts the selected
/// channels, publishes their peak levels and, while recording, writes them to a file (RF-3, RF-5).
/// - macOS: `AVCaptureSession` on the selected device (Float32 non-interleaved).
/// - iOS: `AVAudioEngine` input tap; the input is the device routed by `AudioInputDeviceService`.
@MainActor
final class AudioCaptureService: ObservableObject {
    /// Linear peak per selected channel (0...1), in selection order (mono: 1, stereo: left, right).
    @Published private(set) var peaks: [Float] = []
    @Published private(set) var isRunning = false
    /// Format delivered to the app, e.g. `48000 Hz · 10 ch · Float32 non-interleaved` (debug line).
    @Published private(set) var nativeFormatDescription: String?
    /// iOS: a call or another app took the audio input; capture resumes when the interruption ends.
    @Published private(set) var isInterrupted = false

    /// Events that affect a recording (RF-8). Writing is already paused or stopped when they arrive.
    enum Event {
        /// The capture device disconnected.
        case deviceDisconnected
        /// iOS: a call or another app took the audio input.
        case interruptionBegan
        /// Writing or capture failed; nothing more is written.
        case failed(String)
    }
    let events = PassthroughSubject<Event, Never>()

    enum StartError: Error {
        case deviceUnavailable
        case cannotAddInput
        case cannotAddOutput
    }

    private let logger = Logger(subsystem: "SessionRecorder", category: "AudioCapture")
    /// Starting/stopping capture can block, so it never runs on the main thread.
    private let processingQueue = DispatchQueue(label: "SessionRecorder.AudioCapture", qos: .userInteractive)
    private var processor: CaptureSampleProcessor?
    private var current: (deviceID: String, channelNumbers: [Int])?
    /// Processor and device readable from notification threads, so writing pauses without waiting
    /// for the main thread (no audio from another input gets into the file).
    nonisolated private let active = OSAllocatedUnfairLock<(processor: CaptureSampleProcessor, deviceID: String)?>(initialState: nil)
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    #if os(iOS)
    private var engine: AVAudioEngine?
    private var configurationObserver: NSObjectProtocol?
    #else
    private var session: AVCaptureSession?
    #endif

    init() {
        observeInterruptions()
    }

    deinit {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
    }

    /// Starts capturing `channelNumbers` (1-based, selection order) of the device with `deviceID`.
    /// Does nothing if the same device and channels are already running.
    func start(deviceID: String, channelNumbers: [Int]) throws {
        if isRunning, let current, current.deviceID == deviceID, current.channelNumbers == channelNumbers {
            return
        }
        stop()

        let processor = CaptureSampleProcessor(
            channelIndexes: channelNumbers.map { $0 - 1 },
            onUpdate: { [weak self] update in
                Task { @MainActor [weak self] in
                    self?.apply(update)
                }
            },
            onWriteError: { [weak self] description in
                Task { @MainActor [weak self] in
                    self?.logger.error("Recording write failed: \(description, privacy: .public)")
                    self?.events.send(.failed(description))
                }
            }
        )
        #if os(iOS)
        try startEngine(processor: processor)
        #else
        try startCaptureSession(deviceID: deviceID, processor: processor)
        #endif

        self.processor = processor
        current = (deviceID, channelNumbers)
        active.withLock { $0 = (processor, deviceID) }
        peaks = Array(repeating: 0, count: channelNumbers.count)
        nativeFormatDescription = nil
        isRunning = true
    }

    // MARK: Writing (RF-3, RF-5)

    /// Starts writing the selected channels to `writer`, converted to its quality. Capture must be running.
    func startWriting(to writer: RecordingFileWriter) {
        processor?.setWriter(writer)
    }

    /// Paused: capture and meters keep running, nothing is written; resuming continues in the same file.
    func setWritingPaused(_ paused: Bool) {
        processor?.setWritingPaused(paused)
    }

    /// When this returns no write is in progress or will happen, so the file can be closed.
    func stopWriting() {
        processor?.setWriter(nil)
    }

    func stop() {
        active.withLock { $0 = nil }
        processor?.setWriter(nil)
        #if os(iOS)
        stopEngine()
        #else
        stopCaptureSession()
        #endif
        processor = nil
        current = nil
        isRunning = false
        peaks = []
    }

    /// Restarts capture of the same device and channels, keeping the writer (device reconnected,
    /// interruption ended). The paused state of writing is not changed.
    func restartCapture() {
        guard let processor, let current else { return }
        #if os(iOS)
        if let engine { runEngine(engine, processor: processor) }
        #else
        stopCaptureSession()
        do {
            try startCaptureSession(deviceID: current.deviceID, processor: processor)
        } catch {
            logger.error("Cannot restart capture: \(String(describing: error), privacy: .public)")
        }
        #endif
    }

    // MARK: Interruptions (RF-8)

    /// Pauses writing right away (on the notification thread) and reports the event on the main actor.
    nonisolated private func pauseWriting(andSend event: Event) {
        active.withLock { $0?.processor }?.setWritingPaused(true)
        Task { @MainActor [weak self] in
            self?.events.send(event)
        }
    }

    private func observeInterruptions() {
        let center = NotificationCenter.default
        #if os(iOS)
        // The recording device left the route (iOS falls back to another input, e.g. the built-in mic).
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) {
            [weak self] notification in
            guard let self,
                  let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable,
                  let deviceID = active.withLock({ $0?.deviceID }),
                  let previous = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
                  previous.inputs.contains(where: { $0.uid == deviceID }),
                  !AVAudioSession.sharedInstance().currentRoute.inputs.contains(where: { $0.uid == deviceID })
            else { return }
            pauseWriting(andSend: .deviceDisconnected)
        })
        // A call or another app took the audio input: the system deactivates the session (iOS 27 API,
        // replaces the interruption notification). Deactivations requested by the app are ignored.
        observers.append(center.addObserver(forName: AVAudioSession.didBecomeInactiveNotification, object: nil, queue: nil) {
            [weak self] notification in
            guard let self,
                  let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
                  context.source == .system else { return }
            pauseWriting(andSend: .interruptionBegan)
            Task { @MainActor [weak self] in self?.isInterrupted = true }
        })
        // The interruption ended (with or without a recommendation to resume): meters come back, but the
        // recording stays paused until the user resumes (RF-8).
        observers.append(center.addObserver(forName: AVAudioSession.resumptionRecommendationNotification, object: nil, queue: nil) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, isInterrupted else { return }
                isInterrupted = false
                restartCapture()
            }
        })
        #else
        observers.append(center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: nil) {
            [weak self] notification in
            guard let self, let device = notification.object as? AVCaptureDevice,
                  device.uniqueID == active.withLock({ $0?.deviceID }) else { return }
            pauseWriting(andSend: .deviceDisconnected)
        })
        // Runtime errors with the device still connected stop the recording (a disconnect is handled above).
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: nil, queue: nil) {
            [weak self] notification in
            guard let self, let deviceID = active.withLock({ $0?.deviceID }),
                  AVCaptureDevice(uniqueID: deviceID)?.isConnected == true else { return }
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
            let description = error?.localizedDescription ?? "Capture error"
            active.withLock { $0?.processor }?.setWriter(nil)
            Task { @MainActor [weak self] in
                self?.logger.error("Capture failed: \(description, privacy: .public)")
                self?.events.send(.failed(description))
            }
        })
        #endif
    }

    private func apply(_ update: CaptureSampleProcessor.Update) {
        guard isRunning else { return }
        if let format = update.nativeFormatDescription, format != nativeFormatDescription {
            nativeFormatDescription = format
            logger.notice("Capture format: \(format, privacy: .public)")
        }
        peaks = update.peaks
    }

    #if os(iOS)
    // MARK: iOS — AVAudioEngine

    /// All engine work (tap, start, restart, stop) runs on `processingQueue`, so a configuration change
    /// never races with a start/stop, and the tap is only installed while the engine is stopped
    /// (installing it with a stale hardware format raises an exception).
    private func startEngine(processor: CaptureSampleProcessor) throws {
        let engine = AVAudioEngine()
        // A route, rate or channel-count change stops the engine; restart it with the new input format.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] notification in
            nonisolated(unsafe) let changedEngine = notification.object as AnyObject?
            Task { @MainActor [weak self] in
                guard let self, let current = self.engine, current === changedEngine else { return }
                self.runEngine(current, processor: processor)
            }
        }
        self.engine = engine
        runEngine(engine, processor: processor)
    }

    /// (Re)installs the tap with the current hardware format and starts the engine, on the processing queue.
    private func runEngine(_ engine: AVAudioEngine, processor: CaptureSampleProcessor) {
        // AVAudioEngine is Sendable, so it can be used on the processing queue directly.
        let runningEngine = engine
        let logger = self.logger
        processingQueue.async {
            // After an interruption the session is inactive; activating an active session does nothing.
            try? AVAudioSession.sharedInstance().setActive(true)
            runningEngine.stop()
            let input = runningEngine.inputNode
            input.removeTap(onBus: 0)
            let format = input.inputFormat(forBus: 0)
            guard format.channelCount > 0, format.sampleRate > 0 else {
                logger.error("No audio input available for the engine")
                return
            }
            // Deprecated in iOS 27 in favor of the throwing variant, which this SDK only exposes to Swift as
            // the internal `__installTap`; keep this until Apple ships the Swift wrapper.
            input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
                processor.process(buffer)
            }
            runningEngine.prepare()
            do {
                try runningEngine.start()
            } catch {
                logger.error("Cannot start audio engine: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func stopEngine() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        guard let engine else { return }
        let stoppingEngine = engine
        processingQueue.async {
            stoppingEngine.stop()
            stoppingEngine.inputNode.removeTap(onBus: 0)
        }
        self.engine = nil
    }
    #else
    // MARK: macOS — AVCaptureSession

    private func startCaptureSession(deviceID: String, processor: CaptureSampleProcessor) throws {
        guard let device = AVCaptureDevice(uniqueID: deviceID) else { throw StartError.deviceUnavailable }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            logger.error("Cannot open device: \(error.localizedDescription, privacy: .public)")
            throw StartError.deviceUnavailable
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw StartError.cannotAddInput
        }
        session.addInput(input)

        let output = AVCaptureAudioDataOutput()
        // macOS can deliver Float32 non-interleaved directly at the device rate (no conversion needed).
        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: true
        ]
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw StartError.cannotAddOutput
        }
        session.addOutput(output)
        session.commitConfiguration()
        output.setSampleBufferDelegate(processor, queue: processingQueue)

        self.session = session
        // AVCaptureSession is designed to be started/stopped from a background queue.
        nonisolated(unsafe) let runningSession = session
        processingQueue.async {
            runningSession.startRunning()
        }
    }

    private func stopCaptureSession() {
        guard let session else { return }
        let processor = self.processor
        nonisolated(unsafe) let stoppingSession = session
        processingQueue.async {
            stoppingSession.stopRunning()
            _ = processor // keep the delegate alive until the session has stopped
        }
        self.session = nil
    }
    #endif
}

/// Runs off the main actor (capture queue or engine tap thread): gets Float32 non-interleaved buffers,
/// extracts the selected channels and reports peaks about 30 times per second.
nonisolated final class CaptureSampleProcessor: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    struct Update: Sendable {
        let peaks: [Float]
        /// Set on the first buffer and whenever the native format changes.
        let nativeFormatDescription: String?
    }

    private let channelIndexes: [Int]
    private let onUpdate: @Sendable (Update) -> Void
    private let onWriteError: @Sendable (String) -> Void
    private let reportInterval: TimeInterval = 1.0 / 30
    private var pendingPeaks: [Float]
    private var lastReport = Date.distantPast
    private var lastNativeFormat: AVAudioFormat?
    private var converter: AVAudioConverter?

    // Writing state: set from the main actor, used on the capture thread; guarded by `writeLock`.
    private let writeLock = NSLock()
    private var writer: RecordingFileWriter?
    private var isWritingPaused = false
    private var sampleRateConverter: AVAudioConverter?

    init(
        channelIndexes: [Int],
        onUpdate: @escaping @Sendable (Update) -> Void,
        onWriteError: @escaping @Sendable (String) -> Void
    ) {
        self.channelIndexes = channelIndexes
        self.onUpdate = onUpdate
        self.onWriteError = onWriteError
        self.pendingPeaks = Array(repeating: 0, count: channelIndexes.count)
    }

    /// macOS path: sample buffers from `AVCaptureAudioDataOutput`.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = Self.floatBuffer(from: sampleBuffer, converter: &converter, lastFormat: &lastNativeFormat) else { return }
        accumulate(buffer.pcm, formatChanged: buffer.formatChanged)
        write(buffer.pcm)
    }

    /// iOS path: buffers from the `AVAudioEngine` input tap (already Float32 non-interleaved).
    func process(_ buffer: AVAudioPCMBuffer) {
        let formatChanged = lastNativeFormat != buffer.format
        if formatChanged {
            lastNativeFormat = buffer.format
        }
        accumulate(buffer, formatChanged: formatChanged)
        write(buffer)
    }

    // MARK: Writing

    func setWriter(_ writer: RecordingFileWriter?) {
        writeLock.withLock {
            self.writer = writer
            isWritingPaused = false
            sampleRateConverter = nil
        }
    }

    func setWritingPaused(_ paused: Bool) {
        writeLock.withLock {
            isWritingPaused = paused
            // Do not carry resampler state across the pause.
            if !paused { sampleRateConverter?.reset() }
        }
    }

    /// Holding the lock while writing makes `setWriter(nil)` wait for an in-flight write.
    private func write(_ buffer: AVAudioPCMBuffer) {
        writeLock.withLock {
            guard let writer, !isWritingPaused else { return }
            do {
                let output = try recordingBuffer(from: buffer, targetFormat: writer.processingFormat)
                try writer.write(output)
            } catch {
                self.writer = nil
                onWriteError(String(describing: error))
            }
        }
    }

    enum WriteError: Error {
        case cannotCreateBuffer
        case conversionFailed
    }

    /// Selected channels (selection order) at the recording format; resampled only when the device rate differs.
    private func recordingBuffer(from buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let sameRate = buffer.format.sampleRate == targetFormat.sampleRate
        guard let selectedFormat = sameRate
                ? targetFormat
                : AVAudioFormat(standardFormatWithSampleRate: buffer.format.sampleRate, channels: targetFormat.channelCount),
              let selected = AVAudioPCMBuffer(pcmFormat: selectedFormat, frameCapacity: buffer.frameLength),
              let source = buffer.floatChannelData, let destination = selected.floatChannelData,
              !buffer.format.isInterleaved else { throw WriteError.cannotCreateBuffer }

        selected.frameLength = buffer.frameLength
        let frameCount = Int(buffer.frameLength)
        let available = Int(buffer.format.channelCount)
        for (position, index) in channelIndexes.enumerated() where position < Int(selectedFormat.channelCount) {
            if index < available {
                destination[position].update(from: source[index], count: frameCount)
            } else {
                destination[position].update(repeating: 0, count: frameCount)
            }
        }
        if sameRate { return selected }

        if sampleRateConverter == nil || sampleRateConverter?.inputFormat != selectedFormat {
            sampleRateConverter = AVAudioConverter(from: selectedFormat, to: targetFormat)
        }
        let ratio = targetFormat.sampleRate / selectedFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(selected.frameLength) * ratio).rounded(.up)) + 32
        guard let sampleRateConverter,
              let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            throw WriteError.conversionFailed
        }
        var supplied = false
        var conversionError: NSError?
        let status = sampleRateConverter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return selected
        }
        if status == .error { throw conversionError ?? WriteError.conversionFailed }
        return output
    }

    private func accumulate(_ buffer: AVAudioPCMBuffer, formatChanged: Bool) {
        let frameCount = Int(buffer.frameLength)
        if let channels = buffer.floatChannelData, !buffer.format.isInterleaved {
            let available = Int(buffer.format.channelCount)
            for (position, index) in channelIndexes.enumerated() where index < available {
                // Vectorized max |sample| (a per-sample Swift loop was the app's main CPU cost while idle).
                var peak: Float = 0
                vDSP_maxmgv(channels[index], 1, &peak, vDSP_Length(frameCount))
                pendingPeaks[position] = max(pendingPeaks[position], peak)
            }
        }

        let now = Date()
        guard formatChanged || now.timeIntervalSince(lastReport) >= reportInterval else { return }
        onUpdate(Update(
            peaks: pendingPeaks,
            nativeFormatDescription: formatChanged ? lastNativeFormat.map(Self.describe) : nil
        ))
        pendingPeaks = Array(repeating: 0, count: channelIndexes.count)
        lastReport = now
    }

    /// Copies the sample buffer into an `AVAudioPCMBuffer` and converts it to Float32 non-interleaved
    /// at the native sample rate when needed.
    private static func floatBuffer(
        from sampleBuffer: CMSampleBuffer,
        converter: inout AVAudioConverter?,
        lastFormat: inout AVAudioFormat?
    ) -> (pcm: AVAudioPCMBuffer, formatChanged: Bool)? {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              var streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee else { return nil }

        // Reuse the format while the device format is unchanged (avoids allocating per buffer).
        let formatChanged = lastFormat.map { !Self.isSameStream($0.streamDescription.pointee, streamDescription) } ?? true
        if formatChanged {
            // Not AVAudioFormat(cmAudioFormatDescription:): for more than 2 channels without a channel
            // layout it returns nil despite its non-optional signature, which crashes on first use.
            guard let format = Self.makeFormat(&streamDescription) else { return nil }
            lastFormat = format
            converter = nil
        }
        guard let nativeFormat = lastFormat else { return nil }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frameCount > 0,
              let nativeBuffer = AVAudioPCMBuffer(pcmFormat: nativeFormat, frameCapacity: frameCount) else { return nil }
        nativeBuffer.frameLength = frameCount
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: nativeBuffer.mutableAudioBufferList
        )
        guard status == noErr else { return nil }

        if nativeFormat.commonFormat == .pcmFormatFloat32, !nativeFormat.isInterleaved {
            return (nativeBuffer, formatChanged)
        }

        // More than 2 channels needs the channel layout, otherwise the format is nil.
        let floatFormat: AVAudioFormat? = if let layout = nativeFormat.channelLayout {
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: nativeFormat.sampleRate, interleaved: false, channelLayout: layout)
        } else {
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: nativeFormat.sampleRate, channels: nativeFormat.channelCount, interleaved: false)
        }
        guard let floatFormat else { return nil }
        if converter == nil {
            converter = AVAudioConverter(from: nativeFormat, to: floatFormat)
        }
        guard let converter,
              let floatBuffer = AVAudioPCMBuffer(pcmFormat: floatFormat, frameCapacity: frameCount) else { return nil }
        do {
            try converter.convert(to: floatBuffer, from: nativeBuffer)
        } catch {
            return nil
        }
        return (floatBuffer, formatChanged)
    }

    /// Builds a PCM format; devices with more than 2 channels get a discrete (unnamed) channel layout.
    private static func makeFormat(_ streamDescription: inout AudioStreamBasicDescription) -> AVAudioFormat? {
        let channelCount = streamDescription.mChannelsPerFrame
        guard channelCount > 0 else { return nil }
        if channelCount <= 2 {
            return AVAudioFormat(streamDescription: &streamDescription)
        }
        guard let layout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | channelCount) else {
            return nil
        }
        return AVAudioFormat(streamDescription: &streamDescription, channelLayout: layout)
    }

    private static func isSameStream(_ lhs: AudioStreamBasicDescription, _ rhs: AudioStreamBasicDescription) -> Bool {
        lhs.mSampleRate == rhs.mSampleRate
            && lhs.mFormatID == rhs.mFormatID
            && lhs.mFormatFlags == rhs.mFormatFlags
            && lhs.mBytesPerFrame == rhs.mBytesPerFrame
            && lhs.mChannelsPerFrame == rhs.mChannelsPerFrame
            && lhs.mBitsPerChannel == rhs.mBitsPerChannel
    }

    private static func describe(_ format: AVAudioFormat) -> String {
        let sampleType: String
        switch format.commonFormat {
        case .pcmFormatFloat32: sampleType = "Float32"
        case .pcmFormatFloat64: sampleType = "Float64"
        case .pcmFormatInt16: sampleType = "Int16"
        case .pcmFormatInt32: sampleType = "Int32"
        default: sampleType = "\(format.streamDescription.pointee.mBitsPerChannel)-bit other"
        }
        let layout = format.isInterleaved ? "interleaved" : "non-interleaved"
        return "\(Int(format.sampleRate)) Hz · \(format.channelCount) ch · \(sampleType) \(layout)"
    }
}
