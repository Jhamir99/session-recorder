import SwiftUI

private enum AudioSourceSelectionPreviewData {
    static var duplicateNames: some View {
        let devices = [
            AudioInputDevice(id: "a1", displayName: "USB Interface", channels: [AudioInputChannel(id: "a1:1", number: 1, name: nil)]),
            AudioInputDevice(id: "a2", displayName: "USB Interface", channels: [AudioInputChannel(id: "a2:1", number: 1, name: nil)])
        ]
        let state = AudioSourceSelectionViewModel.PreviewState(
            devices: AudioDeviceSelectionHelper.disambiguateDeviceNames(devices),
            hasNoEligibleDevices: false,
            rawDevices: devices
        )
        return AudioSourceSelectionView()
            .environmentObject(AudioSourceSelectionViewModel(previewState: state))
    }

    static var noChannels: some View {
        let device = AudioInputDevice(id: "d1", displayName: "Mixer", channels: [])
        let state = AudioSourceSelectionViewModel.PreviewState(
            devices: AudioDeviceSelectionHelper.disambiguateDeviceNames([device]),
            selectedDeviceID: "d1",
            permissionState: .granted,
            displayedChannels: [],
            userMessage: AudioSourceUserMessage(kind: .noChannelsAvailable, text: "No channels are available for this device.", showsRetryPermissionAction: false),
            rawDevices: [device]
        )
        return AudioSourceSelectionView()
            .environmentObject(AudioSourceSelectionViewModel(previewState: state))
    }

    static var permissionRequired: some View {
        let device = AudioInputDevice(id: "d1", displayName: "Built-in Microphone", channels: [AudioInputChannel(id: "d1:1", number: 1, name: nil)])
        let state = AudioSourceSelectionViewModel.PreviewState(
            devices: AudioDeviceSelectionHelper.disambiguateDeviceNames([device]),
            selectedDeviceID: "d1",
            permissionState: .denied,
            userMessage: AudioSourceUserMessage(kind: .permissionRequired, text: "Permission must be granted to access audio input channels.", showsRetryPermissionAction: true),
            showsPermissionPrompt: true,
            rawDevices: [device]
        )
        return AudioSourceSelectionView()
            .environmentObject(AudioSourceSelectionViewModel(previewState: state))
    }

    static var monoOnly: some View {
        let channels = [AudioInputChannel(id: "d1:1", number: 1, name: "Mic")]
        let device = AudioInputDevice(id: "d1", displayName: "USB Mic", channels: channels)
        let state = AudioSourceSelectionViewModel.PreviewState(
            devices: AudioDeviceSelectionHelper.disambiguateDeviceNames([device]),
            selectedDeviceID: "d1",
            permissionState: .granted,
            selectedMode: .mono,
            displayedChannels: channels,
            activeSelection: .mono(channelID: "d1:1"),
            rawDevices: [device]
        )
        return AudioSourceSelectionView()
            .environmentObject(AudioSourceSelectionViewModel(previewState: state))
    }

    static var stereoLeftRight: some View {
        let channels = [
            AudioInputChannel(id: "d1:1", number: 1, name: "Deck A"),
            AudioInputChannel(id: "d1:2", number: 2, name: "Deck B"),
            AudioInputChannel(id: "d1:3", number: 3, name: nil)
        ]
        let device = AudioInputDevice(id: "d1", displayName: "DJ Mixer", channels: channels)
        let state = AudioSourceSelectionViewModel.PreviewState(
            devices: AudioDeviceSelectionHelper.disambiguateDeviceNames([device]),
            selectedDeviceID: "d1",
            permissionState: .granted,
            selectedMode: .stereo,
            displayedChannels: channels,
            activeSelection: .stereo(leftChannelID: "d1:1", rightChannelID: "d1:2"),
            rawDevices: [device]
        )
        return AudioSourceSelectionView()
            .environmentObject(AudioSourceSelectionViewModel(previewState: state))
    }

    static var disconnectError: some View {
        let device = AudioInputDevice(id: "d1", displayName: "DJ Mixer", channels: [AudioInputChannel(id: "d1:1", number: 1, name: nil)])
        let state = AudioSourceSelectionViewModel.PreviewState(
            devices: AudioDeviceSelectionHelper.disambiguateDeviceNames([device]),
            selectedDeviceID: nil,
            permissionState: .unknown,
            userMessage: AudioSourceUserMessage(kind: .deviceDisconnected, text: "The selected audio device was disconnected.", showsRetryPermissionAction: false),
            rawDevices: [device]
        )
        return AudioSourceSelectionView()
            .environmentObject(AudioSourceSelectionViewModel(previewState: state))
    }

    static var restoredSelection: some View {
        let channels = [
            AudioInputChannel(id: "d1:1", number: 1, name: nil),
            AudioInputChannel(id: "d1:2", number: 2, name: nil)
        ]
        let device = AudioInputDevice(id: "d1", displayName: "Audio Interface", channels: channels)
        let state = AudioSourceSelectionViewModel.PreviewState(
            devices: AudioDeviceSelectionHelper.disambiguateDeviceNames([device]),
            selectedDeviceID: "d1",
            permissionState: .granted,
            selectedMode: .stereo,
            displayedChannels: channels,
            activeSelection: .stereo(leftChannelID: "d1:1", rightChannelID: "d1:2"),
            rawDevices: [device]
        )
        return AudioSourceSelectionView()
            .environmentObject(AudioSourceSelectionViewModel(previewState: state))
    }
}

#Preview { AudioSourceSelectionPreviewData.stereoLeftRight.padding() }
#Preview("Sample devices") { AudioSourceSelectionPreviewData.restoredSelection.padding() }
#Preview("Empty") {
    AudioSourceSelectionView()
        .environmentObject(AudioSourceSelectionViewModel(previewState: .init(hasNoEligibleDevices: true)))
        .padding()
}
#Preview("Duplicate names") { AudioSourceSelectionPreviewData.duplicateNames.padding() }
#Preview("No channels") { AudioSourceSelectionPreviewData.noChannels.padding() }
#Preview("Permission required") { AudioSourceSelectionPreviewData.permissionRequired.padding() }
#Preview("Mono only") { AudioSourceSelectionPreviewData.monoOnly.padding() }
#Preview("Stereo left/right") { AudioSourceSelectionPreviewData.stereoLeftRight.padding() }
#Preview("Disconnect/error") { AudioSourceSelectionPreviewData.disconnectError.padding() }
#Preview("Restored selection") { AudioSourceSelectionPreviewData.restoredSelection.padding() }
