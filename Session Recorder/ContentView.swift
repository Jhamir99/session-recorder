import SwiftUI

struct ContentView: View {
    @State private var currentStatus: STATUSES = .START
    @State private var isShowingSourceSheet = false
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
            VStack(alignment: .leading, spacing: 8) {
                AudioSourceSummaryRow { isShowingSourceSheet = true }

                if let message = audioSourceViewModel.recordTabMessage {
                    Text(message.text)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 0)

                // Pinned at the bottom so it stays visible regardless of device/channel count.
                RecordButton(currentStatus: $currentStatus)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle("Record")
        }
        .sheet(isPresented: $isShowingSourceSheet) {
            sourceSheet
        }
    }

    // Basic container so the sheet can be dismissed on every platform; T20 turns the content into a native form.
    private var sourceSheet: some View {
        NavigationStack {
            ScrollView {
                AudioSourceSelectionView()
                    .padding()
            }
            .navigationTitle("Audio Source")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingSourceSheet = false }
                }
            }
        }
        .environmentObject(audioSourceViewModel)
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
