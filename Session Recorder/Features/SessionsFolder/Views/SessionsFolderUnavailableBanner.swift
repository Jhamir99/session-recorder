import SwiftUI
import UniformTypeIdentifiers

/// Library notice while the chosen sessions folder can't be accessed (sessions-folder RF-5), with
/// Choose Folder… and Use App Folder. Shows nothing while the folder is available.
struct SessionsFolderUnavailableBanner: View {
    @ObservedObject var folders: SessionsFolderStore
    @State private var isChoosingFolder = false

    var body: some View {
        if folders.isChosenFolderUnavailable {
            VStack(alignment: .leading, spacing: 8) {
                Label("The sessions folder isn't available.", systemImage: "externaldrive.badge.exclamationmark")
                    .font(.subheadline.weight(.semibold))
                Text("Connect the drive or check the folder. Meanwhile, new sessions are saved in the App Folder and listed here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("Choose Folder…") { isChoosingFolder = true }
                    Button("Use App Folder") {
                        Task { @MainActor in try? folders.requestChange(to: .app) }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.vertical, 6)
            .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                guard case .success(let url) = result else { return }
                Task { @MainActor in try? folders.requestChange(to: .chosen(url)) }
            }
        }
    }
}
