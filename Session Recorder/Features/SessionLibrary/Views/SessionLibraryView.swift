import SwiftUI

/// Sessions tab content (RF-1): list newest first and the selected session's detail.
/// - iPhone/iPad: `NavigationSplitView` (on iPhone it collapses to a list that pushes the detail).
/// - Mac: list and detail side by side in a plain `HStack`. Inside the tab sidebar, a split view made the
///   session list a second floating sidebar and the detail was laid out underneath it.
struct SessionLibraryView<Indicator: View>: View {
    @ObservedObject var viewModel: SessionLibraryViewModel
    /// A recording exists (recording or paused): playback is disabled.
    let isRecordingActive: Bool
    /// iPhone/iPad gear button (settings RF-1); the Mac uses the Settings window.
    var onOpenSettings: (() -> Void)?
    /// Shown above the list (the `REC`/`PAUSED` indicator while a recording exists).
    @ViewBuilder var indicator: Indicator

    var body: some View {
        content
            .task {
                viewModel.refresh()
            }
            // The list keeps keyboard focus on Mac and would take these keys before the menus.
            .onKeyPress(keys: [.leftArrow, .rightArrow], phases: .down) { press in
                guard press.modifiers == .command else { return .ignored }
                let seconds = press.key == .leftArrow ? -SessionLibraryLogic.skipInterval : SessionLibraryLogic.skipInterval
                return handlePlaybackKey { $0.skip(by: seconds) }
            }
            .sheet(item: $viewModel.renamingSession) { session in
                RenameSessionSheet(session: session, viewModel: viewModel)
            }
            .sheet(item: $viewModel.sharingSession) { session in
                ExportSheet(session: session) { viewModel.isExportInProgress = $0 }
            }
            .confirmationDialog(
                "Delete “\(viewModel.deletingSession?.name ?? "")”?",
                isPresented: Binding(
                    get: { viewModel.deletingSession != nil },
                    set: { if !$0 { viewModel.deletingSession = nil } }
                ),
                titleVisibility: .visible,
                presenting: viewModel.deletingSession
            ) { session in
                Button(SessionLibraryStore.deleteMovesToTrash ? "Move to Trash" : "Delete", role: .destructive) {
                    viewModel.delete(session)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text(SessionLibraryStore.deleteMovesToTrash
                     ? "The session will be moved to the Trash."
                     : "This session will be deleted from this device. This can't be undone.")
            }
            .alert(
                viewModel.notice?.text ?? "",
                isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })
            ) {
                Button("OK", role: .cancel) {}
            }
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            sessionList
                .safeAreaInset(edge: .top) { indicator }
                .frame(width: 280)
            Divider()
            NavigationStack {
                detail
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Sessions")
        #else
        NavigationSplitView {
            sessionList
                .navigationTitle("Sessions")
                .toolbar {
                    if let onOpenSettings {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Settings", systemImage: "gearshape", action: onOpenSettings)
                        }
                    }
                }
                .safeAreaInset(edge: .top) { indicator }
        } detail: {
            detail
        }
        #endif
    }

    private func handlePlaybackKey(_ action: (SessionDetailViewModel) -> Void) -> KeyPress.Result {
        guard viewModel.canControlPlayback(isRecordingActive: isRecordingActive), let detail = viewModel.activeDetail else {
            return .ignored
        }
        action(detail)
        return .handled
    }

    @ViewBuilder
    private var detail: some View {
        if let session = viewModel.selectedSession {
            // A new detail (and view model) per session file.
            SessionDetailView(
                library: viewModel,
                session: session,
                handoff: viewModel.playbackHandoff,
                isRecordingActive: isRecordingActive,
                trimContext: viewModel.trimContext,
                onRename: { viewModel.startRename(session) },
                onShare: { viewModel.startShare(session) },
                onDelete: { viewModel.requestDelete(session) }
            )
            .id(session.id)
        } else {
            ContentUnavailableView("Select a session", systemImage: "waveform")
        }
    }

    @ViewBuilder
    private var sessionList: some View {
        if viewModel.hasLoaded && viewModel.sessions.isEmpty {
            ContentUnavailableView(
                "No sessions yet",
                systemImage: "waveform",
                description: Text("Your recorded sessions will appear here.")
            )
        } else {
            List(viewModel.sessions, selection: $viewModel.selectedSessionID) { session in
                row(for: session)
            }
        }
    }

    private func row(for session: SessionItem) -> some View {
        rowContent(for: session)
            .contextMenu {
                contextMenuItems(for: session)
                    .labelStyle(.titleAndIcon)
            }
            #if os(iOS)
            // No full swipe: deleting always asks for confirmation (RF-4).
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    viewModel.requestDelete(session)
                }
                Button("Rename", systemImage: "pencil") {
                    viewModel.startRename(session)
                }
                .tint(.blue)
            }
            #endif
    }

    @ViewBuilder
    private func contextMenuItems(for session: SessionItem) -> some View {
        Group {
                Button("Rename…", systemImage: "pencil") {
                    viewModel.startRename(session)
                }
                Button("Share…", systemImage: "square.and.arrow.up") {
                    viewModel.startShare(session)
                }
                .disabled(session.isUnreadable)
                #if os(macOS)
                Button("Show in Finder", systemImage: "folder") {
                    SessionLibraryStore.revealInFinder(session.url)
                }
                #endif
                Divider()
                Button("Delete…", systemImage: "trash", role: .destructive) {
                    viewModel.requestDelete(session)
                }
        }
    }

    @ViewBuilder
    private func rowContent(for session: SessionItem) -> some View {
        #if os(macOS)
        // Selection drives the detail next to the list (no navigation push on Mac).
        SessionRow(session: session)
            .tag(session.id)
        #else
        NavigationLink(value: session.id) {
            SessionRow(session: session)
        }
        #endif
    }
}

/// Rename with live validation (RF-3): empty, `/` `:` and duplicate names are explained as you type.
private struct RenameSessionSheet: View {
    let session: SessionItem
    @ObservedObject var viewModel: SessionLibraryViewModel
    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(session: SessionItem, viewModel: SessionLibraryViewModel) {
        self.session = session
        self.viewModel = viewModel
        _name = State(initialValue: session.name)
    }

    private var validation: Result<String, RenameError> {
        viewModel.validateRename(name, for: session)
    }

    private var canRename: Bool {
        guard case .success(let newName) = validation else { return false }
        return newName != session.name
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .onSubmit(rename)
                } footer: {
                    if case .failure(let error) = validation {
                        Text(error.message)
                            .foregroundStyle(.red)
                    }
                }
            }
            // Grouped style gives the field side margins on Mac (the default Mac form style has none).
            .formStyle(.grouped)
            .navigationTitle("Rename Session")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rename", action: rename)
                        .disabled(!canRename)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 180)
        #else
        .presentationDetents([.medium])
        #endif
    }

    private func rename() {
        guard canRename else { return }
        viewModel.rename(session, to: name)
    }
}
