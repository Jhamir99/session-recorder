import SwiftUI

// Session library previews (C5): list, detail, trim, export and dialogs with preview view models
// (no files or audio). Component previews (row, waveform, player, trim controls) live next to each view.

#Preview("List") {
    SessionLibraryView(viewModel: .previewList, isRecordingActive: false) { EmptyView() }
}

#Preview("List, empty") {
    SessionLibraryView(viewModel: .previewEmpty, isRecordingActive: false) { EmptyView() }
}

#Preview("List while recording") {
    SessionLibraryView(viewModel: .previewList, isRecordingActive: true) {
        RecordingIndicator(state: .recording, elapsedSeconds: 125) {}
            .padding(.horizontal)
    }
}

#Preview("Rename dialog") {
    SessionLibraryView(viewModel: .previewRenaming, isRecordingActive: false) { EmptyView() }
}

#Preview("Delete confirmation") {
    SessionLibraryView(viewModel: .previewDeleting, isRecordingActive: false) { EmptyView() }
}

#Preview("Detail, ready") {
    NavigationStack { SessionDetailView(viewModel: .preview()) }
}

#Preview("Detail, playing") {
    NavigationStack { SessionDetailView(viewModel: .preview(isPlaying: true, position: 1830)) }
}

#Preview("Detail, loading waveform") {
    NavigationStack { SessionDetailView(viewModel: .preview(waveformFraction: 0.35)) }
}

#Preview("Detail, disabled while recording") {
    NavigationStack { SessionDetailView(viewModel: .preview(isPlaybackBlocked: true), isRecordingActive: true) }
}

#Preview("Detail, can't be played") {
    NavigationStack { SessionDetailView(viewModel: .preview(session: SessionItem.previewSessions[3])) }
}

#Preview("Trim") {
    NavigationStack {
        SessionDetailView(viewModel: .preview(position: 600, trimRange: TrimRange(start: 312.4, end: 3420.8)))
    }
}

#Preview("Export, choose") {
    ExportSheet(viewModel: .preview(phase: .choosing))
}

#Preview("Export, AAC") {
    ExportSheet(viewModel: .preview(phase: .choosing, format: .aac))
}

#Preview("Export, progress") {
    ExportSheet(viewModel: .preview(phase: .exporting(progress: 0.42)))
}

#Preview("Export, failed") {
    ExportSheet(viewModel: .preview(phase: .failed("Not enough free storage to export.")))
}
