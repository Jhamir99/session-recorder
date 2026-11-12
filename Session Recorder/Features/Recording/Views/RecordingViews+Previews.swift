import SwiftUI

// Previews that need a recording view model (C5). Component previews (meters, controls, status,
// indicator) live next to each view; full Record tab states are in ContentView.

#Preview("Quality section") {
    Form {
        RecordingQualitySection()
    }
    .environment(\.recordingViewModel, RecordingViewModel.previewIdle)
}

#Preview("Quality section, 16-bit/96 kHz") {
    Form {
        RecordingQualitySection()
    }
    .environment(\.recordingViewModel, RecordingViewModel.preview(quality: RecordingQuality(sampleRate: 96_000, bitDepth: 16)))
}

#Preview("Source sheet with quality") {
    NavigationStack {
        AudioSourceSelectionView()
            .navigationTitle("Audio Source")
    }
    .environmentObject(AudioSourceSelectionViewModel.previewStereo)
    .environment(\.recordingViewModel, RecordingViewModel.previewIdle)
}
