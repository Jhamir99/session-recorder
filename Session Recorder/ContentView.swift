import SwiftUI

struct ContentView: View {
    @State private var currentStatus: STATUSES = .START
    @StateObject private var audioSourceViewModel = AudioSourceSelectionViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            AudioSourceSelectionView(viewModel: audioSourceViewModel)
            RecordButton(currentStatus: $currentStatus)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    ContentView()
}
