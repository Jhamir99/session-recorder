import SwiftUI

/// Live input level per recorded channel with clipping indicators (RF-2).
/// Meters fed by the live levels; the only view that updates at the meter rate.
struct LiveLevelMetersView: View {
    @ObservedObject var meters: LevelMeterModel
    var style: MeterStyle = .continuous
    /// Tap/click on the meters (resets held peaks with peak hold "Until Reset").
    var onTap: () -> Void = {}

    var body: some View {
        LevelMetersView(levels: meters.levels, style: style)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}

struct LevelMetersView: View {
    /// Mono: one level; stereo: left then right.
    let levels: [ChannelLevel]
    /// Continuous bar or LED-like segments (settings RF-2).
    var style: MeterStyle = .continuous

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                MeterRow(label: label(for: index), level: level, style: style)
            }
        }
    }

    private func label(for index: Int) -> String {
        guard levels.count == 2 else { return "M" }
        return index == 0 ? "L" : "R"
    }
}

private struct MeterRow: View {
    let label: String
    let level: ChannelLevel
    let style: MeterStyle

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            bar
                .frame(height: 10)
                .overlay { heldPeakMarker }

            Text("CLIP")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .foregroundStyle(level.isClipping ? .white : Color.secondary.opacity(0.4))
                .background(level.isClipping ? Color.red : Color.clear, in: RoundedRectangle(cornerRadius: 3))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(accessibilityLevel)
    }

    @ViewBuilder
    private var bar: some View {
        switch style {
        case .continuous:
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.fill.tertiary)
                    Capsule()
                        .fill(meterGradient)
                        .frame(width: geometry.size.width * CGFloat(RecordingLogic.meterValue(peak: level.peak)))
                }
            }
        case .segmented:
            SegmentedMeterBar(
                meterValue: RecordingLogic.meterValue(peak: level.peak),
                segmentCount: style.segmentCount ?? SettingsLogic.meterSegmentCount
            )
        }
    }

    /// Thin line at the held peak (settings RF-3), on the same scale as the bar.
    @ViewBuilder
    private var heldPeakMarker: some View {
        if let held = level.heldPeak, held > 0 {
            GeometryReader { geometry in
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2, height: geometry.size.height + 4)
                    .offset(x: geometry.size.width * CGFloat(RecordingLogic.meterValue(peak: held)) - 1, y: -2)
            }
            .allowsHitTesting(false)
        }
    }

    // Green up to about -12 dBFS, yellow up to about -3 dBFS, red near full scale (same zones as the
    // segmented style, see SettingsLogic).
    private var meterGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .green, location: 0),
                .init(color: .green, location: 0.75),
                .init(color: .yellow, location: 0.8),
                .init(color: .red, location: 0.97)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var accessibilityName: String {
        switch label {
        case "L": "Left level"
        case "R": "Right level"
        default: "Input level"
        }
    }

    private var accessibilityLevel: String {
        let decibels = level.peak > 0 ? Int((20 * log10(level.peak)).rounded()) : nil
        let value = decibels.map { "\($0) dB" } ?? "Silent"
        return level.isClipping ? "\(value), clipping" : value
    }
}

/// LED-like meter (settings RF-2): same dB scale and green/yellow/red zones as the continuous bar.
private struct SegmentedMeterBar: View {
    let meterValue: Float
    let segmentCount: Int

    var body: some View {
        let lit = SettingsLogic.litSegments(meterValue: meterValue, segmentCount: segmentCount)
        HStack(spacing: 2) {
            ForEach(0..<segmentCount, id: \.self) { index in
                let fill = index < lit
                    ? color(for: SettingsLogic.zone(forSegment: index, segmentCount: segmentCount))
                    : Color.secondary.opacity(0.18)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(fill)
            }
        }
    }

    private func color(for zone: SettingsLogic.MeterZone) -> Color {
        switch zone {
        case .green: .green
        case .yellow: .yellow
        case .red: .red
        }
    }
}

#Preview("Stereo, clipping right") {
    LevelMetersView(levels: [
        ChannelLevel(peak: 0.3, isClipping: false),
        ChannelLevel(peak: 1, isClipping: true)
    ])
    .padding()
}

#Preview("Mono") {
    LevelMetersView(levels: [ChannelLevel(peak: 0.1, isClipping: false)])
        .padding()
}

#Preview("Segmented") {
    LevelMetersView(levels: [
        ChannelLevel(peak: 0.3, isClipping: false, heldPeak: 0.5),
        ChannelLevel(peak: 0.9, isClipping: false, heldPeak: 0.95)
    ], style: .segmented)
    .padding()
}
