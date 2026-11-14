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
        switch RecordingLogic.storageDecision(remainingSeconds: remainingSeconds, warningAlreadyShown: isLowStorageWarningShown) {
        case .none:
            break
        case .warn:
            isLowStorageWarningShown = true
            show(RecordingNotice(kind: .lowStorageWarning))
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
        let names = fileStore.recoverInterruptedRecordings()
        names.forEach { sessionSaved.send($0) }
        if let name = names.last {
            show(RecordingNotice(kind: .recovered(sessionName: name)))
        }
    }

    private func isListed(_ deviceID: String, in audioSource: AudioSourceSelectionViewModel) -> Bool {
        audioSource.service.devices.contains(where: { $0.id == deviceID })
    }
}
