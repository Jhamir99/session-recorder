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
            .disabled(folders.moveProgress != nil)
            .confirmationDialog(
                moveDialogTitle,
                isPresented: Binding(
                    get: { folders.pendingChange != nil },
                    set: { isPresented in
                        guard !isPresented else { return }
                        Task { @MainActor in folders.cancelPendingChange() }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Move Sessions") { Task { @MainActor in folders.confirmPendingChange(moveSessions: true) } }
                Button("Keep Them") { Task { @MainActor in folders.confirmPendingChange(moveSessions: false) } }
                Button("Cancel", role: .cancel) { Task { @MainActor in folders.cancelPendingChange() } }
            } message: {
                Text("Sessions you keep stay in the current folder and are not shown until you switch back.", comment: "Sessions folder: move question detail")
            }
            .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let url):
                    // The picker can answer during a view update; change state after it.
                    Task { @MainActor in
                        do {
                            errorMessage = nil
                            try folders.requestChange(to: .chosen(url))
                        } catch {
                            errorMessage = String(localized: "This folder can't be used. Choose another one.", comment: "Sessions folder: picked folder not accessible")
                        }
                    }
                case .failure:
                    break
                }
            }

        if !folders.isAppFolder || folders.isChosenFolderUnavailable {
            Button("Use App Folder") {
                Task { @MainActor in try? folders.requestChange(to: .app) }
            }
        }

        if SessionsFolderLogic.showsAppFolderWarning(isAppFolder: folders.isAppFolder && !folders.isChosenFolderUnavailable, isMac: isMac) {
            Label("Sessions in the App Folder are deleted if you delete the app. Choose another folder to keep them.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
        }

        if let progress = folders.moveProgress {
            VStack(alignment: .leading, spacing: 6) {
                Text("Moving sessions… \(progress.done) of \(progress.total)", comment: "Sessions folder: move progress")
                    .font(.footnote)
                ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
            }
        } else if let result = folders.moveResult {
            Text(result)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    /// Move Sessions / Keep Them when the folder changes and sessions exist (RF-3).
    var moveDialogTitle: String {
        String(localized: "Move your sessions to the new folder?", comment: "Sessions folder: move question")
    }

    private var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}
