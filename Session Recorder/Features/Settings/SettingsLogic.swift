import Foundation

/// Pure settings rules (plan §2): explicit inputs, no I/O. Nonisolated: the fade gain is used on the
/// capture thread.
nonisolated enum SettingsLogic {
    static let maximumPrefixLength = 30
    /// Segments in the segmented meter (RF-2).
    static let meterSegmentCount = 24
    /// Meter positions (0...1 on the dB scale) where the zones start: about -12 dBFS and -3 dBFS,
    /// the same zones as the continuous meter.
    static let yellowZoneStart: Float = 0.8
    static let redZoneStart: Float = 0.95

    // MARK: Name prefix (RF-7)

    enum PrefixError: Error, Equatable {
        case empty
        case invalidCharacters
        case tooLong

        var message: String {
            switch self {
            case .empty: "Enter a name."
            case .invalidCharacters: "Names can't contain “/” or “:”."
            case .tooLong: "Use 30 characters or fewer."
            }
        }
    }

    static func validatePrefix(_ text: String) -> Result<String, PrefixError> {
        let prefix = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return .failure(.empty) }
        guard !prefix.contains(where: SessionLibraryLogic.invalidNameCharacters.contains) else { return .failure(.invalidCharacters) }
        guard prefix.count <= maximumPrefixLength else { return .failure(.tooLong) }
        return .success(prefix)
    }

    // MARK: Fade at pause/resume (RF-4)

    static func fadeFrames(_ fade: PauseFade, sampleRate: Double) -> Int {
        Int((fade.seconds * sampleRate).rounded())
    }

    /// Gain for frame `index` of a ramp of `length` frames: fading in goes 0 → 1 (first frame silent),
    /// fading out goes 1 → 0 (last frame silent). Outside a ramp the caller does not multiply at all.
    static func fadeGain(frameIndex index: Int, rampLength length: Int, fadingIn: Bool) -> Float {
        guard length > 0 else { return 1 }
        let position = Float(min(max(index, 0), length - 1)) / Float(max(length - 1, 1))
        return fadingIn ? position : 1 - position
    }

    // MARK: Time limit and storage (RF-8, RF-9)

    static func isTimeLimitReached(elapsedSeconds: TimeInterval, limit: RecordingTimeLimit) -> Bool {
        guard let seconds = limit.seconds else { return false }
        return elapsedSeconds >= seconds
    }

    // MARK: Peak hold (RF-3)

    struct HeldPeak: Equatable {
        var value: Float
        var since: Date
    }

    /// New held peak after a meter update; nil when peak hold is off.
    static func heldPeak(previous: HeldPeak?, peak: Float, now: Date, hold: PeakHold) -> HeldPeak? {
        guard hold != .off else { return nil }
        guard let previous, peak < previous.value else { return HeldPeak(value: peak, since: now) }
        if hold == .untilReset { return previous }
        if let seconds = hold.holdSeconds, now.timeIntervalSince(previous.since) < seconds { return previous }
        return HeldPeak(value: peak, since: now)
    }

    // MARK: Segmented meter (RF-2)

    enum MeterZone: Equatable {
        case green
        case yellow
        case red
    }

    /// Lit segments for a meter position (0...1, the same dB scale as the continuous meter).
    static func litSegments(meterValue: Float, segmentCount: Int = meterSegmentCount) -> Int {
        Int((min(max(meterValue, 0), 1) * Float(segmentCount)).rounded(.down))
    }

    static func zone(forSegment index: Int, segmentCount: Int = meterSegmentCount) -> MeterZone {
        let position = (Float(index) + 0.5) / Float(segmentCount)
        if position >= redZoneStart { return .red }
        if position >= yellowZoneStart { return .yellow }
        return .green
    }

    // MARK: Library (RF-11, RF-12)

    static func sorted(_ items: [SessionItem], by order: SessionSortOrder) -> [SessionItem] {
        switch order {
        case .newestFirst:
            return SessionLibraryLogic.sorted(items)
        case .oldestFirst:
            return SessionLibraryLogic.sorted(items).reversed()
        case .name:
            return items.sorted {
                let comparison = $0.name.localizedStandardCompare($1.name)
                return comparison == .orderedSame ? $0.recordedDate > $1.recordedDate : comparison == .orderedAscending
            }
        }
    }

    /// `12 sessions · 4.2 GB · 85 GB available` (singular for one session).
    static func storageSummary(sessionCount: Int, totalBytes: Int64, freeBytes: Int64) -> String {
        let sessions = sessionCount == 1 ? "1 session" : "\(sessionCount) sessions"
        let used = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let free = ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
        return "\(sessions) · \(used) · \(free) available"
    }
}
