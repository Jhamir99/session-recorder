import Foundation

extension AudioSourceSelectionViewModel {
    func selectDevice(id: String) {
        guard rawDevices.contains(where: { $0.id == id }) else { return }
        selectedDeviceID = id
        routeInputToSelectedDevice()
        stereoLeftCandidateID = nil
        userMessage = nil
        userChangedSourceManually = true
        replacedDeviceID = nil
        store.saveLastSelectedDeviceID(id)
        // No system prompt here: access is asked only from Continue / Allow Audio Input (first-use NFR-2).
        service.refreshPermissionState()
        applyStateAfterDeviceSelection()
    }

    /// Asks for audio-input access (first-use RF-1/RF-3). When granted, the selected or automatically
    /// chosen source is applied, so meters appear without a restart (RF-2).
    func requestAccess() async {
        await service.requestPermission()
        guard service.permissionState == .granted else {
            applyStateAfterDeviceSelection()
            return
        }
        if let selectedDeviceID {
            autoSelectDevice(id: selectedDeviceID, notice: nil)
        } else if let id = AudioDeviceSelectionHelper.launchSelection(devices: rawDevices, lastSelectedDeviceID: store.lastSelectedDeviceID) {
            autoSelectDevice(id: id, notice: nil)
        }
    }

    func refreshFromService() {
        let previousDeviceIDs = Set(rawDevices.map(\.id))
        let previousLabels = devices
        rawDevices = service.devices
        permissionState = service.permissionState
        devices = AudioDeviceSelectionHelper.disambiguateDeviceNames(rawDevices)
        hasNoEligibleDevices = rawDevices.isEmpty

        // RF-7 order: launch selection (once), disconnect, reconnect, connect.
        if !hasAppliedLaunchSelection {
            hasAppliedLaunchSelection = true
            if let id = AudioDeviceSelectionHelper.launchSelection(
                devices: rawDevices,
                lastSelectedDeviceID: store.lastSelectedDeviceID
            ) {
                autoSelectDevice(id: id, notice: nil)
                return
            }
        }

        if let selectedDeviceID {
            let disconnect = AudioDeviceSelectionHelper.disconnectResult(
                selectedDeviceID: selectedDeviceID,
                availableDeviceIDs: Set(rawDevices.map(\.id))
            )
            if disconnect.shouldClearSelection {
                handleSelectedDeviceDisconnect(
                    disconnectedDeviceID: selectedDeviceID,
                    disconnectedLabel: previousLabels.first(where: { $0.id == selectedDeviceID })?.displayLabel
                )
                return
            }
        }

        // While a recording exists the source is locked, but the recording device itself may come back:
        // select it again (no notice) so input is routed to it and the row shows it (recording RF-8).
        if isSourceLocked, selectedDeviceID == nil, let id = replacedDeviceID, rawDevices.contains(where: { $0.id == id }) {
            replacedDeviceID = nil
            autoSelectDevice(id: id, notice: nil)
            return
        }

        if !isSourceLocked, let id = AudioDeviceSelectionHelper.reselectionOnReconnect(
            replacedDeviceID: replacedDeviceID,
            userChangedSourceManually: userChangedSourceManually,
            devices: rawDevices
        ), id != selectedDeviceID {
            replacedDeviceID = nil
            autoSelectDevice(id: id, notice: String(localized: "Switched back to \(label(for: id)).", comment: "Audio source message"))
            return
        }

        if !isSourceLocked, let id = AudioDeviceSelectionHelper.selectionOnConnect(
            previousDeviceIDs: previousDeviceIDs,
            devices: rawDevices,
            selectedDeviceID: selectedDeviceID
        ) {
            autoSelectDevice(id: id, notice: String(localized: "Switched to \(label(for: id)).", comment: "Audio source message"))
            return
        }

        refreshDisplayedState()
    }

    /// Selects a device without user action (RF-7). Never shows the system permission prompt:
    /// it only checks the current status; if not granted, the permission message and retry appear (RF-4).
    /// `noticeKind`: `.deviceDisconnected` when the source changed because the selected device went away.
    func autoSelectDevice(id: String, notice: String?, noticeKind: AudioSourceUserMessage.Kind = .sourceChangedAutomatically) {
        selectedDeviceID = id
        routeInputToSelectedDevice()
        stereoLeftCandidateID = nil
        userMessage = nil
        store.saveLastSelectedDeviceID(id)
        service.refreshPermissionState()
        applyStateAfterDeviceSelection()
        // Do not replace permission/channel errors: they drive the sheet's retry action and messages.
        if let notice, userMessage == nil {
            userMessage = makeMessage(kind: noticeKind, text: notice, showsRetry: false)
        }
    }

    /// The selected device disconnected: fall back to another device (RF-7) or clear (RF-5).
    /// Its saved channel selection is kept so it can be restored when it reconnects.
    func handleSelectedDeviceDisconnect(disconnectedDeviceID: String, disconnectedLabel: String?) {
        replacedDeviceID = disconnectedDeviceID
        userChangedSourceManually = false
        let fallbackID = isSourceLocked ? nil : AudioDeviceSelectionHelper.fallbackOnDisconnect(
            devices: rawDevices,
            disconnectedDeviceID: disconnectedDeviceID
        )
        guard let fallbackID else {
            clearSelectionForDisconnect()
            return
        }
        let disconnectedName = disconnectedLabel ?? String(localized: "The selected audio device", comment: "Used when the disconnected device name is unknown")
        autoSelectDevice(id: fallbackID, notice: String(localized: "\(disconnectedName) was disconnected. Switched to \(label(for: fallbackID)).", comment: "Audio source message"),
                         noticeKind: .deviceDisconnected)
    }

    /// On iOS the input route decides which device is captured and how many channels it exposes,
    /// so route first and read the updated channels before restoring the channel selection.
    private func routeInputToSelectedDevice() {
        guard let selectedDeviceID else { return }
        service.preferInput(deviceID: selectedDeviceID)
        rawDevices = service.devices
        devices = AudioDeviceSelectionHelper.disambiguateDeviceNames(rawDevices)
    }

    private func label(for deviceID: String) -> String {
        devices.first(where: { $0.id == deviceID })?.displayLabel ?? String(localized: "another audio device", comment: "Used when the new device name is unknown")
    }

    func applyStateAfterDeviceSelection() {
        permissionState = service.permissionState
        if permissionState != .granted {
            showsPermissionPrompt = true
            activeSelection = nil
            displayedChannels = []
            userMessage = makeMessage(kind: .permissionRequired, text: String(localized: "Permission must be granted to access audio input channels.", comment: "Audio source message"), showsRetry: true)
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
            userMessage = makeMessage(kind: .noChannelsAvailable, text: String(localized: "No channels are available for this device.", comment: "Audio source message"), showsRetry: false)
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
            // While the session is changing the device may briefly show 1 channel; keep Stereo.
            if selectedMode == .stereo && !canSelectStereo && !service.isRoutingInput {
                fallbackToMonoForSingleChannel(device: device)
            }
            return
        }

        if let saved, AudioDeviceSelectionHelper.invalidSelectionResult(selection: saved, availableChannels: device.channels).showsNoValidChannelError {
            activeSelection = nil
            // Channels are not final while input is being routed to this device: wait, no error yet.
            if service.isRoutingInput { return }
            userMessage = makeMessage(kind: .noValidChannelAvailable, text: String(localized: "No valid channel is available for this device.", comment: "Audio source message"), showsRetry: false)
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

        // Multi-channel devices start in Stereo with channels 1–2 (mono default stays 1 for the Mono tab).
        let mono = AudioDeviceSelectionHelper.initialMonoSelection(availableChannels: device.channels)
        let stereo = AudioDeviceSelectionHelper.initialStereoSelection(availableChannels: device.channels)
        if let mono { rememberValidSelection(mono, for: device.id) }
        if let stereo { rememberValidSelection(stereo, for: device.id) }
        activeSelection = stereo ?? mono
        selectedMode = stereo != nil ? .stereo : .mono
        userMessage = nil
    }

    func refreshDisplayedState() {
        guard let device = selectedDevice else {
            displayedChannels = []
            showsPermissionPrompt = false
            if userMessage?.isSourceChangeNotice == true {
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
            if userMessage?.isSourceChangeNotice != true {
                userMessage = makeMessage(kind: .permissionRequired, text: String(localized: "Permission must be granted to access audio input channels.", comment: "Audio source message"), showsRetry: true)
            }
            return
        }

        showsPermissionPrompt = false
        let channelsChanged = displayedChannels != device.channels
        displayedChannels = device.channels

        // The device exposed new channels (e.g., iOS opened all of a mixer's inputs after routing):
        // try the saved selection again, or recompute the defaults if nothing was saved for this device
        // (so a mixer first seen with 1 channel ends up in Stereo 1–2). If the saved selection is still
        // invalid, the no-valid-channel error stays.
        // No selection and no message means the restore waited for routing to finish (see restore).
        // A source-change notice ("Switched to …") may be showing; it is kept after the restore.
        let sourceChangeNotice = userMessage?.isSourceChangeNotice == true ? userMessage : nil
        let restoreWaitedForRouting = activeSelection == nil
            && (userMessage == nil || sourceChangeNotice != nil)
            && !service.isRoutingInput
        if !device.channels.isEmpty,
           restoreWaitedForRouting || (channelsChanged && (activeSelection == nil || store.record(for: device.id) == nil)) {
            restoreOrInitializeForSelectedDevice()
            if let sourceChangeNotice, userMessage == nil {
                userMessage = sourceChangeNotice
            }
            return
        }

        if device.channels.isEmpty {
            activeSelection = nil
            if userMessage?.isSourceChangeNotice != true {
                userMessage = makeMessage(kind: .noChannelsAvailable, text: String(localized: "No channels are available for this device.", comment: "Audio source message"), showsRetry: false)
            }
            return
        }

        if let activeSelection {
            let validity = AudioDeviceSelectionHelper.invalidSelectionResult(selection: activeSelection, availableChannels: device.channels)
            if validity.showsNoValidChannelError {
                self.activeSelection = nil
                if service.isRoutingInput { return }
                userMessage = makeMessage(kind: .noValidChannelAvailable, text: String(localized: "No valid channel is available for this device.", comment: "Audio source message"), showsRetry: false)
                return
            }
        }

        if selectedMode == .stereo && !canSelectStereo && !service.isRoutingInput {
            fallbackToMonoForSingleChannel(device: device)
            return
        }

        if userMessage?.isSourceChangeNotice != true {
            userMessage = nil
        }
    }

    func clearSelectionForDisconnect() {
        // Saved channel selection is kept (RF-5) so it can be restored on reconnect.
        selectedDeviceID = nil
        activeSelection = nil
        displayedChannels = []
        stereoLeftCandidateID = nil
        showsPermissionPrompt = false
        userMessage = makeMessage(kind: .deviceDisconnected, text: String(localized: "The selected audio device was disconnected.", comment: "Audio source message"), showsRetry: false)
    }
}
