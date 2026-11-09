import Foundation

extension AudioSourceSelectionViewModel {
    func selectMode(_ mode: AudioChannelMode) {
        guard let device = selectedDevice else {
            selectedMode = mode
            return
        }
        selectedMode = mode
        stereoLeftCandidateID = nil
        if mode == .stereo && !canSelectStereo {
            selectedMode = .mono
        }
        replaceSavedSelectionForCurrentMode(device: device)
        refreshDisplayedState()
    }

    func selectMonoChannel(id: String) {
        guard let device = selectedDevice, permissionState == .granted else { return }
        let decision = AudioDeviceSelectionHelper.saveDecisionForMono(channelID: id, availableChannels: device.channels)
        guard case .save(let selection) = decision else { return }
        activeSelection = selection
        selectedMode = .mono
        lastValidMonoByDevice[device.id] = id
        store.saveValidSelection(selection, for: device.id)
        userMessage = nil
        refreshDisplayedState()
    }

    func selectStereoChannel(id: String) {
        guard let device = selectedDevice, permissionState == .granted, canSelectStereo else { return }
        if let left = stereoLeftCandidateID {
            let decision = AudioDeviceSelectionHelper.saveDecisionForStereo(
                leftChannelID: left,
                rightChannelID: id,
                availableChannels: device.channels
            )
            if case .save(let selection) = decision {
                activeSelection = selection
                selectedMode = .stereo
                lastValidStereoByDevice[device.id] = (left: left, right: id)
                store.saveValidSelection(selection, for: device.id)
                stereoLeftCandidateID = nil
                userMessage = nil
            } else {
                stereoLeftCandidateID = nil
            }
        } else {
            stereoLeftCandidateID = id
        }
        refreshDisplayedState()
    }

    func selectStereoLeftChannel(id: String) {
        guard let device = selectedDevice, permissionState == .granted, canSelectStereo else { return }
        let currentRight = activeSelection?.mode == .stereo ? activeSelection?.stereoRightChannelID : nil
        if let currentRight, currentRight != id {
            let decision = AudioDeviceSelectionHelper.saveDecisionForStereo(
                leftChannelID: id,
                rightChannelID: currentRight,
                availableChannels: device.channels
            )
            if case .save(let selection) = decision {
                activeSelection = selection
                selectedMode = .stereo
                lastValidStereoByDevice[device.id] = (left: id, right: currentRight)
                store.saveValidSelection(selection, for: device.id)
                stereoLeftCandidateID = nil
                userMessage = nil
                refreshDisplayedState()
                return
            }
        }
        stereoLeftCandidateID = id
        if activeSelection?.mode == .stereo {
            activeSelection = nil
        }
        userMessage = nil
        refreshDisplayedState()
    }

    func selectStereoRightChannel(id: String) {
        guard let device = selectedDevice, permissionState == .granted, canSelectStereo else { return }
        let left = stereoLeftCandidateID ?? (activeSelection?.mode == .stereo ? activeSelection?.stereoLeftChannelID : nil)
        guard let left else { return }
        let decision = AudioDeviceSelectionHelper.saveDecisionForStereo(
            leftChannelID: left,
            rightChannelID: id,
            availableChannels: device.channels
        )
        if case .save(let selection) = decision {
            activeSelection = selection
            selectedMode = .stereo
            lastValidStereoByDevice[device.id] = (left: left, right: id)
            store.saveValidSelection(selection, for: device.id)
            stereoLeftCandidateID = nil
            userMessage = nil
        }
        refreshDisplayedState()
    }

    func replaceSavedSelectionForCurrentMode(device: AudioInputDevice) {
        let replacement = AudioDeviceSelectionHelper.replacementSelectionForTabSwitch(
            mode: selectedMode,
            latestValidMonoChannelID: lastValidMonoByDevice[device.id] ?? activeMonoChannelID(for: device.id),
            latestValidStereoLeftChannelID: lastValidStereoByDevice[device.id]?.left ?? activeStereoLeftID(for: device.id),
            latestValidStereoRightChannelID: lastValidStereoByDevice[device.id]?.right ?? activeStereoRightID(for: device.id),
            availableChannels: device.channels
        )
        if let replacement {
            activeSelection = replacement
            store.saveValidSelection(replacement, for: device.id)
            rememberValidSelection(replacement, for: device.id)
        }
    }

    func fallbackToMonoForSingleChannel(device: AudioInputDevice) {
        guard let mono = AudioDeviceSelectionHelper.initialMonoSelection(availableChannels: device.channels) else { return }
        selectedMode = .mono
        activeSelection = mono
        rememberValidSelection(mono, for: device.id)
        store.saveValidSelection(mono, for: device.id)
    }
}
