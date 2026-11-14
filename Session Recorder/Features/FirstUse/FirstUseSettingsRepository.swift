import Foundation

/// Remembers that the first-use explanation was shown (approved key `first_use_explained_v1`; NFR-3).
final class FirstUseSettingsRepository {
    private let defaults: UserDefaults
    private let explainedKey: String

    init(defaults: UserDefaults = .standard, explainedKey: String = "first_use_explained_v1") {
        self.defaults = defaults
        self.explainedKey = explainedKey
    }

    var wasExplained: Bool {
        defaults.bool(forKey: explainedKey)
    }

    func markExplained() {
        defaults.set(true, forKey: explainedKey)
    }
}
