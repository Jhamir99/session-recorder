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
