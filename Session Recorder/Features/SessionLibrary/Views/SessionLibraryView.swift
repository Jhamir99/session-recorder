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
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
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
                ExportSheet(session: session, initialChoice: viewModel.initialExportChoice) { viewModel.isExportInProgress = $0 }
            }
            // Centered alert on every platform (not an action sheet on iPhone).
            .alert(
                "Delete “\(viewModel.deletingSession?.name ?? "")”?",
                // The buttons clear `deletingSession` themselves; the setter only writes when something is
                // left (it runs while the alert closes, during a view update, where publishing is not allowed).
                isPresented: Binding(
                    get: { viewModel.deletingSession != nil },
                    set: { if !$0, viewModel.deletingSession != nil { viewModel.deletingSession = nil } }
                ),
                presenting: viewModel.deletingSession
            ) { session in
                Button(viewModel.deleteConfirmation.button, role: .destructive) {
                    viewModel.delete(session)
                }
                Button("Cancel", role: .cancel) { viewModel.deletingSession = nil }
            } message: { _ in
                Text(viewModel.deleteConfirmation.message)
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
                .safeAreaInset(edge: .top) {
                    VStack(spacing: 0) {
                        indicator
                        if let folders = viewModel.foldersStore {
                            SessionsFolderUnavailableBanner(folders: folders)
                        }
                    }
                }
                .frame(width: 280)
                .toolbar {
                    ToolbarItem(placement: .navigation) { sortMenu }
                }
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
                // iPhone (one column): gear in the list's bar, top right.
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { sortMenu }
                    if let onOpenSettings, isCompact {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Settings", systemImage: "gearshape", action: onOpenSettings)
                        }
                    }
                }
                .safeAreaInset(edge: .top) {
                    VStack(spacing: 0) {
                        indicator
                        if let folders = viewModel.foldersStore {
                            SessionsFolderUnavailableBanner(folders: folders)
                        }
                    }
                }
        } detail: {
            detail
                // iPad (list + detail): gear in the detail bar, top right of the window like the Record tab.
                .toolbar {
                    if let onOpenSettings, !isCompact {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Settings", systemImage: "gearshape", action: onOpenSettings)
                        }
                    }
                }
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

    private var isCompact: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
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
            // Finder-like status line (settings RF-12).
            .safeAreaInset(edge: .bottom) {
                if let summary = viewModel.storageSummary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        // Two lines at most: Spanish and large text sizes must not cut it (localization RF-6).
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.bar)
                }
            }
        }
    }

    /// Newest First / Oldest First / Name (settings RF-11).
    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $viewModel.sortOrder) {
                ForEach(SessionSortOrder.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .disabled(viewModel.sessions.isEmpty)
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
                .disabled(session.isUnreadable || session.isDownloading)
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
