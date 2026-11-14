import AVFoundation
import Foundation

/// Converts a session to a share format (RF-6, plan §3) into a temporary folder
/// (`tmp/Export/<uuid>/<name>.<ext>`). Lossless formats keep rate, bit depth and channels; AAC uses the
/// chosen bitrate at up to 48 kHz. Chunked (memory does not grow with length, NFR-3), reports progress,
/// stops when its task is cancelled, and never leaves partial files (NFR-4). Run off the main thread.
nonisolated struct SessionExportService: Sendable {
    enum ExportError: Error, Equatable {
        case cancelled
        case notEnoughStorage
        case cannotConvert
    }

    let exportRoot: URL

    init(exportRoot: URL = FileManager.default.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory)) {
        self.exportRoot = exportRoot
    }

    /// Writes `url` as `choice` and returns the exported file. `progress` gets 0...1.
    func export(
        _ url: URL,
        name: String,
        choice: ExportChoice,
        info: SessionAudioInfo,
        progress: (Double) -> Void = { _ in }
    ) throws -> URL {
        let estimated = SessionLibraryLogic.estimatedExportBytes(choice: choice, info: info)
        guard SessionLibraryStore.freeBytes(at: exportRoot.deletingLastPathComponent()) >= estimated + 10_000_000 else {
            throw ExportError.notEnoughStorage
        }
        let folder = exportRoot.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: name).appendingPathExtension(choice.format.fileExtension)
        do {
            if choice.format == .original {
                try FileManager.default.copyItem(at: url, to: destination)
                progress(1)
            } else {
                try convert(url, to: destination, choice: choice, info: info, progress: progress)
            }
            return destination
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    /// Removes an exported file and its folder (after sharing or when the sheet closes).
    func removeExport(_ url: URL) {
        let folder = url.deletingLastPathComponent()
        // Only folders inside the export root (paths compared without a trailing slash).
        guard folder.deletingLastPathComponent().standardizedFileURL.path(percentEncoded: false).trimmingSuffix("/")
                == exportRoot.standardizedFileURL.path(percentEncoded: false).trimmingSuffix("/") else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    /// Removes exports left by an earlier run (e.g. the app was closed while sharing).
    func removeAllExports() {
        try? FileManager.default.removeItem(at: exportRoot)
    }

    // MARK: Conversion

    private func convert(
        _ url: URL,
        to destination: URL,
        choice: ExportChoice,
        info: SessionAudioInfo,
        progress: (Double) -> Void
    ) throws {
        let source = try AVAudioFile(forReading: url)
        let sourceFormat = source.processingFormat
        let outputRate = choice.format == .aac
            ? SessionLibraryLogic.aacSampleRate(sessionRate: sourceFormat.sampleRate)
            : sourceFormat.sampleRate
        let settings = Self.settings(for: choice, sampleRate: outputRate, channels: sourceFormat.channelCount, bitDepth: info.format.bitDepth)

        // Scope the writer so the file is finished (closed) before returning.
        try {
            let output = try AVAudioFile(forWriting: destination, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            let chunkFrames = AVAudioFrameCount(max(sourceFormat.sampleRate, 1))
            guard let input = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: chunkFrames) else {
                throw ExportError.cannotConvert
            }
            // Only AAC above 48 kHz needs a sample rate conversion.
            let resampler = outputRate != sourceFormat.sampleRate
                ? AVAudioConverter(from: sourceFormat, to: output.processingFormat)
                : nil
            let total = Double(max(source.length, 1))

            while source.framePosition < source.length {
                if Task.isCancelled { throw ExportError.cancelled }
                try source.read(into: input, frameCount: chunkFrames)
                guard input.frameLength > 0 else { break }
                if let resampler {
                    try write(input, through: resampler, to: output, endOfStream: false)
                } else {
                    try output.write(from: input)
                }
                progress(Double(source.framePosition) / total)
            }
            if let resampler {
                try write(nil, through: resampler, to: output, endOfStream: true)
            }
        }()
        progress(1)
    }

    /// Resamples `buffer` (or flushes at the end) and writes the result.
    private func write(_ buffer: AVAudioPCMBuffer?, through converter: AVAudioConverter, to output: AVAudioFile, endOfStream: Bool) throws {
        let ratio = output.processingFormat.sampleRate / converter.inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer?.frameLength ?? 4096) * ratio) + 1024
        nonisolated(unsafe) var pending = buffer
        while true {
            guard let converted = AVAudioPCMBuffer(pcmFormat: output.processingFormat, frameCapacity: capacity) else {
                throw ExportError.cannotConvert
            }
            var conversionError: NSError?
            let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
                if let next = pending {
                    pending = nil
                    inputStatus.pointee = .haveData
                    return next
                }
                inputStatus.pointee = endOfStream ? .endOfStream : .noDataNow
                return nil
            }
            if let conversionError { throw conversionError }
            if converted.frameLength > 0 { try output.write(from: converted) }
            if status != .haveData { return }
        }
    }

    /// File settings per format (plan §3 table). The file type follows the extension.
    private static func settings(for choice: ExportChoice, sampleRate: Double, channels: AVAudioChannelCount, bitDepth: Int) -> [String: Any] {
        var settings: [String: Any] = [
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels
        ]
        switch choice.format {
        case .original, .wav, .aiff:
            settings[AVFormatIDKey] = kAudioFormatLinearPCM
            settings[AVLinearPCMBitDepthKey] = bitDepth
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsBigEndianKey] = choice.format == .aiff
            settings[AVLinearPCMIsNonInterleaved] = false
        case .flac:
            settings[AVFormatIDKey] = kAudioFormatFLAC
            settings[AVEncoderBitDepthHintKey] = bitDepth
        case .alac:
            settings[AVFormatIDKey] = kAudioFormatAppleLossless
            settings[AVEncoderBitDepthHintKey] = bitDepth
        case .aac:
            settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
            settings[AVEncoderBitRateKey] = choice.aacBitrate.bitsPerSecond
        }
        return settings
    }
}

private extension String {
    nonisolated func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
