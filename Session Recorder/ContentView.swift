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
    @StateObject private var firstUseViewModel = FirstUseViewModel()
    @StateObject private var settingsStore: AppSettingsStore
    @State private var isShowingSettings = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    init(
        audioSourceViewModel: AudioSourceSelectionViewModel? = nil,
        recordingViewModel: RecordingViewModel? = nil,
        libraryViewModel: SessionLibraryViewModel? = nil,
        settingsStore: AppSettingsStore? = nil
    ) {
        _settingsStore = StateObject(wrappedValue: settingsStore ?? AppSettingsStore())
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
        // Settings at the bottom left of the sidebar (Mac, iPad sidebar).
        .tabViewSidebarBottomBar {
            HStack {
                sidebarSettingsButton
                Spacer()
            }
            // Same inset as the tab items, clear of the rounded screen corner on iPad.
            #if os(iOS)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            #else
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            #endif
        }
        .environmentObject(settingsStore)
        // iPhone/iPad settings sheet (Mac uses the Settings window, ⌘,).
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(showsDoneButton: true)
                .environmentObject(settingsStore)
        }
        .sheet(isPresented: showsExplanationSheet) { explanation }
        #if os(iOS)
        .fullScreenCover(isPresented: showsExplanationFullScreen) { explanation }
        #endif
        #if os(macOS)
        .overlay { ExportDimmingOverlay(library: libraryViewModel) }
        .background(SpaceKeyHandler(onSpace: handleSpaceKey))
        #endif
        // Injected at the root so tabs and sheets presented from them share the same state.
        .environmentObject(audioSourceViewModel)
        .task {
            recordingViewModel.attach(settings: settingsStore)
            libraryViewModel.attach(recording: recordingViewModel)
            firstUseViewModel.attach(audioSource: audioSourceViewModel)
            recordingViewModel.attach(audioSource: audioSourceViewModel)
        }
        // Recording starts from the Record tab in the recording audio configuration: stop library playback.
        .onChange(of: selectedTab) { _, tab in
            if tab == .record { libraryViewModel.stopPlayback() }
            recordingViewModel.setRecordTabVisible(tab == .record)
        }
        // Recording menu and shortcuts act on this window's recording (RF-9).
        .focusedSceneObject(recordingViewModel)
        .focusedSceneObject(libraryViewModel)
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

    #if os(macOS)
    /// Same rules as the Space menu item: recording first, otherwise the open session; never behind a dialog.
    private func handleSpaceKey() -> Bool {
        guard !libraryViewModel.hasOpenDialog, !isShowingSourceSheet else { return false }
        if recordingViewModel.state.hasActiveRecording {
            guard recordingViewModel.state == .recording || recordingViewModel.canResume else { return false }
            recordingViewModel.togglePauseFromKeyboard()
            return true
        }
        guard libraryViewModel.canControlPlayback(isRecordingActive: false),
              let detail = libraryViewModel.activeDetail else { return false }
        detail.togglePlaybackFromKeyboard()
        return true
    }
    #endif

    /// Gear + "Settings" at the bottom of the sidebar, aligned with the tab items (Mac, iPad).
    @ViewBuilder
    private var sidebarSettingsButton: some View {
        #if os(macOS)
        SettingsLink {
            Label("Settings", systemImage: "gearshape")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderless)
        #else
        Button {
            isShowingSettings = true
        } label: {
            Label("Settings", systemImage: "gearshape")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderless)
        #endif
    }

    private var settingsButton: some View {
        Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
    }

    private var audioAccess: AudioAccessState {
        AudioAccessLogic.accessState(for: audioSourceViewModel.permissionState)
    }

    /// First-use explanation (RF-1): full screen on iPhone, a sheet on iPad and Mac.
    private var explanation: some View {
        FirstUseExplanationView(
            onContinue: firstUseViewModel.continueFromExplanation,
            onNotNow: firstUseViewModel.dismissExplanation
        )
    }

    private var showsExplanationFullScreen: Binding<Bool> {
        #if os(iOS)
        Binding(
            get: { firstUseViewModel.isShowingExplanation && horizontalSizeClass == .compact },
            set: { if !$0 { firstUseViewModel.isShowingExplanation = false } }
        )
        #else
        .constant(false)
        #endif
    }

    private var showsExplanationSheet: Binding<Bool> {
        Binding(
            get: {
                #if os(iOS)
                firstUseViewModel.isShowingExplanation && horizontalSizeClass != .compact
                #else
                firstUseViewModel.isShowingExplanation
                #endif
            },
            set: { if !$0 { firstUseViewModel.isShowingExplanation = false } }
        )
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

                // USB-C note: built-in microphone and no external device (first-use RF-6).
                if AudioAccessLogic.showsExternalDeviceNote(
                    access: audioAccess,
                    selectedDevice: audioSourceViewModel.selectedDevice,
                    devices: audioSourceViewModel.rawDevices,
                    hasActiveRecording: recordingViewModel.state.hasActiveRecording
                ) {
                    Label("For the best quality, connect your mixer or audio interface over USB-C.", systemImage: "cable.connector")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if audioAccess != .allowed {
                    // In place of the meters while audio input is not allowed (first-use RF-3).
                    AudioAccessNoticeView(
                        access: audioAccess,
                        onAllow: firstUseViewModel.requestAccess,
                        onOpenSettings: firstUseViewModel.openSettings
                    )
                    .padding(.top, 8)
                } else if recordingViewModel.meteredChannelCount > 0 {
                    LiveLevelMetersView(
                        meters: recordingViewModel.meters,
                        style: settingsStore.settings.meterStyle,
                        onTap: recordingViewModel.resetHeldPeaks
                    )
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
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { settingsButton }
            }
            #endif
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
        SessionLibraryView(
            viewModel: libraryViewModel,
            isRecordingActive: recordingViewModel.state.hasActiveRecording,
            onOpenSettings: { isShowingSettings = true }
        ) {
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
