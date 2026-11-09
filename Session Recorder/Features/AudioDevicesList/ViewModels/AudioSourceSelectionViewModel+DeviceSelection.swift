import Foundation

extension AudioSourceSelectionViewModel {
    func selectDevice(id: String) {
        guard rawDevices.contains(where: { $0.id == id }) else { return }
        selectedDeviceID = id
        stereoLeftCandidateID = nil
        userMessage = nil
        Task {
            await service.requestPermissionForDeviceSelection()
            applyStateAfterDeviceSelection()
        }
    }

    func retryPermission() {
        guard selectedDeviceID != nil else { return }
        Task {
            await service.requestPermissionForDeviceSelection()
            applyStateAfterDeviceSelection()
        }
    }

    func refreshFromService() {
        rawDevices = service.devices
        permissionState = service.permissionState
        devices = AudioDeviceSelectionHelper.disambiguateDeviceNames(rawDevices)
        hasNoEligibleDevices = rawDevices.isEmpty

        if let selectedDeviceID {
            let disconnect = AudioDeviceSelectionHelper.disconnectResult(
                selectedDeviceID: selectedDeviceID,
                availableDeviceIDs: Set(rawDevices.map(\.id))
            )
            if disconnect.shouldClearSelection {
                clearSelectionForDisconnect()
            }
        }

        refreshDisplayedState()
    }

    func applyStateAfterDeviceSelection() {
        permissionState = service.permissionState
        if permissionState != .granted {
            showsPermissionPrompt = true
            activeSelection = nil
            displayedChannels = []
            userMessage = makeMessage(kind: .permissionRequired, text: "Permission must be granted to access audio input channels.", showsRetry: true)
            return
        }
        showsPermissionPrompt = false
        userMessage = nil
        restoreOrInitializeForSelectedDevice()
    }

    func restoreOrInitializeForSelectedDevice() {
        guard let device = selectedDevice, permissionState == .granted else {
            displayedChannels = []
            activeSelection = nil
            return
        }

        displayedChannels = device.channels
        if device.channels.isEmpty {
            activeSelection = nil
            userMessage = makeMessage(kind: .noChannelsAvailable, text: "No channels are available for this device.", showsRetry: false)
            return
        }

        let saved = store.record(for: device.id)
        let restored = AudioDeviceSelectionHelper.restoreSelection(
            savedSelection: saved,
            isDeviceReliablyIdentified: rawDevices.contains(where: { $0.id == device.id }),
            availableChannels: device.channels
        )

        if let selection = restored.selection {
            activeSelection = selection
            selectedMode = selection.mode
            rememberValidSelection(selection, for: device.id)
            userMessage = nil
            if selectedMode == .stereo && !canSelectStereo {
                fallbackToMonoForSingleChannel(device: device)
            }
            return
        }

        if let saved, AudioDeviceSelectionHelper.invalidSelectionResult(selection: saved, availableChannels: device.channels).showsNoValidChannelError {
            activeSelection = nil
            userMessage = makeMessage(kind: .noValidChannelAvailable, text: "No valid channel is available for this device.", showsRetry: false)
            return
        }

        initializeDefaults(for: device)
    }

    func initializeDefaults(for device: AudioInputDevice) {
        if device.channels.count == 1, let mono = AudioDeviceSelectionHelper.initialMonoSelection(availableChannels: device.channels) {
            activeSelection = mono
            selectedMode = .mono
            rememberValidSelection(mono, for: device.id)
            userMessage = nil
            return
        }

        let mono = AudioDeviceSelectionHelper.initialMonoSelection(availableChannels: device.channels)
        activeSelection = mono
        selectedMode = .mono
        if let mono { rememberValidSelection(mono, for: device.id) }
        if let stereo = AudioDeviceSelectionHelper.initialStereoSelection(availableChannels: device.channels) {
            rememberValidSelection(stereo, for: device.id)
        }
        userMessage = nil
    }

    func refreshDisplayedState() {
        guard let device = selectedDevice else {
            displayedChannels = []
            showsPermissionPrompt = false
            if userMessage?.kind == .deviceDisconnected {
                return
            }
            if rawDevices.isEmpty {
                userMessage = nil
            }
            return
        }

        if permissionState != .granted {
            displayedChannels = []
            showsPermissionPrompt = true
            if userMessage?.kind != .deviceDisconnected {
                userMessage = makeMessage(kind: .permissionRequired, text: "Permission must be granted to access audio input channels.", showsRetry: true)
            }
            return
        }

        showsPermissionPrompt = false
        displayedChannels = device.channels

        if device.channels.isEmpty {
            activeSelection = nil
            if userMessage?.kind != .deviceDisconnected {
                userMessage = makeMessage(kind: .noChannelsAvailable, text: "No channels are available for this device.", showsRetry: false)
            }
            return
        }

        if let activeSelection {
            let validity = AudioDeviceSelectionHelper.invalidSelectionResult(selection: activeSelection, availableChannels: device.channels)
            if validity.showsNoValidChannelError {
                self.activeSelection = nil
                userMessage = makeMessage(kind: .noValidChannelAvailable, text: "No valid channel is available for this device.", showsRetry: false)
                return
            }
        }

        if selectedMode == .stereo && !canSelectStereo {
            fallbackToMonoForSingleChannel(device: device)
            return
        }

        if userMessage?.kind != .deviceDisconnected {
            userMessage = nil
        }
    }

    func clearSelectionForDisconnect() {
        if let selectedDeviceID {
            store.removeSelection(for: selectedDeviceID)
        }
        selectedDeviceID = nil
        activeSelection = nil
        displayedChannels = []
        stereoLeftCandidateID = nil
        showsPermissionPrompt = false
        userMessage = makeMessage(kind: .deviceDisconnected, text: "The selected audio device was disconnected.", showsRetry: false)
    }
}
