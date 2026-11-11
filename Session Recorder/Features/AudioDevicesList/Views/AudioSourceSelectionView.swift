import SwiftUI

struct AudioSourceSelectionView: View {
    // Owned by the Record tab so the source row and source sheet share one state.
    @ObservedObject var viewModel: AudioSourceSelectionViewModel

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
        .environmentObject(viewModel)
    }
}
