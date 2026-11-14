import SwiftUI

/// Sessions tab content (RF-1): list newest first and the selected session's detail.
/// Split view on iPad/Mac; on iPhone it collapses to a list that pushes the detail.
struct SessionLibraryView<Indicator: View>: View {
    @ObservedObject var viewModel: SessionLibraryViewModel
    /// Shown above the list (the `REC`/`PAUSED` indicator while a recording exists).
    @ViewBuilder var indicator: Indicator

    var body: some View {
        NavigationSplitView {
            sessionList
                .navigationTitle("Sessions")
                .safeAreaInset(edge: .top) { indicator }
        } detail: {
            if let session = viewModel.selectedSession {
                // Replaced by the session detail (T8).
                Text(session.name)
                    .font(.title2)
                    .navigationTitle(session.name)
            } else {
                ContentUnavailableView("Select a session", systemImage: "waveform")
            }
        }
        .task {
            viewModel.refresh()
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
                NavigationLink(value: session.id) {
                    SessionRow(session: session)
                }
            }
        }
    }
}
