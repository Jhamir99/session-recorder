import SwiftUI

/// Compact summary of the selected audio source on the Record tab (RF-6).
/// Tapping it opens the source sheet.
struct AudioSourceSummaryRow: View {
    @EnvironmentObject private var viewModel: AudioSourceSelectionViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Audio source: \(title), \(subtitle)")
        .accessibilityHint("Opens audio source settings")
    }

    private var title: String {
        switch viewModel.sourceSummary {
        case .noInputSelected:
            return "No input selected"
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
            return "Choose an audio source"
        case .permissionRequired:
            return "Permission required"
        case .noChannelsAvailable:
            return "No channels available"
        case .noValidChannel:
            return "No valid channel selected"
        case .selected(_, let mode, let channelNumbers):
            return AudioDeviceSelectionHelper.sourceSummaryChannelText(mode: mode, channelNumbers: channelNumbers)
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

#Preview("Stereo selected") {
    let channels = [
        AudioInputChannel(id: "d1:1", number: 1, name: nil),
        AudioInputChannel(id: "d1:2", number: 2, name: nil)
    ]
    let device = AudioInputDevice(id: "d1", displayName: "Xone:96", channels: channels)
    let viewModel = AudioSourceSelectionViewModel(previewState: .init(
        devices: AudioDeviceSelectionHelper.disambiguateDeviceNames([device]),
        selectedDeviceID: "d1",
        permissionState: .granted,
        selectedMode: .stereo,
        displayedChannels: channels,
        activeSelection: .stereo(leftChannelID: "d1:1", rightChannelID: "d1:2"),
        rawDevices: [device]
    ))
    return AudioSourceSummaryRow(onTap: {})
        .environmentObject(viewModel)
        .padding()
}
