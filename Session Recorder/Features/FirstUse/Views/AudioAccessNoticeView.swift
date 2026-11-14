import SwiftUI

/// Why recording is unavailable and what to do (spec RF-3): Allow Audio Input (not asked yet),
/// Open Settings (denied) or only an explanation (restricted). Used on the Record tab and in the source sheet.
struct AudioAccessNoticeView: View {
    let access: AudioAccessState
    let onAllow: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "mic.slash")
                .foregroundStyle(.secondary)
            switch AudioAccessLogic.noticeAction(for: access) {
            case .allowAudioInput:
                Button("Allow Audio Input", action: onAllow)
                    .buttonStyle(.borderedProminent)
            case .openSettings:
                Button("Open Settings", action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
            case nil:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var message: String {
        switch access {
        case .notAsked: String(localized: "Audio input is needed to show levels and record.", comment: "Access notice")
        case .denied: String(localized: "Audio input is turned off for Session Recorder. Turn it on in Settings to record.", comment: "Access notice")
        case .restricted: String(localized: "Audio input is restricted on this device, so recording isn't available.", comment: "Access notice")
        case .allowed: ""
        }
    }
}
