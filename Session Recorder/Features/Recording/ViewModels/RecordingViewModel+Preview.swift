import Foundation

/// Sample recording states for previews (C5). No capture, files or settings are touched.
extension RecordingViewModel {
    static func preview(
        state: RecordingState = .idle,
        elapsedSeconds: TimeInterval = 0,
        notice: RecordingNotice.Kind? = nil,
        levels: [ChannelLevel] = [ChannelLevel(peak: 0.45, isClipping: false), ChannelLevel(peak: 0.6, isClipping: false)],
        quality: RecordingQuality = RecordingQuality(sampleRate: 48_000, bitDepth: 24),
        canResume: Bool = false,
        showsDoNotDisturbTip: Bool = false
    ) -> RecordingViewModel {
        let viewModel = RecordingViewModel(
            settings: RecordingSettingsRepository(defaults: UserDefaults(suiteName: "preview.recording") ?? .standard)
        )
        let bytesPerSecond = RecordingLogic.bytesPerSecond(quality: quality, channelCount: max(levels.count, 1))
        viewModel.applyPreview(
            state: state,
            liveInfo: RecordingLiveInfo(
                elapsedSeconds: elapsedSeconds,
                fileSizeBytes: Int64(elapsedSeconds * bytesPerSecond),
                remainingSeconds: 5 * 3600
            ),
            notice: notice.map { RecordingNotice(kind: $0) },
            levels: levels,
            quality: quality,
            offeredQualities: RecordingLogic.offeredQualities(deviceSupportedRates: [44_100, 48_000, 88_200, 96_000]),
            canResume: canResume,
            showsDoNotDisturbTip: showsDoNotDisturbTip
        )
        return viewModel
    }

    static var previewIdle: RecordingViewModel { preview() }

    static var previewIdleMonoClipping: RecordingViewModel {
        preview(levels: [ChannelLevel(peak: 1, isClipping: true)])
    }

    static var previewRecording: RecordingViewModel {
        preview(state: .recording, elapsedSeconds: 3725, showsDoNotDisturbTip: true)
    }

    static var previewPausedByUser: RecordingViewModel {
        preview(state: .paused(.user), elapsedSeconds: 125, canResume: true)
    }

    static var previewPausedDisconnected: RecordingViewModel {
        preview(state: .paused(.deviceDisconnected), elapsedSeconds: 840, notice: .deviceDisconnected(deviceName: "Xone:96"),
                levels: [ChannelLevel.silent, .silent])
    }

    static var previewPausedInterruption: RecordingViewModel {
        preview(state: .paused(.interruption), elapsedSeconds: 1290, notice: .interrupted)
    }

    static var previewLowStorage: RecordingViewModel {
        preview(state: .recording, elapsedSeconds: 7200, notice: .lowStorageWarning(minutes: 10))
    }

    static var previewSaved: RecordingViewModel {
        preview(notice: .saved(sessionName: "Session 2026-11-12 22.30"))
    }

    static var previewRecovered: RecordingViewModel {
        preview(notice: .recovered(sessionName: "Session 2026-11-12 21.05"))
    }
}
