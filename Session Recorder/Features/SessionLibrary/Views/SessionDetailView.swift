import SwiftUI

/// Session detail (RF-2): date, duration, format, size, waveform and player. Actions come later.
struct SessionDetailView: View {
    @StateObject private var viewModel: SessionDetailViewModel
    /// Latest list item (e.g. after a rename); the view model keeps its own state for the same file.
    private let session: SessionItem?
    /// A recording exists: playback is disabled (RF-2).
    let isRecordingActive: Bool
    var onRename: (() -> Void)?
    var onDelete: (() -> Void)?

    init(
        session: SessionItem,
        handoff: PlaybackHandoff,
        isRecordingActive: Bool,
        onRename: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: SessionDetailViewModel(session: session, handoff: handoff))
        self.session = session
        self.isRecordingActive = isRecordingActive
        self.onRename = onRename
        self.onDelete = onDelete
    }

    init(viewModel: SessionDetailViewModel, isRecordingActive: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.session = nil
        self.isRecordingActive = isRecordingActive
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                infoSection
                waveformSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(viewModel.session.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            viewModel.setPlaybackBlocked(isRecordingActive)
            viewModel.load()
        }
        .onChange(of: session) { _, updated in
            if let updated { viewModel.sessionDidChange(updated) }
        }
        .onChange(of: isRecordingActive) { _, active in
            viewModel.setPlaybackBlocked(active)
        }
        .onDisappear { viewModel.cancel() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                actionsMenu
            }
        }
    }

    /// Session actions (more are added with delete, trim and share).
    private var actionsMenu: some View {
        Menu("Actions", systemImage: "ellipsis.circle") {
            if let onRename {
                Button("Rename…", systemImage: "pencil", action: onRename)
            }
            #if os(macOS)
            Button("Show in Finder", systemImage: "folder") {
                SessionLibraryStore.revealInFinder(viewModel.session.url)
            }
            #endif
            if let onDelete {
                Divider()
                Button("Delete…", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.session.name)
                .font(.title2.weight(.semibold))
            Text(viewModel.session.recordedDate, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
                .foregroundStyle(.secondary)
            Text(detailsLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// `1:00:11 · Stereo · 24-bit/48 kHz · 1.04 GB`.
    private var detailsLine: String {
        let size = RecordingLogic.formatFileSize(viewModel.session.fileSizeBytes)
        switch viewModel.session.audio {
        case .loading:
            return size
        case .readable(let info):
            return [SessionLibraryLogic.formatPlaybackTime(info.duration), info.format.label, size].joined(separator: " · ")
        case .unreadable:
            return size
        }
    }

    /// Seeking is possible once the player opened the file.
    private var seekAction: ((TimeInterval) -> Void)? {
        guard viewModel.canPlay else { return nil }
        let viewModel = viewModel
        return { viewModel.seek(to: $0) }
    }

    @ViewBuilder
    private var waveformSection: some View {
        if viewModel.session.isUnreadable {
            ContentUnavailableView(
                "Can't be played",
                systemImage: "exclamationmark.triangle",
                description: Text("This file is damaged or is not a supported audio file.")
            )
        } else {
            WaveformView(
                waveform: viewModel.waveform,
                duration: viewModel.duration,
                isLoading: !viewModel.isWaveformComplete,
                progress: viewModel.progress,
                onSeek: seekAction
            )
            .frame(maxWidth: .infinity)
            .frame(height: 80)

            PlayerControlsView(
                progress: viewModel.progress,
                duration: viewModel.duration,
                isPlaying: viewModel.isPlaying,
                isEnabled: viewModel.canPlay,
                onTogglePlayback: { viewModel.togglePlayback() },
                onSkip: { viewModel.skip(by: $0) }
            )
            if viewModel.isPlaybackBlocked {
                Label("Playback is unavailable while recording.", systemImage: "record.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
