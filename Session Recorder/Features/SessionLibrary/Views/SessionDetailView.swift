import SwiftUI

/// Session detail (RF-2): date, duration, format, size and waveform. Player and actions come later.
struct SessionDetailView: View {
    @StateObject private var viewModel: SessionDetailViewModel

    init(session: SessionItem) {
        _viewModel = StateObject(wrappedValue: SessionDetailViewModel(session: session))
    }

    init(viewModel: SessionDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
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
                duration: viewModel.audioInfo?.duration ?? 0,
                isLoading: !viewModel.isWaveformComplete
            )
            .frame(maxWidth: .infinity)
            .frame(height: 80)
        }
    }
}
