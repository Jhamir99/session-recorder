import Foundation

/// Pure library rules (plan §2): explicit inputs, no I/O, so they can be checked with a scratch script.
/// Nonisolated: also used by the waveform, trim and export work off the main thread.
nonisolated enum SessionLibraryLogic {
    /// Characters not allowed in session (file) names (RF-3).
    static let invalidNameCharacters: Set<Character> = ["/", ":"]
    static let minimumTrimDuration: TimeInterval = 1
    static let skipInterval: TimeInterval = 15
    /// FLAC/ALAC are typically 50–70 % of PCM for music; used for the "About" estimate (RF-6).
    static let losslessCompressionRatio = 0.6
    static let aacMaximumSampleRate: Double = 48_000

    // MARK: List (RF-1)

    /// Newest first; same date sorted by name.
    static func sorted(_ items: [SessionItem]) -> [SessionItem] {
        items.sorted {
            if $0.recordedDate != $1.recordedDate { return $0.recordedDate > $1.recordedDate }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// File creation date (kept when the file is moved or renamed); else the date in a default name
    /// (`Session YYYY-MM-DD HH.mm`); else the modification date.
    static func recordedDate(creationDate: Date?, fileName: String, modificationDate: Date, calendar: Calendar) -> Date {
        creationDate ?? dateFromDefaultName(fileName, calendar: calendar) ?? modificationDate
    }

    /// Parses `Session 2026-11-12 22.30` (with or without ` (2)`) in `calendar`'s time zone.
    static func dateFromDefaultName(_ name: String, calendar: Calendar) -> Date? {
        let pattern = #/^Session (\d{4})-(\d{2})-(\d{2}) (\d{2})\.(\d{2})/#
        guard let match = name.firstMatch(of: pattern) else { return nil }
        var components = DateComponents()
        components.year = Int(match.1)
        components.month = Int(match.2)
        components.day = Int(match.3)
        components.hour = Int(match.4)
        components.minute = Int(match.5)
        return calendar.date(from: components)
    }

    // MARK: Rename (RF-3)

    /// Trimmed name when it can be used; `currentName` (the session itself) never counts as a duplicate.
    static func validateRename(_ newName: String, currentName: String, existingNames: Set<String>) -> Result<String, RenameError> {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .failure(.empty) }
        guard !name.contains(where: invalidNameCharacters.contains) else { return .failure(.invalidCharacters) }
        let isTaken = existingNames.contains {
            $0.caseInsensitiveCompare(name) == .orderedSame && $0.caseInsensitiveCompare(currentName) != .orderedSame
        }
        return isTaken ? .failure(.duplicate) : .success(name)
    }

    // MARK: Trim (RF-5)

    /// `<name> (trimmed)`, then `<name> (trimmed 2)`, … (case-insensitive, like file names).
    static func trimmedName(for name: String, existingNames: Set<String>) -> String {
        let taken = Set(existingNames.map { $0.lowercased() })
        let base = "\(name) (trimmed)"
        guard taken.contains(base.lowercased()) else { return base }
        var number = 2
        while taken.contains("\(name) (trimmed \(number))".lowercased()) {
            number += 1
        }
        return "\(name) (trimmed \(number))"
    }

    /// Keeps the range inside the session and the start before the end.
    static func clampedTrimRange(_ range: TrimRange, duration: TimeInterval) -> TrimRange {
        let start = min(max(range.start, 0), duration)
        let end = min(max(range.end, start), duration)
        return TrimRange(start: start, end: end)
    }

    static func isValidTrim(_ range: TrimRange, duration: TimeInterval) -> Bool {
        range.start >= 0 && range.end <= duration && range.duration >= minimumTrimDuration
    }

    /// First frame and frame count of the range at `sampleRate`, within `totalFrames`.
    static func frameRange(for range: TrimRange, sampleRate: Double, totalFrames: Int64) -> (start: Int64, count: Int64) {
        let start = min(max(Int64((range.start * sampleRate).rounded()), 0), totalFrames)
        let end = min(max(Int64((range.end * sampleRate).rounded()), start), totalFrames)
        return (start, end - start)
    }

    static func trimmedRecordedDate(originalDate: Date, range: TrimRange) -> Date {
        originalDate.addingTimeInterval(range.start)
    }

    // MARK: Export (RF-6)

    /// Estimated file size; exact for PCM formats, approximate for FLAC/ALAC/AAC.
    static func estimatedExportBytes(choice: ExportChoice, info: SessionAudioInfo) -> Int64 {
        let pcmBytes = info.format.bytesPerSecond * info.duration
        let bytes = switch choice.format {
        case .original, .wav, .aiff: pcmBytes
        case .flac, .alac: pcmBytes * losslessCompressionRatio
        case .aac: Double(choice.aacBitrate.bitsPerSecond) / 8 * info.duration
        }
        return Int64(bytes.rounded())
    }

    /// Whether the estimate is exact (PCM) or shown as "About …".
    static func isExactEstimate(_ format: ExportFormat) -> Bool {
        [.original, .wav, .aiff].contains(format)
    }

    /// AAC keeps the session rate up to 48 kHz; higher rates are exported at 48 kHz.
    static func aacSampleRate(sessionRate: Double) -> Double {
        min(sessionRate, aacMaximumSampleRate)
    }

    // MARK: Waveform (RF-2, RF-5)

    /// One bar per `barCount` slice of `visible` (seconds): the highest peak in the slice.
    static func waveformBars(_ waveform: WaveformData, visible: ClosedRange<TimeInterval>, barCount: Int) -> [Float] {
        guard barCount > 0, !waveform.peaks.isEmpty, visible.upperBound > visible.lowerBound else {
            return Array(repeating: 0, count: max(barCount, 0))
        }
        let rate = Double(waveform.peaksPerSecond)
        let slice = (visible.upperBound - visible.lowerBound) / Double(barCount)
        return (0..<barCount).map { bar in
            let from = Int(((visible.lowerBound + Double(bar) * slice) * rate).rounded(.down))
            let to = Int(((visible.lowerBound + Double(bar + 1) * slice) * rate).rounded(.up))
            let lower = max(from, 0)
            let upper = min(max(to, lower + 1), waveform.peaks.count)
            guard lower < upper else { return 0 }
            return waveform.peaks[lower..<upper].max() ?? 0
        }
    }

    static func xPosition(time: TimeInterval, duration: TimeInterval, width: Double) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(time / duration, 0), 1) * width
    }

    static func time(xPosition: Double, width: Double, duration: TimeInterval) -> TimeInterval {
        guard width > 0 else { return 0 }
        return min(max(xPosition / width, 0), 1) * duration
    }

    /// Stable across renames (creation date and size do not change); changes when the audio changes.
    static func waveformCacheKey(creationDate: Date?, fileSizeBytes: Int64, modificationDate: Date) -> String {
        let created = Int64(((creationDate ?? .distantPast).timeIntervalSince1970 * 1000).rounded())
        let modified = Int64((modificationDate.timeIntervalSince1970 * 1000).rounded())
        return "\(created)-\(fileSizeBytes)-\(modified)"
    }

    /// Peak 0...1 stored as one byte (cache format).
    static func quantizedPeak(_ peak: Float) -> UInt8 {
        UInt8((min(max(peak, 0), 1) * 255).rounded())
    }

    static func peak(fromQuantized value: UInt8) -> Float {
        Float(value) / 255
    }

    // MARK: Formatting (RF-2, RF-5)

    /// `1:02:15` from one hour, otherwise `2:05`.
    static func formatPlaybackTime(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded(.down)), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// Trim handle times with tenths: `2:05.3`, `1:02:15.0`.
    static func formatTrimTime(_ seconds: TimeInterval) -> String {
        let tenths = max(Int((seconds * 10).rounded(.down)), 0)
        return "\(formatPlaybackTime(Double(tenths / 10))).\(tenths % 10)"
    }
}
