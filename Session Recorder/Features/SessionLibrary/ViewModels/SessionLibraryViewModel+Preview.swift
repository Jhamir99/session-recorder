import Foundation

/// Sample library states for previews (C5). Nothing reads or writes files, and no audio is played.
extension SessionLibraryViewModel {
    static let previewStore = SessionLibraryStore(sessionsDirectory: URL(fileURLWithPath: "/dev/null/PreviewSessions"))

    static func preview(
        sessions: [SessionItem] = SessionItem.previewSessions,
        selectedIndex: Int? = nil,
        renamingIndex: Int? = nil,
        deletingIndex: Int? = nil
    ) -> SessionLibraryViewModel {
        let viewModel = SessionLibraryViewModel(store: previewStore)
        viewModel.applyPreview(
            sessions: sessions,
            selectedID: selectedIndex.map { sessions[$0].id },
            renaming: renamingIndex.map { sessions[$0] },
            deleting: deletingIndex.map { sessions[$0] }
        )
        return viewModel
    }

    static var previewEmpty: SessionLibraryViewModel { preview(sessions: []) }
    static var previewList: SessionLibraryViewModel { preview() }
    static var previewSelected: SessionLibraryViewModel { preview(selectedIndex: 0) }
    static var previewRenaming: SessionLibraryViewModel { preview(renamingIndex: 1) }
    static var previewDeleting: SessionLibraryViewModel { preview(deletingIndex: 1) }
}

nonisolated extension SessionItem {
    static func preview(
        _ name: String,
        minutesAgo: Double,
        duration: TimeInterval? = 3735,
        audio: AudioState? = nil
    ) -> SessionItem {
        let format = SessionFormat(channelCount: 2, sampleRate: 48_000, bitDepth: 24)
        let state = audio ?? duration.map { .readable(SessionAudioInfo(duration: $0, format: format)) } ?? .loading
        return SessionItem(
            url: URL(fileURLWithPath: "/PreviewSessions/\(name).caf"),
            name: name,
            recordedDate: Date(timeIntervalSince1970: 1_794_700_000 - minutesAgo * 60),
            fileSizeBytes: Int64(format.bytesPerSecond * (duration ?? 0)),
            audio: state
        )
    }

    static let previewSessions: [SessionItem] = [
        .preview("Session 2026-11-14 22.30.15", minutesAgo: 0, duration: 3735),
        .preview("Friday warm-up", minutesAgo: 60 * 24, duration: 1520),
        .preview("Session 2026-11-12 18.02.44", minutesAgo: 60 * 48, duration: nil),
        .preview("Broken file", minutesAgo: 60 * 72, audio: .unreadable)
    ]
}

extension SessionDetailViewModel {
    static func previewWaveform(seconds: Int = 3735) -> WaveformData {
        let peaks = (0..<(seconds * WaveformData.defaultPeaksPerSecond)).map { index in
            Float(0.35 + 0.45 * abs(sin(Double(index) / 400)) * (0.8 + 0.2 * sin(Double(index) / 37)))
        }
        return WaveformData(peaksPerSecond: WaveformData.defaultPeaksPerSecond, peaks: peaks)
    }

    static func preview(
        session: SessionItem = SessionItem.previewSessions[0],
        waveformFraction: Double = 1,
        isPlaying: Bool = false,
        isPlaybackBlocked: Bool = false,
        position: TimeInterval = 845,
        trimRange: TrimRange? = nil
    ) -> SessionDetailViewModel {
        let viewModel = SessionDetailViewModel(session: session)
        let duration = session.audioInfo?.duration ?? 0
        let full = previewWaveform(seconds: Int(duration))
        let waveform = waveformFraction <= 0 ? nil : WaveformData(
            peaksPerSecond: full.peaksPerSecond,
            peaks: Array(full.peaks.prefix(Int(Double(full.peaks.count) * waveformFraction)))
        )
        viewModel.applyPreview(
            waveform: session.isUnreadable ? nil : waveform,
            isWaveformComplete: waveformFraction >= 1,
            isPlaying: isPlaying,
            isPlayable: !session.isUnreadable,
            isPlaybackBlocked: isPlaybackBlocked,
            position: position,
            trimRange: trimRange
        )
        return viewModel
    }
}

extension SessionExportViewModel {
    static func preview(phase: Phase, format: ExportFormat = .flac) -> SessionExportViewModel {
        let settings = SessionLibrarySettingsRepository(
            defaults: UserDefaults(suiteName: "preview.library") ?? .standard,
            exportChoiceKey: "preview_export_choice"
        )
        let viewModel = SessionExportViewModel(session: SessionItem.previewSessions[0], settings: settings)
        viewModel.choice = ExportChoice(format: format, aacBitrate: .kbps256)
        viewModel.applyPreview(phase: phase)
        return viewModel
    }
}
