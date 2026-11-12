import AVFoundation
import Combine
import os

/// Apple-API boundary for audio capture (plan §3): captures the selected device, extracts the selected
/// channels and publishes their peak levels. Writing to a file is added in T7.
/// - macOS: `AVCaptureSession` on the selected device (Float32 non-interleaved).
/// - iOS: `AVAudioEngine` input tap; the input is the device routed by `AudioInputDeviceService`.
@MainActor
final class AudioCaptureService: ObservableObject {
    /// Linear peak per selected channel (0...1), in selection order (mono: 1, stereo: left, right).
    @Published private(set) var peaks: [Float] = []
    @Published private(set) var isRunning = false
    /// Format delivered to the app, e.g. `48000 Hz · 10 ch · Float32 non-interleaved` (debug line).
    @Published private(set) var nativeFormatDescription: String?

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
    #if os(iOS)
    private var engine: AVAudioEngine?
    private var configurationObserver: NSObjectProtocol?
    #else
    private var session: AVCaptureSession?
    #endif

    /// Starts capturing `channelNumbers` (1-based, selection order) of the device with `deviceID`.
    /// Does nothing if the same device and channels are already running.
    func start(deviceID: String, channelNumbers: [Int]) throws {
        if isRunning, let current, current.deviceID == deviceID, current.channelNumbers == channelNumbers {
            return
        }
        stop()

        let processor = CaptureSampleProcessor(channelIndexes: channelNumbers.map { $0 - 1 }) { [weak self] update in
            Task { @MainActor [weak self] in
                self?.apply(update)
            }
        }
        #if os(iOS)
        try startEngine(processor: processor)
        #else
        try startCaptureSession(deviceID: deviceID, processor: processor)
        #endif

        self.processor = processor
        current = (deviceID, channelNumbers)
        peaks = Array(repeating: 0, count: channelNumbers.count)
        nativeFormatDescription = nil
        isRunning = true
    }

    func stop() {
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

    private func startEngine(processor: CaptureSampleProcessor) throws {
        let engine = AVAudioEngine()
        guard installTap(on: engine, processor: processor) else { throw StartError.deviceUnavailable }

        // A route or channel-count change stops the engine; restart it with the new input format.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.restartEngineAfterConfigurationChange()
            }
        }
        self.engine = engine
        runEngine(engine)
    }

    /// Installs the input tap with the current hardware format; false when there is no usable input.
    private func installTap(on engine: AVAudioEngine, processor: CaptureSampleProcessor) -> Bool {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            logger.error("No audio input available for the engine")
            return false
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            processor.process(buffer)
        }
        return true
    }

    private func runEngine(_ engine: AVAudioEngine) {
        nonisolated(unsafe) let runningEngine = engine
        let logger = self.logger
        processingQueue.async {
            runningEngine.prepare()
            do {
                try runningEngine.start()
            } catch {
                logger.error("Cannot start audio engine: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func restartEngineAfterConfigurationChange() {
        guard let engine, let processor else { return }
        engine.inputNode.removeTap(onBus: 0)
        guard installTap(on: engine, processor: processor) else { return }
        runEngine(engine)
    }

    private func stopEngine() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        guard let engine else { return }
        nonisolated(unsafe) let stoppingEngine = engine
        processingQueue.async {
            stoppingEngine.inputNode.removeTap(onBus: 0)
            stoppingEngine.stop()
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
    private let reportInterval: TimeInterval = 1.0 / 30
    private var pendingPeaks: [Float]
    private var lastReport = Date.distantPast
    private var lastNativeFormat: AVAudioFormat?
    private var converter: AVAudioConverter?

    init(channelIndexes: [Int], onUpdate: @escaping @Sendable (Update) -> Void) {
        self.channelIndexes = channelIndexes
        self.onUpdate = onUpdate
        self.pendingPeaks = Array(repeating: 0, count: channelIndexes.count)
    }

    /// macOS path: sample buffers from `AVCaptureAudioDataOutput`.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = Self.floatBuffer(from: sampleBuffer, converter: &converter, lastFormat: &lastNativeFormat) else { return }
        accumulate(buffer.pcm, formatChanged: buffer.formatChanged)
    }

    /// iOS path: buffers from the `AVAudioEngine` input tap (already Float32 non-interleaved).
    func process(_ buffer: AVAudioPCMBuffer) {
        let formatChanged = lastNativeFormat != buffer.format
        if formatChanged {
            lastNativeFormat = buffer.format
        }
        accumulate(buffer, formatChanged: formatChanged)
    }

    private func accumulate(_ buffer: AVAudioPCMBuffer, formatChanged: Bool) {
        let frameCount = Int(buffer.frameLength)
        if let channels = buffer.floatChannelData, !buffer.format.isInterleaved {
            let available = Int(buffer.format.channelCount)
            for (position, index) in channelIndexes.enumerated() where index < available {
                var peak: Float = 0
                let samples = channels[index]
                for frame in 0..<frameCount {
                    peak = max(peak, abs(samples[frame]))
                }
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
