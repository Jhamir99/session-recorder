import SwiftUI

private enum AudioSourceSelectionPreviewData {
    /// Presents content the way the Record tab's source sheet does.
    static func sheet(_ content: some View) -> some View {
        NavigationStack {
            content.navigationTitle("Audio Source")
        }
    }

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

#Preview { AudioSourceSelectionPreviewData.sheet(AudioSourceSelectionPreviewData.stereoLeftRight) }
#Preview("Sample devices") { AudioSourceSelectionPreviewData.sheet(AudioSourceSelectionPreviewData.restoredSelection) }
#Preview("Empty") {
    AudioSourceSelectionPreviewData.sheet(
        AudioSourceSelectionView().environmentObject(AudioSourceSelectionViewModel.previewNoInput)
    )
}
#Preview("Duplicate names") { AudioSourceSelectionPreviewData.sheet(AudioSourceSelectionPreviewData.duplicateNames) }
#Preview("No channels") { AudioSourceSelectionPreviewData.sheet(AudioSourceSelectionPreviewData.noChannels) }
#Preview("Permission required") { AudioSourceSelectionPreviewData.sheet(AudioSourceSelectionPreviewData.permissionRequired) }
#Preview("Mono only") { AudioSourceSelectionPreviewData.sheet(AudioSourceSelectionPreviewData.monoOnly) }
#Preview("Stereo left/right") { AudioSourceSelectionPreviewData.sheet(AudioSourceSelectionPreviewData.stereoLeftRight) }
#Preview("Disconnect/error") { AudioSourceSelectionPreviewData.sheet(AudioSourceSelectionPreviewData.disconnectError) }
#Preview("Restored selection") { AudioSourceSelectionPreviewData.sheet(AudioSourceSelectionPreviewData.restoredSelection) }
#Preview("Many channels") {
    AudioSourceSelectionPreviewData.sheet(
        AudioSourceSelectionView().environmentObject(AudioSourceSelectionViewModel.previewManyChannels)
    )
}
