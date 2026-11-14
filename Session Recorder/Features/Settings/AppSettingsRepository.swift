import Foundation

/// Local settings storage (approved keys): `app_settings_v1` (all settings as JSON; bad or missing data →
/// defaults) and `library_sort_order_v1`. No personal data (NFR-2).
final class AppSettingsRepository {
    private let defaults: UserDefaults
    private let settingsKey: String
    private let sortOrderKey: String

    init(
        defaults: UserDefaults = .standard,
        settingsKey: String = "app_settings_v1",
        sortOrderKey: String = "library_sort_order_v1"
    ) {
        self.defaults = defaults
        self.settingsKey = settingsKey
        self.sortOrderKey = sortOrderKey
    }

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else { return .defaults }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }

    func loadSortOrder() -> SessionSortOrder {
        defaults.string(forKey: sortOrderKey).flatMap(SessionSortOrder.init(rawValue:)) ?? .newestFirst
    }

    func saveSortOrder(_ order: SessionSortOrder) {
        defaults.set(order.rawValue, forKey: sortOrderKey)
    }
}
