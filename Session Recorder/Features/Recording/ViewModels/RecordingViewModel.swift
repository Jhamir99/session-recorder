import Combine
import Foundation
import os

/// Live meter levels (~30 updates per second). Kept out of `RecordingViewModel` so views observing it
/// (Record tab, source sheet with open menus) are not rebuilt on every level update; only the meters observe this.
@MainActor
final class LevelMeterModel: ObservableObject {
    /// One level per recorded channel: mono 1, stereo left then right.
    @Published fileprivate(set) var levels: [ChannelLevel] = []
}

/// Coordinates capture, files, settings and the selected source (plan §5):
/// live level meters (RF-2), quality (RF-1) and the recording state machine (RF-3–RF-6).
@MainActor
final class RecordingViewModel: ObservableObject {
    @Published private(set) var state: RecordingState = .idle
    /// Elapsed time, file size and remaining time; updated every second while recording or paused (RF-4).
    @Published private(set) var liveInfo: RecordingLiveInfo = .zero
    @Published private(set) var notice: RecordingNotice?
    /// Live levels for the meters (observed only by the meter view).
    let meters = LevelMeterModel()
    /// Sends the name of each session saved or recovered, so the session library can refresh.
    let sessionSaved = PassthroughSubject<String, Never>()
    /// Number of metered channels (0 when meters are hidden); changes only when the source changes.
    @Published private(set) var meteredChannelCount = 0
    /// Quality for the next (or current) recording on the selected device (RF-1).
    @Published private(set) var quality: RecordingQuality?
    @Published private(set) var offeredQualities: [RecordingQuality] = []
    /// iPhone/iPad: tip to turn on Do Not Disturb, shown during recordings until dismissed once (RF-3).
    @Published private(set) var showsDoNotDisturbTip = false
    /// The session library is playing (library RF-2): idle meters stop and Record is unavailable.
    @Published private(set) var isPlaybackActive = false
    /// iOS: a call or another app has the audio input (RF-8); recording and resuming wait for it to end.
    @Published private(set) var isInputInterrupted = false
    /// Native capture format of the device (shown in debug builds only).
    @Published private(set) var nativeFormatDescription: String?

    let capture: AudioCaptureService
    let fileStore: SessionFileStore
    private let settings: RecordingSettingsRepository
    private let logger = Logger(subsystem: "SessionRecorder", category: "Recording")
    private(set) weak var audioSource: AudioSourceSelectionViewModel?
    private var lastClipDates: [Date?] = []
    /// Last hardware rate requested, to avoid asking again on every source change.
    private var appliedSampleRate: (deviceID: String, rate: Double)?
    private var cancellables: Set<AnyCancellable> = []
    /// Recovery of interrupted recordings already ran in this process (RF-8).
    static var hasRecoveredInterruptedRecordings = false

    // Current recording (nil while idle).
    private var writer: RecordingFileWriter?
    private var recordingStartDate: Date?
    /// Device being recorded; the source stays locked to it until stop (RF-8).
    private(set) var recordingDeviceID: String?
    /// Device name for notices (the device is no longer listed once it disconnects).
    private(set) var recordingDeviceName: String?
    /// The recording device disconnected; capture restarts when it reconnects (see +Interruptions).
    var isWaitingForDeviceReconnect = false
    /// The ~10 min low-storage warning is shown once per recording (RF-8).
    var isLowStorageWarningShown = false
    private var liveInfoTask: Task<Void, Never>?
    /// Previews only: display state is set directly; no capture, files or source observation.
    private var isPreview = false
    /// Previews only: whether Resume is possible (replaces the device/interruption check).
    private var previewCanResume = false
    /// False while the app is in the background; idle meters stop then to save battery (NFR-6).
    private var isAppInForeground = true
    #if os(macOS)
    /// Keeps the Mac from idle-sleeping while a recording exists (RF-7).
    private var sleepPreventionActivity: NSObjectProtocol?
    #endif

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
        if isPreview {
            self.audioSource = audioSource
            return
        }
        recoverInterruptedRecordingsOnce()
        self.audioSource = audioSource
        // objectWillChange fires before the change; receiving on the run loop reads the new values.
        audioSource.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.sourceDidChange() }
            .store(in: &cancellables)
        sourceDidChange()
    }

    /// Library playback starts/ends: capture stops so the audio session can switch to playback, and
    /// restarts afterwards. Never called while a recording exists (playback is disabled then).
    func setPlaybackActive(_ active: Bool) {
        guard isPlaybackActive != active else { return }
        isPlaybackActive = active
        sourceDidChange()
    }

    /// Recording continues in the background (iOS background audio mode); idle meters do not (RF-7, NFR-6).
    func setAppInForeground(_ inForeground: Bool) {
        guard isAppInForeground != inForeground else { return }
        isAppInForeground = inForeground
        sourceDidChange()
    }

    // MARK: Availability (RF-3)

    /// Record button enabled: idle, valid source, permission granted.
    var canRecord: Bool {
        state == .idle && meteringSource != nil && !isInputInterrupted && !isPlaybackActive
    }

    /// Resume enabled while paused, with the recording device back and no call in progress (RF-8).
    var canResume: Bool {
        RecordingLogic.canResume(
            state: state,
            isRecordingDeviceConnected: isPreview ? previewCanResume : isRecordingDeviceReady && !isInputInterrupted
        )
    }

    // MARK: Quality (RF-1)

    func selectQuality(_ newQuality: RecordingQuality) {
        if isPreview {
            quality = newQuality
            return
        }
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
        // While the session is changing, supported rates may not be probed yet; applied when it finishes.
        guard let audioSource, !audioSource.service.isRoutingInput,
              let device = audioSource.selectedDevice, let quality,
              device.supportedSampleRates.contains(where: { abs($0 - quality.sampleRate) < 1 }) else { return }
        if let appliedSampleRate, appliedSampleRate.deviceID == device.id, appliedSampleRate.rate == quality.sampleRate {
            return
        }
        appliedSampleRate = (device.id, quality.sampleRate)
        audioSource.service.preferSampleRate(quality.sampleRate, deviceID: device.id)
    }

    // MARK: Recording (RF-3–RF-6)

    func startRecording() {
        guard state == .idle, !isPreview else { return }
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
        recordingDeviceID = source?.deviceID
        isLowStorageWarningShown = false
        recordingDeviceName = audioSource?.devices.first(where: { $0.id == source?.deviceID })?.displayLabel
        isWaitingForDeviceReconnect = false
        capture.startWriting(to: writer)
        state = .recording
        audioSource?.isSourceLocked = true
        preventIdleSleep(true)
        #if os(iOS)
        showsDoNotDisturbTip = !settings.isDoNotDisturbTipDismissed
        #endif
        updateLiveInfo()
        startLiveInfoUpdates()
    }

    func pauseRecording() {
        pause(reason: .user)
    }

    /// Pauses writing; automatic pauses (disconnect, interruption) also come through here.
    func pause(reason: RecordingPauseReason) {
        guard state == .recording else { return }
        capture.setWritingPaused(true)
        state = .paused(reason)
    }

    func resumeRecording() {
        guard canResume else { return }
        capture.setWritingPaused(false)
        state = .recording
    }

    /// Finishes the file and saves the session with a date-based name (RF-6).
    func stopRecording() {
        finishRecording { name in name.map { RecordingNotice(kind: .saved(sessionName: $0)) } }
    }

    /// Stops and saves; `makeNotice` gets the saved session name (nil when nothing was saved).
    func finishRecording(notice makeNotice: (String?) -> RecordingNotice?) {
        guard state.hasActiveRecording, let writer, let startDate = recordingStartDate else { return }
        capture.stopWriting()
        writer.close()
        liveInfoTask?.cancel()
        liveInfoTask = nil

        var savedName: String?
        do {
            savedName = try fileStore.finishRecording(at: writer.url, startDate: startDate, hasAudio: writer.framesWritten > 0)
        } catch {
            // The file stays in progress and is recovered on next launch (RF-8), so nothing is lost.
            logger.error("Cannot save session: \(error.localizedDescription, privacy: .public)")
        }
        notice = makeNotice(savedName)
        if let savedName { sessionSaved.send(savedName) }

        self.writer = nil
        recordingStartDate = nil
        recordingDeviceID = nil
        recordingDeviceName = nil
        isWaitingForDeviceReconnect = false
        state = .idle
        liveInfo = .zero
        audioSource?.isSourceLocked = false
        preventIdleSleep(false)
        showsDoNotDisturbTip = false
        // Source changes were ignored while recording; apply the current source now.
        sourceDidChange()
    }

    func dismissNotice() {
        notice = nil
    }

    /// The tip never appears again after this (RF-3).
    func dismissDoNotDisturbTip() {
        settings.dismissDoNotDisturbTip()
        showsDoNotDisturbTip = false
    }

    func show(_ notice: RecordingNotice) {
        self.notice = notice
    }

    /// Previews only (see RecordingViewModel+Preview): shows a state without capture or files.
    func applyPreview(
        state: RecordingState,
        liveInfo: RecordingLiveInfo,
        notice: RecordingNotice?,
        levels: [ChannelLevel],
        quality: RecordingQuality,
        offeredQualities: [RecordingQuality],
        canResume: Bool,
        showsDoNotDisturbTip: Bool
    ) {
        isPreview = true
        self.state = state
        self.liveInfo = liveInfo
        self.notice = notice
        meters.levels = levels
        meteredChannelCount = levels.count
        self.quality = quality
        self.offeredQualities = offeredQualities
        previewCanResume = canResume
        self.showsDoNotDisturbTip = showsDoNotDisturbTip
    }

    // MARK: Mac sleep (RF-7)

    private func preventIdleSleep(_ prevent: Bool) {
        #if os(macOS)
        if prevent, sleepPreventionActivity == nil {
            sleepPreventionActivity = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .userInitiated],
                reason: "Recording a session"
            )
        } else if !prevent, let sleepPreventionActivity {
            ProcessInfo.processInfo.endActivity(sleepPreventionActivity)
            self.sleepPreventionActivity = nil
        }
        #endif
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
        checkStorage(remainingSeconds: liveInfo.remainingSeconds)
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
        guard !isPreview else { return }
        // The source is locked while recording; capture keeps the recording device and channels.
        guard !state.hasActiveRecording else {
            recordingSourceDidChange()
            return
        }
        updateQuality()
        updateMetering()
    }

    private func updateMetering() {
        // iOS: the engine is stopped while the session changes (route, rate, channels) and restarted
        // once with the final format, instead of restarting on every intermediate change.
        guard isAppInForeground, !isPlaybackActive, let source = meteringSource, audioSource?.service.isRoutingInput != true else {
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
        capture.$isInterrupted
            .sink { [weak self] interrupted in self?.isInputInterrupted = interrupted }
            .store(in: &cancellables)
        capture.events
            .sink { [weak self] event in self?.handleCaptureEvent(event) }
            .store(in: &cancellables)
    }

    private func updateLevels(peaks: [Float], now: Date = Date()) {
        if lastClipDates.count != peaks.count {
            lastClipDates = Array(repeating: nil, count: peaks.count)
        }
        if meteredChannelCount != peaks.count {
            meteredChannelCount = peaks.count
        }
        meters.levels = peaks.enumerated().map { index, peak in
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
