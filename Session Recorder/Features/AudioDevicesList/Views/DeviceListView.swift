import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var viewModel: AudioSourceSelectionViewModel
    
    var body: some View {
        if viewModel.hasNoEligibleDevices {
            Text("No audio input devices are available.")
                .foregroundStyle(.secondary)
        } else {
            deviceList
        }
    }
    
    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.devices) { device in
                Button {
                    viewModel.selectDevice(id: device.id)
                } label: {
                    HStack {
                        Text(device.displayLabel)
                        Spacer()
                        if viewModel.selectedDeviceID == device.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
