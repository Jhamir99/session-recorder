import SwiftUI

struct AudioSourceSelectionView: View {
    // Injected by ContentView so the source row and source sheet share one state.
    @EnvironmentObject private var viewModel: AudioSourceSelectionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Input")
                .font(.headline)

            DeviceListView()

            ChannelSelectionView()

            if let message = viewModel.userMessage, message.kind != .permissionRequired {
                Text(message.text)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
