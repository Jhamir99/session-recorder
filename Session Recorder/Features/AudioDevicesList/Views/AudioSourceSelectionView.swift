import SwiftUI

struct AudioSourceSelectionView: View {
    @StateObject private var viewModel: AudioSourceSelectionViewModel

    init(viewModel: AudioSourceSelectionViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? AudioSourceSelectionViewModel())
    }

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
