import SwiftUI
import UniformTypeIdentifiers

/// Settings › Library rows for the sessions folder (sessions-folder RF-1, RF-2): current folder,
/// Choose Folder…, Use App Folder, and on iPhone/iPad the warning while the App Folder is used.
struct SessionsFolderRows: View {
    @EnvironmentObject private var folders: SessionsFolderStore
    @State private var isChoosingFolder = false
    @State private var errorMessage: String?

    var body: some View {
        LabeledContent("Sessions folder") {
            Text(folders.displayName)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }

        if folders.isChosenFolderUnavailable {
            Label("The sessions folder isn't available. New sessions are saved in the App Folder.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
        }

        Button("Choose Folder…") { isChoosingFolder = true }
            .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let url):
                    do {
                        try folders.choose(url)
                    } catch {
                        errorMessage = String(localized: "This folder can't be used. Choose another one.", comment: "Sessions folder: picked folder not accessible")
                    }
                case .failure:
                    break
                }
            }

        if !folders.isAppFolder || folders.isChosenFolderUnavailable {
            Button("Use App Folder") { folders.useAppFolder() }
        }

        if SessionsFolderLogic.showsAppFolderWarning(isAppFolder: folders.isAppFolder && !folders.isChosenFolderUnavailable, isMac: isMac) {
            Label("Sessions in the App Folder are deleted if you delete the app. Choose another folder to keep them.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
        }

        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}
