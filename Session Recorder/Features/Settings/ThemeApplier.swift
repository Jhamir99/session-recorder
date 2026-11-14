import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Applies the app theme (settings RF-13) to every window, including sheets and the Mac Settings window.
/// Done at the window/app level because `preferredColorScheme(nil)` does not reliably return to System.
enum ThemeApplier {
    @MainActor
    static func apply(_ theme: AppTheme) {
        #if os(iOS)
        let style: UIUserInterfaceStyle = switch theme {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
        #else
        NSApp.appearance = switch theme {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
        #endif
    }
}
