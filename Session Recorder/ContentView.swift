import SwiftUI

struct ContentView: View {
    private enum AppTab: Hashable {
        case record
        case sessions
    }

    @State private var selectedTab: AppTab = .record
    @State private var isShowingSourceSheet = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var windowID = UUID()
    @StateObject private var audioSourceViewModel: AudioSourceSelectionViewModel
    @StateObject private var recordingViewModel: RecordingViewModel
    /// Owned but not observed here (`@State`, not `@StateObject`): only the Sessions tab observes it, so list
    /// updates do not rebuild the whole window.
    @State private var libraryViewModel: SessionLibraryViewModel

    init(
        audioSourceViewModel: AudioSourceSelectionViewModel? = nil,
        recordingViewModel: RecordingViewModel? = nil,
        libraryViewModel: SessionLibraryViewModel? = nil
    ) {
        _audioSourceViewModel = StateObject(wrappedValue: audioSourceViewModel ?? AudioSourceSelectionViewModel())
        _recordingViewModel = StateObject(wrappedValue: recordingViewModel ?? RecordingViewModel())
        _libraryViewModel = State(initialValue: libraryViewModel ?? SessionLibraryViewModel())
    }

    var body: some View {
        // Bottom tab bar on iPhone; sidebar-adaptable on iPad and Mac.
        TabView(selection: $selectedTab) {
            Tab("Record", systemImage: "record.circle", value: AppTab.record) {
                recordTab
            }
            Tab("Sessions", systemImage: "list.bullet", value: AppTab.sessions) {
                sessionsTab
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        #if os(macOS)
        .overlay { ExportDimmingOverlay(library: libraryViewModel) }
        #endif
        // Injected at the root so tabs and sheets presented from them share the same state.
        .environmentObject(audioSourceViewModel)
        .task {
            libraryViewModel.attach(recording: recordingViewModel)
            recordingViewModel.attach(audioSource: audioSourceViewModel)
        }
        // Recording starts from the Record tab in the recording audio configuration: stop library playback.
        .onChange(of: selectedTab) { _, tab in
            if tab == .record { libraryViewModel.stopPlayback() }
            recordingViewModel.setRecordTabVisible(tab == .record)
        }
        // Recording menu and shortcuts act on this window's recording (RF-9).
        .focusedSceneObject(recordingViewModel)
        .focusedSceneValue(\.chooseRecordingSource, ChooseRecordingSourceAction(windowID: windowID) {
            selectedTab = .record
            isShowingSourceSheet = true
        })
        // Idle meters stop in the background; a recording keeps going (RF-7).
        .onChange(of: scenePhase) { _, phase in
            recordingViewModel.setAppInForeground(phase != .background)
            // Sessions may have been renamed or deleted in Files/Finder meanwhile (RF-1).
            if phase == .active { libraryViewModel.refresh() }
        }
        #if os(macOS)
        // On Mac the scene stays active while another app (e.g. Finder) is in front, so refresh when the
        // app itself becomes active again (RF-1).
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            libraryViewModel.refresh()
        }
        #endif
    }

    private var recordTab: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                AudioSourceSummaryRow(
                    qualityLabel: recordingViewModel.quality?.label,
                    isLocked: recordingViewModel.state.hasActiveRecording
                ) { isShowingSourceSheet = true }

                if let message = audioSourceViewModel.recordTabMessage {
                    Text(message.text)
                        .font(.footnote)
                        .foregroundStyle(message.kind == .sourceChangedAutomatically ? Color.secondary : Color.red)
                }

                if recordingViewModel.meteredChannelCount > 0 {
                    LiveLevelMetersView(meters: recordingViewModel.meters)
                        .padding(.top, 8)
                }

                if recordingViewModel.state.hasActiveRecording {
                    RecordingStatusView(state: recordingViewModel.state, liveInfo: recordingViewModel.liveInfo)
                        .padding(.top, 16)
                }

                if let notice = recordingViewModel.notice {
                    recordingNoticeView(notice)
                }

                if recordingViewModel.showsDoNotDisturbTip {
                    doNotDisturbTip
                }

                #if DEBUG
                // Capture spike (recording plan §3): native format delivered by the device.
                if let format = recordingViewModel.nativeFormatDescription {
                    Text("Capture: \(format)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                #endif

                Spacer(minLength: 0)

                // Pinned at the bottom so it stays visible regardless of device/channel count.
                RecordingControlsView(
                    state: recordingViewModel.state,
                    canRecord: recordingViewModel.canRecord,
                    canResume: recordingViewModel.canResume,
                    onRecord: recordingViewModel.startRecording,
                    onPause: recordingViewModel.pauseRecording,
                    onResume: recordingViewModel.resumeRecording,
                    onStop: recordingViewModel.stopRecording
                )
            }
            .padding()
            .navigationTitle("Record")
        }
        .sheet(isPresented: $isShowingSourceSheet) {
            sourceSheet
        }
    }

    private func recordingNoticeView(_ notice: RecordingNotice) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(notice.text)
                .font(.footnote)
                .foregroundStyle(notice.isError ? Color.red : Color.secondary)
            Spacer(minLength: 0)
            Button("Dismiss", systemImage: "xmark.circle.fill", action: recordingViewModel.dismissNotice)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
        }
    }

    // iPhone/iPad only (the view model never shows it on Mac): calls pause the recording (RF-3, RF-8).
    private var doNotDisturbTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "moon.fill")
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 6) {
                Text("Tip: turn on Do Not Disturb while recording. Calls pause the recording.")
                    .font(.footnote)
                Button("Got It", action: recordingViewModel.dismissDoNotDisturbTip)
                    .font(.footnote.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .padding(.top, 8)
    }

    // Done button is needed on Mac, where sheets cannot be dismissed by swiping.
    private var sourceSheet: some View {
        NavigationStack {
            AudioSourceSelectionView()
                .navigationTitle("Audio Source")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isShowingSourceSheet = false }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
        .environmentObject(audioSourceViewModel)
        .environment(\.recordingViewModel, recordingViewModel)
    }

    private var sessionsTab: some View {
        SessionLibraryView(viewModel: libraryViewModel, isRecordingActive: recordingViewModel.state.hasActiveRecording) {
            // REC/PAUSED stays visible while a recording exists (recording RF-4).
            if recordingViewModel.state.hasActiveRecording {
                RecordingIndicator(
                    state: recordingViewModel.state,
                    elapsedSeconds: recordingViewModel.liveInfo.elapsedSeconds
                ) { selectedTab = .record }
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
    }
}

#Preview("Record tab") {
    ContentView(audioSourceViewModel: .previewStereo, recordingViewModel: .previewIdle)
}

#Preview("Idle, mono clipping") {
    ContentView(audioSourceViewModel: .previewMono, recordingViewModel: .previewIdleMonoClipping)
}

#Preview("Recording, DND tip") {
    ContentView(audioSourceViewModel: .previewStereo, recordingViewModel: .previewRecording)
}

#Preview("Paused by user") {
    ContentView(audioSourceViewModel: .previewStereo, recordingViewModel: .previewPausedByUser)
}

#Preview("Paused, device disconnected") {
    ContentView(audioSourceViewModel: .previewStereo, recordingViewModel: .previewPausedDisconnected)
}

#Preview("Paused by a call") {
    ContentView(audioSourceViewModel: .previewStereo, recordingViewModel: .previewPausedInterruption)
}

#Preview("Low storage warning") {
    ContentView(audioSourceViewModel: .previewStereo, recordingViewModel: .previewLowStorage)
}

#Preview("Saved notice") {
    ContentView(audioSourceViewModel: .previewStereo, recordingViewModel: .previewSaved)
}

#Preview("Recovered notice") {
    ContentView(audioSourceViewModel: .previewStereo, recordingViewModel: .previewRecovered)
}

#Preview("Record tab, no input") {
    ContentView(audioSourceViewModel: .previewNoInput, recordingViewModel: .preview(levels: []))
}

#Preview("Record tab, auto-selected external") {
    ContentView(audioSourceViewModel: .previewAutoSelectedExternal, recordingViewModel: .previewIdle)
}

#Preview("Record tab, fallback after disconnect") {
    ContentView(audioSourceViewModel: .previewFallbackToBuiltIn, recordingViewModel: .preview(levels: [.silent]))
}
