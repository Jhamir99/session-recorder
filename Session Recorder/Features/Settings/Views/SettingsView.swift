import SwiftUI

/// Settings (spec RF-1): Recording, Library and Appearance. Changes apply and are saved immediately.
/// Mac: the standard Settings window (⌘,). iPhone/iPad: a sheet with Done, opened from the gear button.
struct SettingsView: View {
    @EnvironmentObject private var store: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    /// Shows Done (iPhone/iPad sheet).
    var showsDoneButton = false

    var body: some View {
        NavigationStack {
            Form {
                recordingSection
                librarySection
                appearanceSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 480, height: 620)
        #endif
    }

    // MARK: Recording

    private var recordingSection: some View {
        Section {
            Picker("Meter style", selection: $store.settings.meterStyle) {
                ForEach(MeterStyle.allCases) { Text($0.title).tag($0) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                OptionLabel("Peak hold", hint: "Marks the loudest recent peak to help you avoid clipping.")
                Spacer(minLength: 8)
                Picker("Peak hold", selection: $store.settings.peakHold) {
                    ForEach(PeakHold.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                OptionLabel("Fade at pause", hint: "Removes the click when you pause and resume a recording.")
                Spacer(minLength: 8)
                Picker("Fade at pause", selection: $store.settings.pauseFade) {
                    ForEach(PauseFade.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            #if os(iOS)
            Toggle("Keep screen on while recording", isOn: $store.settings.keepScreenOn)
            #endif
            NamePrefixField(prefix: $store.settings.namePrefix)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                OptionLabel("Recording time limit", hint: "Stops and saves the recording when it reaches this length.")
                Spacer(minLength: 8)
                Picker("Recording time limit", selection: $store.settings.timeLimit) {
                    ForEach(RecordingTimeLimit.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                OptionLabel("Low storage warning", hint: "Warns when this much recording time is left.")
                Spacer(minLength: 8)
                Picker("Low storage warning", selection: $store.settings.lowStorageWarning) {
                    ForEach(LowStorageWarning.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
        } header: {
            Text("Recording")
        }
    }

    // MARK: Library

    private var librarySection: some View {
        Section {
            Picker("Export format", selection: exportFormatBinding) {
                Text("Last Used").tag(ExportFormat?.none)
                ForEach(ExportFormat.allCases) { Text($0.title).tag(Optional($0)) }
            }
            if case .fixed(let choice) = store.settings.exportDefault, choice.format == .aac {
                Picker("AAC bitrate", selection: aacBitrateBinding) {
                    ForEach(AACBitrate.allCases) { Text($0.title).tag($0) }
                }
            }
        } header: {
            Text("Library")
        } footer: {
            Text("The format used by default when you share a session. You can still change it before sharing.")
        }
    }

    /// nil = Last Used; a format = fixed default (RF-10).
    private var exportFormatBinding: Binding<ExportFormat?> {
        Binding(
            get: {
                if case .fixed(let choice) = store.settings.exportDefault { return choice.format }
                return nil
            },
            set: { format in
                guard let format else {
                    store.settings.exportDefault = .lastUsed
                    return
                }
                var choice = ExportChoice.default
                if case .fixed(let current) = store.settings.exportDefault { choice = current }
                choice.format = format
                store.settings.exportDefault = .fixed(choice)
            }
        )
    }

    private var aacBitrateBinding: Binding<AACBitrate> {
        Binding(
            get: {
                if case .fixed(let choice) = store.settings.exportDefault { return choice.aacBitrate }
                return ExportChoice.default.aacBitrate
            },
            set: { bitrate in
                guard case .fixed(var choice) = store.settings.exportDefault else { return }
                choice.aacBitrate = bitrate
                store.settings.exportDefault = .fixed(choice)
            }
        )
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $store.settings.theme) {
                ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
            }
            Picker("Waveform", selection: $store.settings.waveformStyle) {
                ForEach(WaveformStyle.allCases) { Text($0.title).tag($0) }
            }
        }
    }
}

/// Option title with a short hint below it (settings RF-1). Placed in an HStack with the picker on the right
/// (a multi-line Picker label, or LabeledContent, put the menu below or next to the text on iPhone).
private struct OptionLabel: View {
    let title: String
    let hint: String

    init(_ title: String, hint: String) {
        self.title = title
        self.hint = hint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Session name prefix (RF-7): edited as text, saved only when valid; the message explains invalid values.
private struct NamePrefixField: View {
    @Binding var prefix: String
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text("Session name")
                Spacer(minLength: 8)
                TextField("Session name", text: $text, prompt: Text("Session"))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .onSubmit(save)
                    .onChange(of: text) { save() }
            }
            if case .failure(let error) = SettingsLogic.validatePrefix(text) {
                Text(error.message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("New session names: \(prefix) 2026-11-14 22.30.15")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { text = prefix }
    }

    private func save() {
        if case .success(let valid) = SettingsLogic.validatePrefix(text), valid != prefix {
            prefix = valid
        }
    }
}
