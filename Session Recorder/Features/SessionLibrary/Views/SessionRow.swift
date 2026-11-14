import SwiftUI

/// Name, recording date and duration of a session; "Can't be played" for unreadable files (RF-1).
struct SessionRow: View {
    let session: SessionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.name)
                .font(.body)
                .lineLimit(2)
            HStack(spacing: 4) {
                Text(session.recordedDate, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                switch session.audio {
                case .loading:
                    EmptyView()
                case .readable(let info):
                    Text(verbatim: "·")
                    Text(SessionLibraryLogic.formatPlaybackTime(info.duration))
                        .monospacedDigit()
                case .unreadable:
                    Text(verbatim: "·")
                    Label("Can't be played", systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.orange)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Rows") {
    List {
        SessionRow(session: SessionItem(
            url: URL(fileURLWithPath: "/Sessions/Friday warm-up.caf"), name: "Friday warm-up",
            recordedDate: .now, fileSizeBytes: 1_040_000_000,
            audio: .readable(SessionAudioInfo(duration: 3735, format: SessionFormat(channelCount: 2, sampleRate: 48_000, bitDepth: 24)))
        ))
        SessionRow(session: SessionItem(
            url: URL(fileURLWithPath: "/Sessions/Session 2026-11-12 22.30.caf"), name: "Session 2026-11-12 22.30",
            recordedDate: .now, fileSizeBytes: 0, audio: .loading
        ))
        SessionRow(session: SessionItem(
            url: URL(fileURLWithPath: "/Sessions/Broken.caf"), name: "Broken",
            recordedDate: .now, fileSizeBytes: 12, audio: .unreadable
        ))
    }
}
