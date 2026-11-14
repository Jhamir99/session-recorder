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
        case .continuous: String(localized: "Continuous", comment: "Settings option value")
        case .segmented: String(localized: "Segmented", comment: "Settings option value")
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
        case .off: String(localized: "Off", comment: "Settings option value")
        case .oneSecond: String(localized: "1 Second", comment: "Settings option value")
        case .threeSeconds: String(localized: "3 Seconds", comment: "Settings option value")
        case .untilReset: String(localized: "Until Reset", comment: "Settings option value")
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
        case .off: String(localized: "Off", comment: "Settings option value")
        case .short: String(localized: "Short", comment: "Settings option value")
        case .long: String(localized: "Long", comment: "Settings option value")
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
        case .off: String(localized: "Off", comment: "Settings option value")
        case .oneHour: String(localized: "1 Hour", comment: "Settings option value")
        case .twoHours: String(localized: "2 Hours", comment: "Settings option value")
        case .fourHours: String(localized: "4 Hours", comment: "Settings option value")
        case .eightHours: String(localized: "8 Hours", comment: "Settings option value")
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
        case .tenMinutes: String(localized: "10 Minutes Left", comment: "Settings option value")
        case .thirtyMinutes: String(localized: "30 Minutes Left", comment: "Settings option value")
        case .sixtyMinutes: String(localized: "60 Minutes Left", comment: "Settings option value")
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
        case .system: String(localized: "System", comment: "Settings option value")
        case .light: String(localized: "Light", comment: "Settings option value")
        case .dark: String(localized: "Dark", comment: "Settings option value")
        }
    }
}

nonisolated enum WaveformStyle: String, CaseIterable, Identifiable, Codable {
    case bars
    case line

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bars: String(localized: "Bars", comment: "Settings option value")
        case .line: String(localized: "Line", comment: "Settings option value")
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
        case .newestFirst: String(localized: "Newest First", comment: "Settings option value")
        case .oldestFirst: String(localized: "Oldest First", comment: "Settings option value")
        case .name: String(localized: "Name", comment: "Settings option value")
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
