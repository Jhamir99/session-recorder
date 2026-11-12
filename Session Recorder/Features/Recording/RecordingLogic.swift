import Foundation

/// Pure recording rules: explicit inputs, deterministic outputs, no I/O.
enum RecordingLogic {
    static let allowedSampleRates: [Double] = [44_100, 48_000]
    static let allowedBitDepths: [Int] = [16, 24]
    /// Used (with conversion) when the device supports none of the allowed rates (RF-1).
    static let fallbackSampleRate: Double = 48_000

    /// Recording cannot start with less than this (RF-3); recording stops at this limit (RF-8).
    static let minimumRemainingSeconds: TimeInterval = 60
    static let lowStorageWarningSeconds: TimeInterval = 10 * 60
    static let clipHoldSeconds: TimeInterval = 2
    /// Peaks at or above this count as clipping (about -0.01 dBFS; integer sources never reach exactly 1).
    static let clipThreshold: Float = 0.999
    /// Bottom of the meter scale.
    static let meterFloorDecibels: Float = -60

    // MARK: Quality (RF-1)

    static func offeredSampleRates(deviceSupportedRates: [Double]) -> [Double] {
        let offered = allowedSampleRates.filter { rate in
            deviceSupportedRates.contains { abs($0 - rate) < 1 }
        }
        return offered.isEmpty ? [fallbackSampleRate] : offered
    }

    static func offeredQualities(deviceSupportedRates: [Double]) -> [RecordingQuality] {
        offeredSampleRates(deviceSupportedRates: deviceSupportedRates).flatMap { rate in
            allowedBitDepths.map { RecordingQuality(sampleRate: rate, bitDepth: $0) }
        }
    }

    static func highestQuality(in offered: [RecordingQuality]) -> RecordingQuality {
        offered.max { lhs, rhs in
            (lhs.bitDepth, lhs.sampleRate) < (rhs.bitDepth, rhs.sampleRate)
        } ?? RecordingQuality(sampleRate: fallbackSampleRate, bitDepth: 24)
    }

    /// Saved quality if the device still offers it, otherwise the highest offered quality.
    static func resolveQuality(saved: RecordingQuality?, offered: [RecordingQuality]) -> RecordingQuality {
        if let saved, offered.contains(saved) {
            return saved
        }
        return highestQuality(in: offered)
    }

    // MARK: Storage (RF-3, RF-4, RF-8)

    static func bytesPerSecond(quality: RecordingQuality, channelCount: Int) -> Double {
        quality.sampleRate * Double(quality.bitDepth / 8) * Double(channelCount)
    }

    static func remainingSeconds(freeBytes: Int64, bytesPerSecond: Double) -> TimeInterval {
        guard bytesPerSecond > 0 else { return 0 }
        return max(0, Double(freeBytes) / bytesPerSecond)
    }

    static func startError(
        permission: AudioInputPermissionState,
        hasValidSource: Bool,
        remainingSeconds: TimeInterval
    ) -> RecordingStartError? {
        if permission != .granted { return .permissionRequired }
        if !hasValidSource { return .noValidSource }
        if remainingSeconds < minimumRemainingSeconds { return .notEnoughStorage }
        return nil
    }

    enum StorageDecision: Equatable {
        case none
        case warn
        case stop
    }

    static func storageDecision(remainingSeconds: TimeInterval, warningAlreadyShown: Bool) -> StorageDecision {
        if remainingSeconds <= minimumRemainingSeconds { return .stop }
        if remainingSeconds <= lowStorageWarningSeconds, !warningAlreadyShown { return .warn }
        return .none
    }

    // MARK: Session name (RF-6)

    /// `Session YYYY-MM-DD HH.mm`, with ` (2)`, ` (3)`… when the name is taken.
    static func sessionName(startDate: Date, calendar: Calendar, existingNames: Set<String>) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: startDate)
        let base = String(
            format: "Session %04d-%02d-%02d %02d.%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0
        )
        guard existingNames.contains(base) else { return base }
        var number = 2
        while existingNames.contains("\(base) (\(number))") {
            number += 1
        }
        return "\(base) (\(number))"
    }

    // MARK: Pause/resume (RF-5, RF-8)

    static func canResume(state: RecordingState, isRecordingDeviceConnected: Bool) -> Bool {
        guard case .paused = state else { return false }
        return isRecordingDeviceConnected
    }

    // MARK: Meters (RF-2)

    static func isClipping(peak: Float) -> Bool {
        peak >= clipThreshold
    }

    static func isClipIndicatorVisible(lastClipDate: Date?, now: Date) -> Bool {
        guard let lastClipDate else { return false }
        return now.timeIntervalSince(lastClipDate) < clipHoldSeconds
    }

    /// Linear peak (0...1) → meter position (0...1) on a dB scale from `meterFloorDecibels` to 0 dBFS.
    static func meterValue(peak: Float) -> Float {
        guard peak > 0 else { return 0 }
        let decibels = 20 * log10(min(peak, 1))
        return max(0, min(1, 1 - decibels / meterFloorDecibels))
    }

    // MARK: Formatting (RF-4)

    /// `H:MM:SS`.
    static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    static func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// `About 5 h left`, `About 25 min left`, `Less than 1 min left`.
    static func formatRemaining(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "Less than 1 min left" }
        if minutes < 60 { return "About \(minutes) min left" }
        return "About \(minutes / 60) h left"
    }
}
