import SwiftUI

struct ContentView: View {
    @State private var currentStatus: STATUSES = .START
    @StateObject private var audioSourceViewModel: AudioSourceSelectionViewModel

    init(audioSourceViewModel: AudioSourceSelectionViewModel? = nil) {
        _audioSourceViewModel = StateObject(wrappedValue: audioSourceViewModel ?? AudioSourceSelectionViewModel())
    }

    var body: some View {
        // Bottom tab bar on iPhone; sidebar-adaptable on iPad and Mac.
        TabView {
            Tab("Record", systemImage: "record.circle") {
                recordTab
            }
            Tab("Sessions", systemImage: "list.bullet") {
                sessionsTab
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Injected at the root so tabs and sheets presented from them share the same state.
        .environmentObject(audioSourceViewModel)
    }

    private var recordTab: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 30) {
                AudioSourceSelectionView()
                RecordButton(currentStatus: $currentStatus)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Record")
        }
    }

    // Placeholder until the session library feature exists.
    private var sessionsTab: some View {
        NavigationStack {
            ContentUnavailableView(
                "No sessions yet",
                systemImage: "waveform",
                description: Text("Your recorded sessions will appear here.")
            )
            .navigationTitle("Sessions")
        }
    }
}

#Preview {
    ContentView()
}
