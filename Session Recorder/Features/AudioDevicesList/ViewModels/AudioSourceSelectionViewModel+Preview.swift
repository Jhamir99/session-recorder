import Foundation

extension AudioSourceSelectionViewModel {
    convenience init(previewState: PreviewState) {
        self.init(
            service: AudioInputDeviceService(),
            store: AudioDeviceSelectionRepository(
                defaults: UserDefaults(suiteName: "preview.audio.devices") ?? .standard,
                storageKey: "preview_unused"
            )
        )
        cancellables.removeAll()
        devices = previewState.devices
        selectedDeviceID = previewState.selectedDeviceID
        permissionState = previewState.permissionState
        selectedMode = previewState.selectedMode
        displayedChannels = previewState.displayedChannels
        activeSelection = previewState.activeSelection
        stereoLeftCandidateID = previewState.stereoLeftCandidateID
        userMessage = previewState.userMessage
        showsPermissionPrompt = previewState.showsPermissionPrompt
        hasNoEligibleDevices = previewState.hasNoEligibleDevices
        rawDevices = previewState.rawDevices
    }

    // Sample states shared by the Record tab, source row and source sheet previews.

    static var previewNoInput: AudioSourceSelectionViewModel {
        AudioSourceSelectionViewModel(previewState: .init(hasNoEligibleDevices: true))
    }

    static var previewMono: AudioSourceSelectionViewModel {
        previewDevice(name: "iPhone Microphone", isExternal: false, channelCount: 1, mode: .mono, selection: .mono(channelID: "d1:1"))
    }

    static var previewStereo: AudioSourceSelectionViewModel {
        previewDevice(name: "Xone:96", channelCount: 4, mode: .stereo, selection: .stereo(leftChannelID: "d1:1", rightChannelID: "d1:2"))
    }

    /// Large interface to check that the sheet scrolls and the record button stays visible.
    static var previewManyChannels: AudioSourceSelectionViewModel {
        previewDevice(name: "DJ Mixer 16x", channelCount: 16, mode: .stereo, selection: .stereo(leftChannelID: "d1:3", rightChannelID: "d1:4"))
    }

    static var previewNoValidChannel: AudioSourceSelectionViewModel {
        previewDevice(name: "Xone:96", channelCount: 4, mode: .mono, selection: nil)
    }

    static var previewPermissionRequired: AudioSourceSelectionViewModel {
        let device = AudioInputDevice(id: "d1", displayName: "Xone:96", channels: previewChannels(count: 4), isExternal: true)
        return AudioSourceSelectionViewModel(previewState: .init(
            devices: AudioDeviceSelectionHelper.disambiguateDeviceNames([device]),
            selectedDeviceID: "d1",
            permissionState: .denied,
            userMessage: AudioSourceUserMessage(kind: .permissionRequired, text: "Permission must be granted to access audio input channels.", showsRetryPermissionAction: true),
            showsPermissionPrompt: true,
            rawDevices: [device]
        ))
    }

    /// External device selected automatically after it connected (RF-7).
    static var previewAutoSelectedExternal: AudioSourceSelectionViewModel {
        let viewModel = previewStereo
        viewModel.userMessage = AudioSourceUserMessage(kind: .sourceChangedAutomatically, text: "Switched to Xone:96.", showsRetryPermissionAction: false)
        return viewModel
    }

    /// Selected external device disconnected; fell back to the built-in input (RF-5, RF-7).
    static var previewFallbackToBuiltIn: AudioSourceSelectionViewModel {
        let channels = previewChannels(deviceID: "d0", count: 1)
        let builtIn = AudioInputDevice(id: "d0", displayName: "iPhone Microphone", channels: channels)
        return AudioSourceSelectionViewModel(previewState: .init(
            devices: AudioDeviceSelectionHelper.disambiguateDeviceNames([builtIn]),
            selectedDeviceID: "d0",
            permissionState: .granted,
            selectedMode: .mono,
            displayedChannels: channels,
            activeSelection: .mono(channelID: "d0:1"),
            userMessage: AudioSourceUserMessage(kind: .deviceDisconnected, text: "Xone:96 was disconnected. Switched to iPhone Microphone.", showsRetryPermissionAction: false),
            rawDevices: [builtIn]
        ))
    }

    private static func previewChannels(deviceID: String = "d1", count: Int) -> [AudioInputChannel] {
        (1...count).map { AudioInputChannel(id: "\(deviceID):\($0)", number: $0, name: nil) }
    }

    private static func previewDevice(
        name: String,
        isExternal: Bool = true,
        channelCount: Int,
        mode: AudioChannelMode,
        selection: ChannelSelection?
    ) -> AudioSourceSelectionViewModel {
        let channels = previewChannels(count: channelCount)
        let device = AudioInputDevice(id: "d1", displayName: name, channels: channels, isExternal: isExternal)
        let builtIn = AudioInputDevice(id: "d0", displayName: "Built-in Microphone", channels: previewChannels(deviceID: "d0", count: 1))
        let devices = [builtIn, device]
        return AudioSourceSelectionViewModel(previewState: .init(
            devices: AudioDeviceSelectionHelper.disambiguateDeviceNames(devices),
            selectedDeviceID: "d1",
            permissionState: .granted,
            selectedMode: mode,
            displayedChannels: channels,
            activeSelection: selection,
            rawDevices: devices
        ))
    }

    struct PreviewState {
        var devices: [AudioDeviceSelectionHelper.DisambiguatedDevice] = []
        var selectedDeviceID: String?
        var permissionState: AudioInputPermissionState = .unknown
        var selectedMode: AudioChannelMode = .mono
        var displayedChannels: [AudioInputChannel] = []
        var activeSelection: ChannelSelection?
        var stereoLeftCandidateID: String?
        var userMessage: AudioSourceUserMessage?
        var showsPermissionPrompt: Bool = false
        var hasNoEligibleDevices: Bool = false
        var rawDevices: [AudioInputDevice] = []
    }
}
