import Accelerate
import AVFoundation
import Foundation

/// Waveform overview of a session (plan §3): 10 peaks per second (max of all channels), read in chunks
/// off the main thread with partial results, and cached in `Caches/Waveforms/` (approved 2026-11-14).
/// Synchronous API meant to run inside a detached task; it stops early when that task is cancelled.
nonisolated struct WaveformService: Sendable {
    enum WaveformError: Error {
        case cancelled
    }

    /// Cache file: magic, version, peaks per second, peak count, then one byte per peak.
    private static let magic: [UInt8] = Array("SRWF".utf8)
    private static let version: UInt8 = 1
    private static let headerSize = 10

    let cacheDirectory: URL
    /// Seconds of audio read between partial updates.
    let partialUpdateInterval: TimeInterval

    init(
        cacheDirectory: URL = URL.cachesDirectory.appending(path: "Waveforms", directoryHint: .isDirectory),
        partialUpdateInterval: TimeInterval = 60
    ) {
        self.cacheDirectory = cacheDirectory
        self.partialUpdateInterval = partialUpdateInterval
    }

    /// Cached waveform if it matches the file; otherwise computes it (calling `onPartial` as it progresses)
    /// and caches it. Throws `WaveformError.cancelled` when the task is cancelled.
    func waveform(for url: URL, onPartial: (WaveformData) -> Void = { _ in }) throws -> WaveformData {
        let cacheURL = cacheFileURL(for: url)
        if let cacheURL, let cached = Self.readCache(at: cacheURL) {
            return cached
        }
        let waveform = try compute(url: url, onPartial: onPartial)
        if let cacheURL {
            Self.writeCache(waveform, to: cacheURL, directory: cacheDirectory)
        }
        return waveform
    }

    /// Removes the cache entry of a session (when it is deleted).
    func removeCache(for url: URL) {
        guard let cacheURL = cacheFileURL(for: url) else { return }
        try? FileManager.default.removeItem(at: cacheURL)
    }

    // MARK: Computing

    func compute(url: URL, onPartial: (WaveformData) -> Void = { _ in }) throws -> WaveformData {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let peaksPerSecond = WaveformData.defaultPeaksPerSecond
        let framesPerPeak = max(Int((format.sampleRate / Double(peaksPerSecond)).rounded()), 1)
        // About one second per read, a whole number of peaks.
        let peaksPerChunk = peaksPerSecond
        let chunkFrames = AVAudioFrameCount(framesPerPeak * peaksPerChunk)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else { return WaveformData(peaksPerSecond: peaksPerSecond, peaks: []) }

        var peaks: [Float] = []
        peaks.reserveCapacity(Int(Double(file.length) / Double(framesPerPeak)) + 1)
        let peaksPerUpdate = Int(partialUpdateInterval) * peaksPerSecond
        var nextUpdate = peaksPerUpdate
        let channelCount = Int(format.channelCount)

        while file.framePosition < file.length {
            if Task.isCancelled { throw WaveformError.cancelled }
            try file.read(into: buffer, frameCount: chunkFrames)
            let frames = Int(buffer.frameLength)
            guard frames > 0, let channels = buffer.floatChannelData else { break }
            var start = 0
            while start < frames {
                let count = min(framesPerPeak, frames - start)
                var peak: Float = 0
                for channel in 0..<channelCount {
                    var channelPeak: Float = 0
                    vDSP_maxmgv(channels[channel] + start, 1, &channelPeak, vDSP_Length(count))
                    peak = max(peak, channelPeak)
                }
                peaks.append(min(peak, 1))
                start += count
            }
            if peaks.count >= nextUpdate {
                onPartial(WaveformData(peaksPerSecond: peaksPerSecond, peaks: peaks))
                nextUpdate += peaksPerUpdate
            }
        }
        return WaveformData(peaksPerSecond: peaksPerSecond, peaks: peaks)
    }

    // MARK: Cache

    /// Named by `SessionLibraryLogic.waveformCacheKey`: kept on rename, new when the audio changes.
    private func cacheFileURL(for url: URL) -> URL? {
        guard let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey, .contentModificationDateKey]),
              let size = values.fileSize, let modified = values.contentModificationDate else { return nil }
        let key = SessionLibraryLogic.waveformCacheKey(
            creationDate: values.creationDate,
            fileSizeBytes: Int64(size),
            modificationDate: modified
        )
        return cacheDirectory.appending(path: key).appendingPathExtension("peaks")
    }

    private static func readCache(at url: URL) -> WaveformData? {
        guard let data = try? Data(contentsOf: url), data.count >= headerSize,
              Array(data.prefix(4)) == magic, data[4] == version else { return nil }
        let peaksPerSecond = Int(data[5])
        let count = data[6..<10].reduce(0) { $0 << 8 | Int($1) }
        guard peaksPerSecond > 0, data.count == headerSize + count else { return nil }
        let peaks = data.dropFirst(headerSize).map(SessionLibraryLogic.peak(fromQuantized:))
        return WaveformData(peaksPerSecond: peaksPerSecond, peaks: peaks)
    }

    private static func writeCache(_ waveform: WaveformData, to url: URL, directory: URL) {
        let count = waveform.peaks.count
        var data = Data(magic)
        data.append(version)
        data.append(UInt8(clamping: waveform.peaksPerSecond))
        data.append(contentsOf: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: count >> $0) })
        data.append(contentsOf: waveform.peaks.map(SessionLibraryLogic.quantizedPeak))
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // The cache is optional: a failed write only means computing it again next time.
        try? data.write(to: url, options: .atomic)
    }
}
