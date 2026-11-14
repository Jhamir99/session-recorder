import SwiftUI

@main struct MyApp: App {
    /// One settings store for every window and the Mac Settings window (settings RF-1).
    @StateObject private var settingsStore = AppSettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView(settingsStore: settingsStore)
        }
        .commands {
            RecordingCommands()
            SessionLibraryCommands()
        }
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(settingsStore)
        }
        #endif
    }
}
