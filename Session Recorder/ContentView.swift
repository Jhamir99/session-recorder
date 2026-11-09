import SwiftUI

struct ContentView: View {
    @State private var currentStatus: STATUSES = .START

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            AudioSourceSelectionView()
            RecordButton(currentStatus: $currentStatus)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    ContentView()
}
