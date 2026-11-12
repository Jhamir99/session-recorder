import Combine
import Foundation
import os

/// Coordinates audio capture with the selected source (plan §5). For now: live level meters (RF-2);
/// the recording state machine is added in T8.
@MainActor
final class RecordingViewModel: ObservableObject {
    /// One level per recorded channel: mono 1, stereo left then right.
    @Published private(set) var levels: [ChannelLevel] = []
    /// Native capture format of the device (plan §3 spike; shown in debug builds only).
    @Published private(set) var nativeFormatDescription: String?

    let capture: AudioCaptureService
    private let logger = Logger(subsystem: "SessionRecorder", category: "Recording")
    private weak var audioSource: AudioSourceSelectionViewModel?
    private var lastClipDates: [Date?] = []
    private var cancellables: Set<AnyCancellable> = []

    init(capture: AudioCaptureService? = nil) {
        self.capture = capture ?? AudioCaptureService()
        bindCapture()
    }

    /// Connects to the shared source selection; meters follow it automatically. Safe to call more than once.
    func attach(audioSource: AudioSourceSelectionViewModel) {
        guard self.audioSource !== audioSource else { return }
        self.audioSource = audioSource
        // objectWillChange fires before the change; receiving on the run loop reads the new values.
        audioSource.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMetering() }
            .store(in: &cancellables)
        updateMetering()
    }

    /// Device ID and channel numbers (selection order) of a valid, permitted source; nil otherwise.
    private var meteringSource: (deviceID: String, channelNumbers: [Int])? {
        guard let audioSource, let deviceID = audioSource.selectedDeviceID,
              case .selected(_, _, let channelNumbers) = audioSource.sourceSummary,
              !channelNumbers.isEmpty else { return nil }
        return (deviceID, channelNumbers)
    }

    private func updateMetering() {
        guard let source = meteringSource else {
            capture.stop()
            return
        }
        do {
            try capture.start(deviceID: source.deviceID, channelNumbers: source.channelNumbers)
        } catch {
            logger.error("Cannot start level meters: \(String(describing: error), privacy: .public)")
            capture.stop()
        }
    }

    private func bindCapture() {
        capture.$peaks
            .sink { [weak self] peaks in self?.updateLevels(peaks: peaks) }
            .store(in: &cancellables)
        capture.$nativeFormatDescription
            .sink { [weak self] format in self?.nativeFormatDescription = format }
            .store(in: &cancellables)
    }

    private func updateLevels(peaks: [Float], now: Date = Date()) {
        if lastClipDates.count != peaks.count {
            lastClipDates = Array(repeating: nil, count: peaks.count)
        }
        levels = peaks.enumerated().map { index, peak in
            if RecordingLogic.isClipping(peak: peak) {
                lastClipDates[index] = now
            }
            return ChannelLevel(
                peak: peak,
                isClipping: RecordingLogic.isClipIndicatorVisible(lastClipDate: lastClipDates[index], now: now)
            )
        }
    }
}
