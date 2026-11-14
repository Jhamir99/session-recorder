import SwiftUI

// Sessions folder previews (C5): Settings rows with the App Folder (warning on iPhone/iPad), a chosen folder,
// an unavailable folder, moving sessions and the move result; and the library notice.
// Preview stores use their own UserDefaults suite and never touch a real folder.

@MainActor
private func previewFolders(
    _ folder: SessionsFolderInUse,
    moveProgress: (done: Int, total: Int)? = nil,
    moveResult: String? = nil
) -> SessionsFolderStore {
    let store = SessionsFolderStore(repository: SessionsFolderRepository(
        defaults: UserDefaults(suiteName: "preview.folders") ?? .standard,
        bookmarkKey: "preview_bookmark"
    ))
    store.applyPreview(folder: folder, moveProgress: moveProgress, moveResult: moveResult)
    return store
}

private let previewAppFolder = URL(fileURLWithPath: "/App/Documents/Sessions")
private let previewChosenFolder = URL(fileURLWithPath: "/Volumes/DJ Drive/Recordings")

private struct FolderRowsPreview: View {
    let store: SessionsFolderStore

    var body: some View {
        Form {
            Section("Library") {
                SessionsFolderRows()
            }
        }
        .environmentObject(store)
    }
}

#Preview("App Folder") {
    FolderRowsPreview(store: previewFolders(.app(previewAppFolder)))
}

#Preview("Chosen folder") {
    FolderRowsPreview(store: previewFolders(.chosen(previewChosenFolder)))
}

#Preview("Folder unavailable") {
    FolderRowsPreview(store: previewFolders(.fallback(app: previewAppFolder, unavailable: previewChosenFolder)))
}

#Preview("Moving sessions") {
    FolderRowsPreview(store: previewFolders(.chosen(previewChosenFolder), moveProgress: (7, 24)))
}

#Preview("Move result") {
    FolderRowsPreview(store: previewFolders(
        .chosen(previewChosenFolder),
        moveResult: SessionsFolderLogic.moveSummary(moved: 22, failed: 2)
    ))
}

#Preview("Library notice") {
    SessionsFolderUnavailableBanner(folders: previewFolders(.fallback(app: previewAppFolder, unavailable: previewChosenFolder)))
}

#Preview("App Folder (Spanish)") {
    FolderRowsPreview(store: previewFolders(.app(previewAppFolder)))
        .environment(\.locale, Locale(identifier: "es"))
}
