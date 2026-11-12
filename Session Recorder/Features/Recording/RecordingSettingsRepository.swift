import Foundation

/// Local recording settings (RF-1, RF-3). Device IDs and numbers only; no personal data (NFR-5).
final class RecordingSettingsRepository {
    private let defaults: UserDefaults
    private let qualityKey: String
    private let tipDismissedKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        qualityKey: String = "recording_quality_by_device_v1",
        tipDismissedKey: String = "recording_dnd_tip_dismissed_v1"
    ) {
        self.defaults = defaults
        self.qualityKey = qualityKey
        self.tipDismissedKey = tipDismissedKey
    }

    // MARK: Per-device quality (RF-1)

    func quality(for deviceID: String) -> RecordingQuality? {
        allQualities()[deviceID]
    }

    func saveQuality(_ quality: RecordingQuality, for deviceID: String) {
        guard !deviceID.isEmpty else { return }
        var qualities = allQualities()
        qualities[deviceID] = quality
        guard let data = try? encoder.encode(qualities) else { return }
        defaults.set(data, forKey: qualityKey)
    }

    private func allQualities() -> [String: RecordingQuality] {
        guard let data = defaults.data(forKey: qualityKey),
              let qualities = try? decoder.decode([String: RecordingQuality].self, from: data) else {
            return [:]
        }
        return qualities
    }

    // MARK: Do Not Disturb tip (RF-3)

    var isDoNotDisturbTipDismissed: Bool {
        defaults.bool(forKey: tipDismissedKey)
    }

    func dismissDoNotDisturbTip() {
        defaults.set(true, forKey: tipDismissedKey)
    }
}
