import SwiftUI

struct ContentView: View {
    private enum AppTab: Hashable {
        case record
        case sessions
    }

    @State private var selectedTab: AppTab = .record
    @State private var isShowingSourceSheet = false
    @StateObject private var audioSourceViewModel: AudioSourceSelectionViewModel
    @StateObject private var recordingViewModel = RecordingViewModel()

    init(audioSourceViewModel: AudioSourceSelectionViewModel? = nil) {
        _audioSourceViewModel = StateObject(wrappedValue: audioSourceViewModel ?? AudioSourceSelectionViewModel())
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
        // Injected at the root so tabs and sheets presented from them share the same state.
        .environmentObject(audioSourceViewModel)
        .task {
            recordingViewModel.attach(audioSource: audioSourceViewModel)
        }
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

    // Placeholder until the session library feature exists.
    private var sessionsTab: some View {
        NavigationStack {
            ContentUnavailableView(
                "No sessions yet",
                systemImage: "waveform",
                description: Text("Your recorded sessions will appear here.")
            )
            .navigationTitle("Sessions")
            // REC/PAUSED stays visible while a recording exists (RF-4).
            .safeAreaInset(edge: .top) {
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
}

#Preview("Record tab") {
    ContentView(audioSourceViewModel: .previewStereo)
}

#Preview("Record tab, no input") {
    ContentView(audioSourceViewModel: .previewNoInput)
}

#Preview("Record tab, auto-selected external") {
    ContentView(audioSourceViewModel: .previewAutoSelectedExternal)
}

#Preview("Record tab, fallback after disconnect") {
    ContentView(audioSourceViewModel: .previewFallbackToBuiltIn)
}
