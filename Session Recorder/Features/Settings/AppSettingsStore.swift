import Combine
import Foundation

/// The app's settings, shared by every window and the Mac Settings window (created once in `MyApp`), so a
/// change applies everywhere at once. Saved on every change (RF-1).
@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            repository.saveSettings(settings)
        }
    }

    @Published var sortOrder: SessionSortOrder {
        didSet {
            guard sortOrder != oldValue else { return }
            repository.saveSortOrder(sortOrder)
        }
    }

    private let repository: AppSettingsRepository

    init(repository: AppSettingsRepository? = nil) {
        let repository = repository ?? AppSettingsRepository()
        self.repository = repository
        settings = repository.loadSettings()
        sortOrder = repository.loadSortOrder()
    }
}
