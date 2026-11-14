import Foundation

// Settings values (spec RF-2–RF-14). Nonisolated value types: the fade length is also read on the
// capture thread.

nonisolated enum MeterStyle: String, CaseIterable, Identifiable, Codable {
    case continuous
    /// 24 thin segments.
    case segmented

    var id: String { rawValue }
    var title: String {
        switch self {
        case .continuous: "Continuous"
        case .segmented: "Segmented"
        }
    }

    /// Number of segments/LEDs (nil for the continuous bar).
    var segmentCount: Int? {
        switch self {
        case .continuous: nil
        case .segmented: 24
        }
    }
}

nonisolated enum PeakHold: String, CaseIterable, Identifiable, Codable {
    case off
    case oneSecond
    case threeSeconds
    case untilReset

    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: "Off"
        case .oneSecond: "1 Second"
        case .threeSeconds: "3 Seconds"
        case .untilReset: "Until Reset"
        }
    }

    /// How long a held peak stays; nil for Off and Until Reset.
    var holdSeconds: TimeInterval? {
        switch self {
        case .oneSecond: 1
        case .threeSeconds: 3
        case .off, .untilReset: nil
        }
    }
}

nonisolated enum PauseFade: String, CaseIterable, Identifiable, Codable {
    case off
    case short
    case long

    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: "Off"
        case .short: "Short"
        case .long: "Long"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .off: 0
        case .short: 0.02
        case .long: 0.2
        }
    }
}

nonisolated enum RecordingTimeLimit: String, CaseIterable, Identifiable, Codable {
    case off
    case oneHour
    case twoHours
    case fourHours
    case eightHours

    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: "Off"
        case .oneHour: "1 Hour"
        case .twoHours: "2 Hours"
        case .fourHours: "4 Hours"
        case .eightHours: "8 Hours"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .off: nil
        case .oneHour: 3600
        case .twoHours: 7200
        case .fourHours: 14_400
        case .eightHours: 28_800
        }
    }
}

nonisolated enum LowStorageWarning: String, CaseIterable, Identifiable, Codable {
    case tenMinutes
    case thirtyMinutes
    case sixtyMinutes

    var id: String { rawValue }
    var title: String {
        switch self {
        case .tenMinutes: "10 Minutes Left"
        case .thirtyMinutes: "30 Minutes Left"
        case .sixtyMinutes: "60 Minutes Left"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .tenMinutes: 600
        case .thirtyMinutes: 1800
        case .sixtyMinutes: 3600
        }
    }
}

/// Format the share sheet opens with (RF-10).
nonisolated enum ExportDefault: Equatable, Codable {
    case lastUsed
    case fixed(ExportChoice)
}

nonisolated enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

nonisolated enum WaveformStyle: String, CaseIterable, Identifiable, Codable {
    case bars
    case line

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bars: "Bars"
        case .line: "Line"
        }
    }
}

/// Library order (RF-11; chosen in the library, stored separately).
nonisolated enum SessionSortOrder: String, CaseIterable, Identifiable, Codable {
    case newestFirst
    case oldestFirst
    case name

    var id: String { rawValue }
    var title: String {
        switch self {
        case .newestFirst: "Newest First"
        case .oldestFirst: "Oldest First"
        case .name: "Name"
        }
    }
}

/// All settings with the approved defaults (spec Decisions). Missing or unknown values decode as defaults,
/// so older or newer saved data never fails.
nonisolated struct AppSettings: Equatable, Codable {
    var meterStyle: MeterStyle = .continuous
    var peakHold: PeakHold = .oneSecond
    var pauseFade: PauseFade = .short
    var keepScreenOn = true
    var namePrefix = "Session"
    var timeLimit: RecordingTimeLimit = .off
    var lowStorageWarning: LowStorageWarning = .tenMinutes
    var exportDefault: ExportDefault = .lastUsed
    var theme: AppTheme = .system
    var waveformStyle: WaveformStyle = .bars

    static let defaults = AppSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.defaults
        func value<T: Decodable>(_ key: CodingKeys, _ defaultValue: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? defaultValue
        }
        meterStyle = value(.meterStyle, fallback.meterStyle)
        peakHold = value(.peakHold, fallback.peakHold)
        pauseFade = value(.pauseFade, fallback.pauseFade)
        keepScreenOn = value(.keepScreenOn, fallback.keepScreenOn)
        namePrefix = value(.namePrefix, fallback.namePrefix)
        timeLimit = value(.timeLimit, fallback.timeLimit)
        lowStorageWarning = value(.lowStorageWarning, fallback.lowStorageWarning)
        exportDefault = value(.exportDefault, fallback.exportDefault)
        theme = value(.theme, fallback.theme)
        waveformStyle = value(.waveformStyle, fallback.waveformStyle)
    }
}
