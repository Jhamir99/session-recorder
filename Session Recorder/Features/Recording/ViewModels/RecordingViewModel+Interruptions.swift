import Combine
import Foundation

/// Device disconnect/reconnect, iOS audio interruptions and capture failures while a recording exists (RF-8).
extension RecordingViewModel {
    /// The recording device is listed again and iOS finished routing input to it.
    var isRecordingDeviceReady: Bool {
        guard let recordingDeviceID, let audioSource else { return false }
        return isListed(recordingDeviceID, in: audioSource) && !audioSource.service.isRoutingInput
    }

    /// Writing was already paused (or stopped) by the capture service when the event arrives.
    func handleCaptureEvent(_ event: AudioCaptureService.Event) {
        guard state.hasActiveRecording else { return }
        switch event {
        case .deviceDisconnected:
            handleRecordingDeviceDisconnected()
        case .interruptionBegan:
            // Already paused by the user: stays paused, no extra notice.
            guard state == .recording else { return }
            pause(reason: .interruption)
            show(RecordingNotice(kind: .interrupted))
        case .failed:
            finishRecording { name in RecordingNotice(kind: .recordingFailed(sessionName: name)) }
        }
    }

    /// Called for source changes while recording or paused (the source itself is locked).
    func recordingSourceDidChange() {
        guard let recordingDeviceID, let audioSource else { return }
        if !isListed(recordingDeviceID, in: audioSource) {
            // Backup for platforms/paths where capture did not report the disconnect.
            handleRecordingDeviceDisconnected()
        } else if isWaitingForDeviceReconnect, !audioSource.service.isRoutingInput {
            // Same device is back: capture it again; the user resumes when ready (no auto-resume).
            isWaitingForDeviceReconnect = false
            if let quality {
                audioSource.service.preferSampleRate(quality.sampleRate, deviceID: recordingDeviceID)
            }
            capture.restartCapture()
        }
    }

    private func handleRecordingDeviceDisconnected() {
        guard !isWaitingForDeviceReconnect else { return }
        isWaitingForDeviceReconnect = true
        capture.setWritingPaused(true)
        pause(reason: .deviceDisconnected)
        show(RecordingNotice(kind: .deviceDisconnected(deviceName: recordingDeviceName ?? "The audio device")))
    }

    // MARK: Low storage (RF-8)

    /// Called every second while recording or paused: warns once at ~10 min left, stops and saves at ~1 min.
    func checkStorage(remainingSeconds: TimeInterval) {
        // Recording time limit from Settings (settings RF-8); paused time is not counted.
        let limit = settingsStore?.settings.timeLimit ?? .off
        var reached = SettingsLogic.isTimeLimitReached(elapsedSeconds: liveInfo.elapsedSeconds, limit: limit)
        var title = limit.title.lowercased()
        #if DEBUG
        // Testing aid (Debug builds only): launch argument `-debug_time_limit_seconds 30` overrides the limit.
        let debugLimit = UserDefaults.standard.double(forKey: "debug_time_limit_seconds")
        if debugLimit > 0 {
            reached = liveInfo.elapsedSeconds >= debugLimit
            title = "\(Int(debugLimit)) seconds"
        }
        #endif
        if state == .recording, reached {
            finishRecording { name in RecordingNotice(kind: .timeLimitReached(limit: title, sessionName: name)) }
            return
        }
        let warning = settingsStore?.settings.lowStorageWarning ?? .tenMinutes
        switch RecordingLogic.storageDecision(
            remainingSeconds: remainingSeconds,
            warningAlreadyShown: isLowStorageWarningShown,
            warningSeconds: warning.seconds
        ) {
        case .none:
            break
        case .warn:
            isLowStorageWarningShown = true
            show(RecordingNotice(kind: .lowStorageWarning(minutes: Int(warning.seconds / 60))))
        case .stop:
            finishRecording { name in
                RecordingNotice(kind: name.map { .storageFull(sessionName: $0) } ?? .startFailed(.notEnoughStorage))
            }
        }
    }

    // MARK: Recovery after termination (RF-8, NFR-4)

    /// Saves recordings left in progress by a crash or termination. Runs once per launch, before any
    /// recording starts (a second window must not take the first window's file in progress).
    func recoverInterruptedRecordingsOnce() {
        guard !Self.hasRecoveredInterruptedRecordings else { return }
        Self.hasRecoveredInterruptedRecordings = true
        let names = fileStore.recoverInterruptedRecordings(prefix: currentNamePrefix, directory: sessionsFolderForSaving)
        names.forEach { sessionSaved.send($0) }
        if let name = names.last {
            show(RecordingNotice(kind: .recovered(sessionName: name)))
        }
    }

    private func isListed(_ deviceID: String, in audioSource: AudioSourceSelectionViewModel) -> Bool {
        audioSource.service.devices.contains(where: { $0.id == deviceID })
    }
}
