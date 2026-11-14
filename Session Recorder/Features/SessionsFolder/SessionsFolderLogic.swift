import Foundation

/// Folder where finished sessions are read and written (spec RF-1, RF-5).
nonisolated enum SessionsFolderInUse: Equatable {
    /// The app's own `Documents/Sessions` (deleted with the app on iPhone/iPad).
    case app(URL)
    /// The folder the user chose.
    case chosen(URL)
    /// A folder was chosen but cannot be accessed now: the App Folder is used meanwhile.
    case fallback(app: URL, unavailable: URL)

    /// Where sessions are written and listed right now.
    var url: URL {
        switch self {
        case .app(let url), .chosen(let url): url
        case .fallback(let app, _): app
        }
    }

    var isAppFolder: Bool {
        if case .chosen = self { return false }
        return true
    }
}

/// Pure sessions-folder rules (plan §2): explicit inputs, no I/O.
nonisolated enum SessionsFolderLogic {
    static func folderInUse(appFolder: URL, chosen: URL?, isChosenAvailable: Bool) -> SessionsFolderInUse {
        guard let chosen else { return .app(appFolder) }
        return isChosenAvailable ? .chosen(chosen) : .fallback(app: appFolder, unavailable: chosen)
    }

    /// iPhone/iPad only: the App Folder is deleted with the app (RF-2).
    static func showsAppFolderWarning(isAppFolder: Bool, isMac: Bool) -> Bool {
        isAppFolder && !isMac
    }

    /// A picked folder inside the app's own storage counts as the App Folder (edge case).
    static func isInsideAppStorage(_ url: URL, appContainer: URL) -> Bool {
        let folder = url.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        let container = appContainer.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        let prefix = container.hasSuffix("/") ? container : container + "/"
        return folder == container || folder.hasPrefix(prefix)
    }

    /// `name.caf`, or `name (2).caf`, `name (3).caf`… when taken (case-insensitive, like file systems).
    static func uniqueFileName(name: String, fileExtension: String, existingFileNames: Set<String>) -> String {
        let taken = Set(existingFileNames.map { $0.lowercased() })
        let first = "\(name).\(fileExtension)"
        guard taken.contains(first.lowercased()) else { return first }
        var number = 2
        while taken.contains("\(name) (\(number)).\(fileExtension)".lowercased()) {
            number += 1
        }
        return "\(name) (\(number)).\(fileExtension)"
    }

    /// Result of moving sessions to a new folder (RF-3).
    static func moveSummary(moved: Int, failed: Int) -> String {
        if failed == 0 {
            return moved == 1
                ? String(localized: "Moved 1 session.", comment: "Sessions folder: move result")
                : String(localized: "Moved \(moved) sessions.", comment: "Sessions folder: move result")
        }
        return failed == 1
            ? String(localized: "Moved \(moved) sessions. 1 session could not be moved and stays in the previous folder.", comment: "Sessions folder: move result with a failure")
            : String(localized: "Moved \(moved) sessions. \(failed) sessions could not be moved and stay in the previous folder.", comment: "Sessions folder: move result with failures")
    }
}
