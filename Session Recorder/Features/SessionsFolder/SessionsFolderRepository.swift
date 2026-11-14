import Foundation

/// The chosen sessions folder, stored as a system access bookmark under the approved key
/// `sessions_folder_bookmark_v1` (spec RF-1, NFR-3). No bookmark = App Folder.
final class SessionsFolderRepository {
    private let defaults: UserDefaults
    private let bookmarkKey: String

    init(defaults: UserDefaults = .standard, bookmarkKey: String = "sessions_folder_bookmark_v1") {
        self.defaults = defaults
        self.bookmarkKey = bookmarkKey
    }

    var bookmark: Data? {
        defaults.data(forKey: bookmarkKey)
    }

    func saveBookmark(_ data: Data) {
        defaults.set(data, forKey: bookmarkKey)
    }

    /// Back to the App Folder.
    func clearBookmark() {
        defaults.removeObject(forKey: bookmarkKey)
    }
}
