import SwiftUI

/// Compact summary of the selected audio source on the Record tab (RF-6).
/// Tapping it opens the source sheet, except while a recording is locked to the source (recording RF-4).
struct AudioSourceSummaryRow: View {
    @EnvironmentObject private var viewModel: AudioSourceSelectionViewModel
    /// Recording quality shown after the channels, e.g. `24-bit/48 kHz` (recording RF-1).
    var qualityLabel: String? = nil
    var isLocked: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button {
            if !isLocked { onTap() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(isWarning ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(isWarning ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Audio source: \(title), \(subtitle)", comment: "VoiceOver: source row"))
        .accessibilityHint(isLocked
            ? String(localized: "The source cannot change while recording", comment: "VoiceOver hint: locked source row")
            : String(localized: "Opens audio source settings", comment: "VoiceOver hint: source row"))
    }

    private var title: String {
        switch viewModel.sourceSummary {
        case .noInputSelected:
            return String(localized: "No input selected", comment: "Source row status")
        case .permissionRequired(let label),
             .noChannelsAvailable(let label),
             .noValidChannel(let label),
             .selected(let label, _, _):
            return label
        }
    }

    private var subtitle: String {
        switch viewModel.sourceSummary {
        case .noInputSelected:
            return String(localized: "Choose an audio source", comment: "Source row status")
        case .permissionRequired:
            return String(localized: "Permission required", comment: "Source row status")
        case .noChannelsAvailable:
            return String(localized: "No channels available", comment: "Source row status")
        case .noValidChannel:
            return String(localized: "No valid channel selected", comment: "Source row status")
        case .selected(_, let mode, let channelNumbers):
            let channels = AudioDeviceSelectionHelper.sourceSummaryChannelText(mode: mode, channelNumbers: channelNumbers)
            guard let qualityLabel else { return channels }
            return "\(channels) · \(qualityLabel)"
        }
    }

    private var isWarning: Bool {
        switch viewModel.sourceSummary {
        case .selected, .noInputSelected:
            return false
        case .permissionRequired, .noChannelsAvailable, .noValidChannel:
            return true
        }
    }

    private var iconName: String {
        switch viewModel.sourceSummary {
        case .noInputSelected:
            return "mic.slash"
        case .permissionRequired, .noChannelsAvailable, .noValidChannel:
            return "exclamationmark.triangle"
        case .selected:
            return "waveform"
        }
    }
}

#Preview("Row states") {
    VStack(spacing: 12) {
        AudioSourceSummaryRow(onTap: {}).environmentObject(AudioSourceSelectionViewModel.previewStereo)
        AudioSourceSummaryRow(qualityLabel: "24-bit/48 kHz", onTap: {}).environmentObject(AudioSourceSelectionViewModel.previewStereo)
        AudioSourceSummaryRow(qualityLabel: "24-bit/48 kHz", isLocked: true, onTap: {}).environmentObject(AudioSourceSelectionViewModel.previewStereo)
        AudioSourceSummaryRow(onTap: {}).environmentObject(AudioSourceSelectionViewModel.previewMono)
        AudioSourceSummaryRow(onTap: {}).environmentObject(AudioSourceSelectionViewModel.previewNoInput)
        AudioSourceSummaryRow(onTap: {}).environmentObject(AudioSourceSelectionViewModel.previewPermissionRequired)
        AudioSourceSummaryRow(onTap: {}).environmentObject(AudioSourceSelectionViewModel.previewNoValidChannel)
    }
    .padding()
}
