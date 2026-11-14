#if os(iOS)
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// iPhone/iPad: the system file browser opened at a folder, for Show in Files (sessions-folder RF-6).
/// The user can browse, copy, move or share files as in the Files app; picking a file just closes it.
/// iOS has no supported way to open the Files app itself at an arbitrary folder.
struct FolderBrowserView: UIViewControllerRepresentable {
    let directoryURL: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: false)
        picker.directoryURL = directoryURL
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {}
}
#endif
