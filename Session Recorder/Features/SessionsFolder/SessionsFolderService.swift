import Foundation

/// Apple-API boundary for the chosen sessions folder (plan §2): access bookmarks, security-scoped access
/// and availability. Moving sessions is added with the move flow.
nonisolated enum SessionsFolderService {
    enum FolderError: Error {
        case notAccessible
    }

    /// The app's own `Documents/Sessions`.
    static var appFolder: URL { SessionFileStore.defaultSessionsDirectory }

    /// Root of the app's own storage (the sandbox container on Mac, the app's home on iOS).
    static var appContainer: URL { URL.homeDirectory }

    /// Bookmark that keeps access to a folder picked by the user. Mac needs a security-scoped bookmark
    /// (entitlement `com.apple.security.files.bookmarks.app-scope`); iOS keeps access with a plain one.
    static func makeBookmark(for url: URL) throws -> Data {
        #if os(macOS)
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        #endif
    }

    /// Folder URL from a saved bookmark; `isStale` means the bookmark should be created again.
    static func resolveBookmark(_ data: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = .withSecurityScope
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        guard let url = try? URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        return (url, isStale)
    }

    /// The folder exists and can be read (drive connected, not deleted, access still granted).
    static func isAvailable(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
            && isDirectory.boolValue
            && FileManager.default.isReadableFile(atPath: url.path(percentEncoded: false))
    }

    /// Name shown in Settings, as the system shows it (e.g. "iCloud Drive" folders keep their visible name).
    static func displayName(of url: URL) -> String {
        FileManager.default.displayName(atPath: url.path(percentEncoded: false))
    }
}
