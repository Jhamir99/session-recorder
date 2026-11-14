import Foundation

/// Local library settings (RF-6): the last export format and AAC bitrate. No personal data (NFR-5).
final class SessionLibrarySettingsRepository {
    private let defaults: UserDefaults
    private let exportChoiceKey: String

    init(defaults: UserDefaults = .standard, exportChoiceKey: String = "library_export_format_v1") {
        self.defaults = defaults
        self.exportChoiceKey = exportChoiceKey
    }

    var exportChoice: ExportChoice {
        guard let data = defaults.data(forKey: exportChoiceKey),
              let choice = try? JSONDecoder().decode(ExportChoice.self, from: data) else { return .default }
        return choice
    }

    func saveExportChoice(_ choice: ExportChoice) {
        guard let data = try? JSONEncoder().encode(choice) else { return }
        defaults.set(data, forKey: exportChoiceKey)
    }
}
