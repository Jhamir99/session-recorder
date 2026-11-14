import SwiftUI

@main struct MyApp: App {
    /// One settings store for every window and the Mac Settings window (settings RF-1).
    @StateObject private var settingsStore = AppSettingsStore()
    /// One sessions folder for every window (sessions-folder RF-1).
    @StateObject private var foldersStore = SessionsFolderStore()

    var body: some Scene {
        WindowGroup {
            ContentView(settingsStore: settingsStore, foldersStore: foldersStore)
        }
        #if os(macOS)
        // Comfortable first size on Mac; the window can still be resized (macOS remembers the last size).
        .defaultSize(width: 900, height: 620)
        #endif
        .commands {
            RecordingCommands()
            SessionLibraryCommands()
        }
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(foldersStore)
        }
        #endif
    }
}
