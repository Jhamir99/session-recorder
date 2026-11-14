import SwiftUI

/// Sessions tab content (RF-1): list newest first and the selected session's detail.
/// - iPhone/iPad: `NavigationSplitView` (on iPhone it collapses to a list that pushes the detail).
/// - Mac: list and detail side by side in a plain `HStack`. Inside the tab sidebar, a split view made the
///   session list a second floating sidebar and the detail was laid out underneath it.
struct SessionLibraryView<Indicator: View>: View {
    @ObservedObject var viewModel: SessionLibraryViewModel
    /// A recording exists (recording or paused): playback is disabled.
    let isRecordingActive: Bool
    /// Shown above the list (the `REC`/`PAUSED` indicator while a recording exists).
    @ViewBuilder var indicator: Indicator

    var body: some View {
        content
            .task {
                viewModel.refresh()
            }
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            sessionList
                .safeAreaInset(edge: .top) { indicator }
                .frame(width: 280)
            Divider()
            NavigationStack {
                detail
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Sessions")
        #else
        NavigationSplitView {
            sessionList
                .navigationTitle("Sessions")
                .safeAreaInset(edge: .top) { indicator }
        } detail: {
            detail
        }
        #endif
    }

    @ViewBuilder
    private var detail: some View {
        if let session = viewModel.selectedSession {
            // A new detail (and view model) per session file.
            SessionDetailView(session: session, handoff: viewModel.playbackHandoff, isRecordingActive: isRecordingActive)
                .id(session.id)
        } else {
            ContentUnavailableView("Select a session", systemImage: "waveform")
        }
    }

    @ViewBuilder
    private var sessionList: some View {
        if viewModel.hasLoaded && viewModel.sessions.isEmpty {
            ContentUnavailableView(
                "No sessions yet",
                systemImage: "waveform",
                description: Text("Your recorded sessions will appear here.")
            )
        } else {
            List(viewModel.sessions, selection: $viewModel.selectedSessionID) { session in
                row(for: session)
            }
        }
    }

    @ViewBuilder
    private func row(for session: SessionItem) -> some View {
        #if os(macOS)
        // Selection drives the detail next to the list (no navigation push on Mac).
        SessionRow(session: session)
            .tag(session.id)
            .contextMenu {
                Button("Show in Finder", systemImage: "folder") {
                    SessionLibraryStore.revealInFinder(session.url)
                }
            }
        #else
        NavigationLink(value: session.id) {
            SessionRow(session: session)
        }
        #endif
    }
}
