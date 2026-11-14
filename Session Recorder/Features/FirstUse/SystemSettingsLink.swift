import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Opens the place where audio-input access is turned on (first-use RF-3, NFR-5):
/// the app's page in Settings (iPhone/iPad) or System Settings › Privacy & Security › Microphone (Mac).
enum SystemSettingsLink {
    @MainActor
    static func openAudioInputSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #else
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
        #endif
    }
}
