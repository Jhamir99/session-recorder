import Foundation

struct StoredChannelSelection: Codable, Equatable {
    let deviceID: String
    let selection: ChannelSelection
}

final class AudioDeviceSelectionRepository {
    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "audio_device_channel_selections_v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func record(for deviceID: String) -> ChannelSelection? {
        allRecords()[deviceID]?.selection
    }

    func allRecords() -> [String: StoredChannelSelection] {
        guard let data = defaults.data(forKey: storageKey),
              let records = try? decoder.decode([String: StoredChannelSelection].self, from: data) else {
            return [:]
        }
        return records
    }

    func saveValidSelection(_ selection: ChannelSelection, for deviceID: String) {
        guard isValidForStorage(selection) else { return }
        var records = allRecords()
        records[deviceID] = StoredChannelSelection(deviceID: deviceID, selection: selection)
        persist(records)
    }

    func removeSelection(for deviceID: String) {
        var records = allRecords()
        records.removeValue(forKey: deviceID)
        persist(records)
    }

    private func isValidForStorage(_ selection: ChannelSelection) -> Bool {
        switch selection.mode {
        case .mono:
            guard let monoChannelID = selection.monoChannelID else { return false }
            return !monoChannelID.isEmpty
        case .stereo:
            guard let leftID = selection.stereoLeftChannelID,
                  let rightID = selection.stereoRightChannelID else { return false }
            return !leftID.isEmpty && !rightID.isEmpty && leftID != rightID
        }
    }

    private func persist(_ records: [String: StoredChannelSelection]) {
        guard let data = try? encoder.encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
