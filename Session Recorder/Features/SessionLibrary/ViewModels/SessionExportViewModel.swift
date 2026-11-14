import Combine
import Foundation

/// Share flow for one session (RF-6): choose format/bitrate, see the size, export with progress, then share.
@MainActor
final class SessionExportViewModel: ObservableObject {
    enum Phase: Equatable {
        case choosing
        case exporting(progress: Double)
        case ready(URL)
        case failed(String)
    }

    @Published var choice: ExportChoice {
        didSet {
            settings.saveExportChoice(choice)
            // A finished export no longer matches the new choice.
            if case .ready = phase { discardExport() }
        }
    }
    @Published private(set) var phase: Phase = .choosing
    @Published private(set) var session: SessionItem

    private let service: SessionExportService
    private let settings: SessionLibrarySettingsRepository
    private var exportTask: Task<Void, Never>?

    init(
        session: SessionItem,
        service: SessionExportService = SessionExportService(),
        settings: SessionLibrarySettingsRepository? = nil
    ) {
        let settings = settings ?? SessionLibrarySettingsRepository()
        self.session = session
        self.service = service
        self.settings = settings
        self.choice = settings.exportChoice
    }

    /// `About 412 MB` (FLAC/ALAC/AAC) or `1.04 GB` (PCM, exact); nil until the header is read.
    var estimateText: String? {
        guard let info = session.audioInfo else { return nil }
        let size = RecordingLogic.formatFileSize(SessionLibraryLogic.estimatedExportBytes(choice: choice, info: info))
        return SessionLibraryLogic.isExactEstimate(choice.format) ? size : "About \(size)"
    }

    /// Reads the header if the list had not yet (the size estimate needs it).
    func load() async {
        guard session.audio == .loading else { return }
        let url = session.url
        session.audio = await Task.detached(priority: .userInitiated) { SessionLibraryStore.readAudioState(at: url) }.value
    }

    func export() {
        guard let info = session.audioInfo else { return }
        discardExport()
        phase = .exporting(progress: 0)
        let service = service
        let url = session.url
        let name = session.name
        let choice = choice
        exportTask = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                try service.export(url, name: name, choice: choice, info: info) { value in
                    Task { @MainActor [weak self] in
                        if case .exporting = self?.phase { self?.phase = .exporting(progress: value) }
                    }
                }
            }
            do {
                let exported = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                guard let self, !Task.isCancelled else {
                    service.removeExport(exported)
                    return
                }
                phase = .ready(exported)
            } catch {
                guard let self, !Task.isCancelled else { return }
                phase = .failed((error as? SessionExportService.ExportError) == .notEnoughStorage
                    ? "Not enough free storage to export."
                    : "The export failed. Please try again.")
            }
        }
    }

    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        phase = .choosing
    }

    /// The sheet closed: stop any export and remove the temporary file (it never appears in the library).
    func close() {
        discardExport()
        cancelExport()
    }

    /// Mac Save… moved the file to the chosen place: nothing temporary is left to share.
    func exportWasMoved() {
        discardExport()
    }

    private func discardExport() {
        if case .ready(let url) = phase {
            service.removeExport(url)
        }
        phase = .choosing
    }
}
