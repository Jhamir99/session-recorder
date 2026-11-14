import SwiftUI

// Settings previews (C5): the settings form with default and changed values, segmented meters with peak hold,
// the line waveform and the library storage line. Preview stores use their own UserDefaults suite.

@MainActor
private func previewStore(_ change: (inout AppSettings) -> Void = { _ in }) -> AppSettingsStore {
    let repository = AppSettingsRepository(
        defaults: UserDefaults(suiteName: "preview.settings") ?? .standard,
        settingsKey: "preview_app_settings",
        sortOrderKey: "preview_sort_order"
    )
    let store = AppSettingsStore(repository: repository)
    var settings = AppSettings.defaults
    change(&settings)
    store.settings = settings
    return store
}

#Preview("Settings, defaults") {
    SettingsView(showsDoneButton: true)
        .environmentObject(previewStore())
}

#Preview("Settings, changed") {
    SettingsView(showsDoneButton: true)
        .environmentObject(previewStore {
            $0.meterStyle = .segmented
            $0.peakHold = .untilReset
            $0.pauseFade = .long
            $0.namePrefix = "Set"
            $0.timeLimit = .twoHours
            $0.lowStorageWarning = .thirtyMinutes
            $0.exportDefault = .fixed(ExportChoice(format: .aac, aacBitrate: .kbps192))
            $0.theme = .dark
            $0.waveformStyle = .line
        })
}

#Preview("Meters, segmented with peak hold") {
    LevelMetersView(levels: [
        ChannelLevel(peak: 0.25, isClipping: false, heldPeak: 0.4),
        ChannelLevel(peak: 0.7, isClipping: false, heldPeak: 0.92)
    ], style: .segmented)
    .padding()
}

#Preview("Waveform, line") {
    let peaks = (0..<900).map { index in Float(0.3 + 0.5 * abs(sin(Double(index) / 40))) }
    WaveformView(waveform: WaveformData(peaksPerSecond: 10, peaks: peaks), duration: 90)
        .frame(height: 80)
        .padding()
        .environment(\.waveformStyle, .line)
}

#Preview("Storage line") {
    Text(SettingsLogic.storageSummary(sessionCount: 12, totalBytes: 4_200_000_000, freeBytes: 85_000_000_000))
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding()
}

#Preview("Settings (Spanish)") {
    SettingsView(showsDoneButton: true)
        .environmentObject(previewStore())
        .environment(\.locale, Locale(identifier: "es"))
}
