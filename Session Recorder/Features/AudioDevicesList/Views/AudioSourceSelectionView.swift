import SwiftUI

/// Content of the source sheet: device list and channel selection as a native form (RF-6).
struct AudioSourceSelectionView: View {
    // Injected by ContentView so the source row and source sheet share one state.
    @EnvironmentObject private var viewModel: AudioSourceSelectionViewModel

    var body: some View {
        Form {
            Section("Device") {
                DeviceListView()
            }

            if viewModel.selectedDeviceID != nil {
                Section("Channels") {
                    ChannelSelectionView()
                }
            }

            if let message = viewModel.userMessage, message.kind != .permissionRequired {
                Section {
                    Text(message.text)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }
}
