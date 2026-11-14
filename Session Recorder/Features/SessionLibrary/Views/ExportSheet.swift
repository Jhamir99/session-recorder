import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Share a session (RF-6): format + bitrate, size estimate, then **Share…** (and **Save…** on Mac).
/// Each button exports first (with progress) and then opens the system share panel or the save panel.
/// The exported file is temporary and removed when this sheet closes.
struct ExportSheet: View {
    /// What to do once the export is ready.
    private enum PendingAction {
        case share
        case save
    }

    @StateObject private var viewModel: SessionExportViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pendingAction: PendingAction?
    /// Set to the exported file to open the system share panel (anchored to the Share button).
    @State private var shareURL: URL?
    #if os(macOS)
    @State private var isSaving = false
    #endif

    /// Reports when an export starts/ends (Mac darkens the whole app window meanwhile).
    private let onExportingChange: (Bool) -> Void

    init(session: SessionItem, initialChoice: ExportChoice? = nil, onExportingChange: @escaping (Bool) -> Void = { _ in }) {
        _viewModel = StateObject(wrappedValue: SessionExportViewModel(session: session, initialChoice: initialChoice))
        self.onExportingChange = onExportingChange
    }

    init(viewModel: SessionExportViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onExportingChange = { _ in }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section {
                        Picker("Format", selection: $viewModel.choice.format) {
                            ForEach(ExportFormat.allCases) { format in
                                Text(format.title).tag(format)
                            }
                        }
                        if viewModel.choice.format == .aac {
                            Picker("Bitrate", selection: $viewModel.choice.aacBitrate) {
                                ForEach(AACBitrate.allCases) { bitrate in
                                    Text(bitrate.title).tag(bitrate)
                                }
                            }
                        }
                        LabeledContent("Estimated size", value: viewModel.estimateText ?? "…")
                    } footer: {
                        Text(footerText)
                    }
                    .disabled(isExporting)
                }
                .formStyle(.grouped)

                // Plain buttons below the form (not inside grey form rows).
                actionBar
                    .padding()
            }
            .navigationTitle("Share “\(viewModel.session.name)”")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            #endif
        }
        // Over the whole sheet (title and Close bar included), not only the form.
        .overlay {
            if case .exporting(let progress) = viewModel.phase {
                progressCard(progress)
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 360)
        .fileMover(isPresented: $isSaving, file: readyURL) { result in
            if case .success = result { viewModel.exportWasMoved() }
        }
        #endif
        .onChange(of: viewModel.phase) { _, phase in
            if case .exporting = phase { onExportingChange(true) } else { onExportingChange(false) }
            switch phase {
            case .ready(let url):
                runPendingAction(with: url)
            case .failed, .choosing:
                pendingAction = nil
            case .exporting:
                break
            }
        }
        .task { await viewModel.load() }
        .onDisappear {
            viewModel.close()
            onExportingChange(false)
        }
    }

    /// Mac: lighter than the app window's darkening, because the sheet sits on top of an already darkened
    /// window and otherwise looks darker than the rest of the app.
    #if os(macOS)
    private static let sheetDimming = 0.3
    #else
    private static let sheetDimming = 0.5
    #endif

    private var isExporting: Bool {
        if case .exporting = viewModel.phase { return true }
        return false
    }

    private var readyURL: URL? {
        if case .ready(let url) = viewModel.phase { return url }
        return nil
    }

    private var footerText: String {
        viewModel.choice.format.isLossless
            ? String(localized: "Lossless: same quality as the original.", comment: "Export format footer")
            : String(localized: "Compressed: smaller file, some quality is lost.", comment: "Export format footer")
    }

    /// Uses the finished export if it matches the current choice; otherwise exports first.
    private func perform(_ action: PendingAction) {
        if let readyURL {
            pendingAction = action
            runPendingAction(with: readyURL)
        } else {
            pendingAction = action
            viewModel.export()
        }
    }

    private func runPendingAction(with url: URL) {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .share:
            #if os(iOS)
            ActivityPresenter.present(url)
            #else
            shareURL = url
            #endif
        case .save:
            #if os(macOS)
            isSaving = true
            #endif
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 12) {
            if case .failed(let message) = viewModel.phase {
                Text(message)
                    .foregroundStyle(.red)
            }
            #if os(macOS)
            // Mac: Close lives here (not in the sheet's toolbar, which AppKit draws outside the content
            // and the export darkening could not cover).
            Button("Close") { dismiss() }
            #endif
            Spacer()
            #if os(macOS)
            Button("Save…") { perform(.save) }
                .disabled(viewModel.session.audioInfo == nil)
            #endif
            Button("Share…", systemImage: "square.and.arrow.up") { perform(.share) }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.session.audioInfo == nil)
                #if os(macOS)
                .background(SystemSharePresenter(url: $shareURL))
                #endif
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(isExporting)
    }

    /// Alert-style card over the darkened form while exporting: title, progress, then a full-width
    /// Cancel separated by a line (like a system alert button).
    private func progressCard(_ progress: Double) -> some View {
        ZStack {
            // The sheet is darkened behind the card; on Mac the app window behind it is darkened too
            // (`ExportDimmingOverlay` in ContentView), so the whole app reads as busy.
            Rectangle()
                .fill(.black.opacity(Self.sheetDimming))
                .ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("Exporting…")
                        .font(.headline)
                    ExportProgressBar(progress: progress)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(20)

                Divider()

                Button {
                    pendingAction = nil
                    viewModel.cancelExport()
                } label: {
                    Text("Cancel")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
            .frame(width: 270)
            // Opaque, so the darkening behind does not show through the card.
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 16)
        }
        .transition(.opacity)
    }
}

#if os(iOS)
/// Presents `UIActivityViewController` from the top-most view controller of the active window.
/// Presenting from a view inside the sheet right when the progress card disappeared was ignored by iOS,
/// so the first Share needed a second tap.
@MainActor
private enum ActivityPresenter {
    static func present(_ url: URL, attempt: Int = 0) {
        guard let top = topViewController() else { return }
        // A presentation or dismissal still in progress would make `present` do nothing: try again shortly.
        if top.isBeingPresented || top.isBeingDismissed || top.transitionCoordinator != nil, attempt < 10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { present(url, attempt: attempt + 1) }
            return
        }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            // iPad: show near the bottom center of the sheet (where the Share button is).
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 60, width: 1, height: 1)
            popover.permittedArrowDirections = [.down]
        }
        top.present(activity, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first { $0.activationState == .foregroundActive }?.keyWindow
            ?? scenes.first?.keyWindow
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
#else
/// Shows the Mac share picker for `url` when it is set, anchored to this view (the Share button).
private struct SystemSharePresenter: NSViewRepresentable {
    @Binding var url: URL?

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ anchor: NSView, context: Context) {
        guard let url else { return }
        DispatchQueue.main.async {
            self.url = nil
            NSSharingServicePicker(items: [url]).show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        }
    }
}
#endif

/// Mac: darkens the whole app window while an export runs (the export sheet darkens itself). Only this
/// small view observes the library, so the window is not rebuilt on every library change.
struct ExportDimmingOverlay: View {
    @ObservedObject var library: SessionLibraryViewModel

    var body: some View {
        if library.isExportInProgress {
            Rectangle()
                .fill(.black.opacity(0.5))
                .ignoresSafeArea()
                .transition(.opacity)
        }
    }
}

/// Determinate bar for the export card; the fill always matches `progress` (0...1). The Mac system bar
/// lagged far behind the value inside the card.
private struct ExportProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(.tint)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("Export progress")
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}
