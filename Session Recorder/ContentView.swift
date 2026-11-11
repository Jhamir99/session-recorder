import SwiftUI

struct ContentView: View {
    @State private var currentStatus: STATUSES = .START
    @StateObject private var audioSourceViewModel: AudioSourceSelectionViewModel

    init(audioSourceViewModel: AudioSourceSelectionViewModel? = nil) {
        _audioSourceViewModel = StateObject(wrappedValue: audioSourceViewModel ?? AudioSourceSelectionViewModel())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            AudioSourceSelectionView()
            RecordButton(currentStatus: $currentStatus)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Injected at the root so tabs and sheets presented from them share the same state.
        .environmentObject(audioSourceViewModel)
    }
}

#Preview {
    ContentView()
}
