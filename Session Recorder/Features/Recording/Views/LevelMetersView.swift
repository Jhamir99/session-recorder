import SwiftUI

/// Live input level per recorded channel with clipping indicators (RF-2).
/// Meters fed by the live levels; the only view that updates at the meter rate.
struct LiveLevelMetersView: View {
    @ObservedObject var meters: LevelMeterModel

    var body: some View {
        LevelMetersView(levels: meters.levels)
    }
}

struct LevelMetersView: View {
    /// Mono: one level; stereo: left then right.
    let levels: [ChannelLevel]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                MeterRow(label: label(for: index), level: level)
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

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.fill.tertiary)
                    Capsule()
                        .fill(meterGradient)
                        .frame(width: geometry.size.width * CGFloat(RecordingLogic.meterValue(peak: level.peak)))
                }
            }
            .frame(height: 10)

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

    // Green up to about -12 dBFS, yellow up to about -3 dBFS, red near full scale.
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
