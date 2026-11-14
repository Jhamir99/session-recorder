import SwiftUI

// First-use previews (C5): explanation, each access notice and the USB-C note. No permission is requested.

#Preview("Explanation") {
    FirstUseExplanationView(onContinue: {}, onNotNow: {})
}

#Preview("Notice, not asked") {
    AudioAccessNoticeView(access: .notAsked, onAllow: {}, onOpenSettings: {})
        .padding()
}

#Preview("Notice, denied") {
    AudioAccessNoticeView(access: .denied, onAllow: {}, onOpenSettings: {})
        .padding()
}

#Preview("Notice, restricted") {
    AudioAccessNoticeView(access: .restricted, onAllow: {}, onOpenSettings: {})
        .padding()
}

#Preview("USB-C note") {
    Label("For the best quality, connect your mixer or audio interface over USB-C.", systemImage: "cable.connector")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding()
}

#Preview("Large text") {
    AudioAccessNoticeView(access: .denied, onAllow: {}, onOpenSettings: {})
        .padding()
        .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Explanation (Spanish)") {
    FirstUseExplanationView(onContinue: {}, onNotNow: {})
        .environment(\.locale, Locale(identifier: "es"))
}
