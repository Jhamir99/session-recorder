import Combine
import Foundation
import os

/// Coordinates capture, files, settings and the selected source (plan §5):
/// live level meters (RF-2), quality (RF-1) and the recording state machine (RF-3–RF-6).
@MainActor
final class RecordingViewModel: ObservableObject {
    @Published private(set) var state: RecordingState = .idle
    /// Elapsed time, file size and remaining time; updated every second while recording or paused (RF-4).
    @Published private(set) var liveInfo: RecordingLiveInfo = .zero
    @Published private(set) var notice: RecordingNotice?
    /// One level per recorded channel: mono 1, stereo left then right.
    @Published private(set) var levels: [ChannelLevel] = []
    /// Quality for the next (or current) recording on the selected device (RF-1).
    @Published private(set) var quality: RecordingQuality?
    @Published private(set) var offeredQualities: [RecordingQuality] = []
    /// Native capture format of the device (shown in debug builds only).
    @Published private(set) var nativeFormatDescription: String?

    let capture: AudioCaptureService
    private let fileStore: SessionFileStore
    private let settings: RecordingSettingsRepository
    private let logger = Logger(subsystem: "SessionRecorder", category: "Recording")
    private weak var audioSource: AudioSourceSelectionViewModel?
    private var lastClipDates: [Date?] = []
    /// Last hardware rate requested, to avoid asking again on every source change.
    private var appliedSampleRate: (deviceID: String, rate: Double)?
    private var cancellables: Set<AnyCancellable> = []

    // Current recording (nil while idle).
    private var writer: RecordingFileWriter?
    private var recordingStartDate: Date?
    private var liveInfoTask: Task<Void, Never>?

    init(
        capture: AudioCaptureService? = nil,
        fileStore: SessionFileStore? = nil,
        settings: RecordingSettingsRepository? = nil
    ) {
        self.capture = capture ?? AudioCaptureService()
        self.fileStore = fileStore ?? SessionFileStore()
        self.settings = settings ?? RecordingSettingsRepository()
        bindCapture()
    }

    /// Connects to the shared source selection; meters and quality follow it. Safe to call more than once.
    func attach(audioSource: AudioSourceSelectionViewModel) {
        guard self.audioSource !== audioSource else { return }
        self.audioSource = audioSource
        // objectWillChange fires before the change; receiving on the run loop reads the new values.
        audioSource.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.sourceDidChange() }
            .store(in: &cancellables)
        sourceDidChange()
    }

    // MARK: Availability (RF-3)

    /// Record button enabled: idle, valid source, permission granted.
    var canRecord: Bool {
        state == .idle && meteringSource != nil
    }

    /// Resume enabled while paused (device connection is checked with interruptions, T12).
    var canResume: Bool {
        RecordingLogic.canResume(state: state, isRecordingDeviceConnected: true)
    }

    // MARK: Quality (RF-1)

    func selectQuality(_ newQuality: RecordingQuality) {
        guard !state.hasActiveRecording, offeredQualities.contains(newQuality),
              let deviceID = audioSource?.selectedDeviceID else { return }
        quality = newQuality
        settings.saveQuality(newQuality, for: deviceID)
        applySampleRate()
    }

    private func updateQuality() {
        guard let device = audioSource?.selectedDevice else {
            offeredQualities = []
            quality = nil
            return
        }
        offeredQualities = RecordingLogic.offeredQualities(deviceSupportedRates: device.supportedSampleRates)
        quality = RecordingLogic.resolveQuality(saved: settings.quality(for: device.id), offered: offeredQualities)
        applySampleRate()
    }

    /// Runs the device at the quality's rate so the recording is not resampled (when the device supports it).
    private func applySampleRate() {
        guard let audioSource, let device = audioSource.selectedDevice, let quality,
              device.supportedSampleRates.contains(where: { abs($0 - quality.sampleRate) < 1 }) else { return }
        if let appliedSampleRate, appliedSampleRate.deviceID == device.id, appliedSampleRate.rate == quality.sampleRate {
            return
        }
        appliedSampleRate = (device.id, quality.sampleRate)
        audioSource.service.preferSampleRate(quality.sampleRate, deviceID: device.id)
    }

    // MARK: Recording (RF-3–RF-6)

    func startRecording() {
        guard state == .idle else { return }
        notice = nil
        let source = meteringSource
        let channelCount = source?.channelNumbers.count ?? 0
        let remaining = quality.map {
            RecordingLogic.remainingSeconds(
                freeBytes: fileStore.freeBytes(),
                bytesPerSecond: RecordingLogic.bytesPerSecond(quality: $0, channelCount: max(channelCount, 1))
            )
        } ?? 0
        if let error = RecordingLogic.startError(
            permission: audioSource?.permissionState ?? .unknown,
            hasValidSource: source != nil && quality != nil,
            remainingSeconds: remaining
        ) {
            notice = RecordingNotice(kind: .startFailed(error))
            return
        }
        guard let quality, capture.isRunning else {
            notice = RecordingNotice(kind: .startFailed(.deviceUnavailable))
            return
        }

        let startDate = Date()
        let writer: RecordingFileWriter
        do {
            writer = try fileStore.createRecording(startDate: startDate, quality: quality, channelCount: channelCount)
        } catch {
            logger.error("Cannot create recording file: \(error.localizedDescription, privacy: .public)")
            notice = RecordingNotice(kind: .startFailed(.cannotCreateFile))
            return
        }

        self.writer = writer
        recordingStartDate = startDate
        capture.startWriting(to: writer)
        state = .recording
        audioSource?.isSourceLocked = true
        updateLiveInfo()
        startLiveInfoUpdates()
    }

    func pauseRecording() {
        guard state == .recording else { return }
        capture.setWritingPaused(true)
        state = .paused(.user)
    }

    func resumeRecording() {
        guard canResume else { return }
        capture.setWritingPaused(false)
        state = .recording
    }

    /// Finishes the file and saves the session with a date-based name (RF-6).
    func stopRecording() {
        guard state.hasActiveRecording, let writer, let startDate = recordingStartDate else { return }
        capture.stopWriting()
        writer.close()
        liveInfoTask?.cancel()
        liveInfoTask = nil

        do {
            if let name = try fileStore.finishRecording(at: writer.url, startDate: startDate, hasAudio: writer.framesWritten > 0) {
                notice = RecordingNotice(kind: .saved(sessionName: name))
            }
        } catch {
            // The file stays in progress and is recovered on next launch (RF-8), so nothing is lost.
            logger.error("Cannot save session: \(error.localizedDescription, privacy: .public)")
        }

        self.writer = nil
        recordingStartDate = nil
        state = .idle
        liveInfo = .zero
        audioSource?.isSourceLocked = false
        // Source changes were ignored while recording; apply the current source now.
        sourceDidChange()
    }

    func dismissNotice() {
        notice = nil
    }

    // MARK: Live info (RF-4)

    private func startLiveInfoUpdates() {
        liveInfoTask?.cancel()
        liveInfoTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.updateLiveInfo()
            }
        }
    }

    private func updateLiveInfo() {
        guard let writer else { return }
        let bytesPerSecond = RecordingLogic.bytesPerSecond(quality: writer.quality, channelCount: writer.channelCount)
        liveInfo = RecordingLiveInfo(
            elapsedSeconds: writer.elapsedSeconds,
            fileSizeBytes: writer.fileSizeBytes,
            remainingSeconds: RecordingLogic.remainingSeconds(freeBytes: fileStore.freeBytes(), bytesPerSecond: bytesPerSecond)
        )
    }

    // MARK: Source and meters (RF-2)

    /// Device ID and channel numbers (selection order) of a valid, permitted source; nil otherwise.
    private var meteringSource: (deviceID: String, channelNumbers: [Int])? {
        guard let audioSource, let deviceID = audioSource.selectedDeviceID,
              case .selected(_, _, let channelNumbers) = audioSource.sourceSummary,
              !channelNumbers.isEmpty else { return nil }
        return (deviceID, channelNumbers)
    }

    private func sourceDidChange() {
        // The source is locked while recording; capture keeps the recording device and channels.
        guard !state.hasActiveRecording else { return }
        updateQuality()
        updateMetering()
    }

    private func updateMetering() {
        guard let source = meteringSource else {
            capture.stop()
            return
        }
        do {
            try capture.start(deviceID: source.deviceID, channelNumbers: source.channelNumbers)
        } catch {
            logger.error("Cannot start level meters: \(String(describing: error), privacy: .public)")
            capture.stop()
        }
    }

    private func bindCapture() {
        capture.$peaks
            .sink { [weak self] peaks in self?.updateLevels(peaks: peaks) }
            .store(in: &cancellables)
        capture.$nativeFormatDescription
            .sink { [weak self] format in self?.nativeFormatDescription = format }
            .store(in: &cancellables)
    }

    private func updateLevels(peaks: [Float], now: Date = Date()) {
        if lastClipDates.count != peaks.count {
            lastClipDates = Array(repeating: nil, count: peaks.count)
        }
        levels = peaks.enumerated().map { index, peak in
            if RecordingLogic.isClipping(peak: peak) {
                lastClipDates[index] = now
            }
            return ChannelLevel(
                peak: peak,
                isClipping: RecordingLogic.isClipIndicatorVisible(lastClipDate: lastClipDates[index], now: now)
            )
        }
    }
}
