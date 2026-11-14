import AVFoundation
#if os(macOS)
import CoreAudio
#endif
import Combine
import CoreMedia
import Foundation
import os

/// Input device discovery and permission.
/// - macOS: `AVCaptureDevice` (each audio device, including USB interfaces, is listed).
/// - iOS: `AVAudioSession` inputs (ports). `AVCaptureDevice` only exposes a generic microphone there
///   that follows the audio route, so USB interfaces would not appear with their name and channels.
@MainActor
final class AudioInputDeviceService: ObservableObject {
    @Published private(set) var devices: [AudioInputDevice] = []
    @Published private(set) var permissionState: AudioInputPermissionState = .unknown
    /// True while the iOS audio session is being changed (input route, sample rate, open channels):
    /// channels and format are not final yet, so selection errors wait and capture stays stopped.
    @Published private(set) var isRoutingInput = false

    private var observers: [NSObjectProtocol] = []
    private let logger = Logger(subsystem: "SessionRecorder", category: "AudioInputDevices")
    #if os(iOS)
    /// AVAudioSession calls that change the session can block while it is active, so they never run
    /// on the main thread. Serial, so they apply in the order they were requested.
    private let sessionQueue = DispatchQueue(label: "SessionRecorder.AudioSession", qos: .userInitiated)
    /// iOS does not list supported rates; they are probed once per routed device (by port UID).
    private var probedSampleRates: [String: [Double]] = [:]
    /// Session changes queued or running; `isRoutingInput` is true while this is above 0.
    private var pendingSessionChanges = 0
    /// Session library playback owns the session (`.playback`); recording configuration is not restored.
    private var isPlaybackMode = false
    /// Rates probed on iOS (the ones recording can offer).
    nonisolated private static let probeCandidateRates: [Double] = [44_100, 48_000, 88_200, 96_000]

    /// Carries probe results from the session queue to the main actor.
    /// Nonisolated: filled on the session queue, read on the main actor after that work finished.
    nonisolated private final class SampleRateProbe: @unchecked Sendable {
        var rates: [Double] = []
    }
    #endif

    init() {
        #if os(iOS)
        updateSession { session, logger in
            Self.configure(session, logger: logger)
        }
        #endif
        refreshPermissionState()
        // Read once synchronously so the launch selection sees the devices; later refreshes are async on iOS.
        #if os(iOS)
        devices = Self.discoverAudioSessionInputs(probedSampleRates: probedSampleRates)
        #else
        refreshDevices()
        #endif
        observeDeviceChanges()
        observePermissionChangesIfNeeded()
    }

    deinit {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
    }

    /// iOS: the session is read on the session queue (after any queued change), because its getters
    /// block while a change (route, rate, channels) is running and would freeze the UI on the main thread.
    func refreshDevices() {
        #if os(iOS)
        // While the library plays, the `.playback` session has no input route, so devices would look
        // reduced (1 channel) and the selection would be recomputed mid-playback. Keep the last list;
        // it is refreshed when playback ends.
        guard !isPlaybackMode else { return }
        let probedSampleRates = self.probedSampleRates
        sessionQueue.async { [weak self] in
            let devices = Self.discoverAudioSessionInputs(probedSampleRates: probedSampleRates)
            Task { @MainActor [weak self] in
                self?.devices = devices
            }
        }
        #else
        devices = Self.discoverInputDevices()
        #endif
    }

    /// Routes audio input to the selected device so its channels and capture use it.
    /// iOS only (one input route at a time); macOS captures from any device directly.
    /// Asks the device to run at `rate` so recording needs no resampling (recording RF-1).
    /// iOS: preferred session rate (only for the routed device). macOS: device nominal rate.
    func preferSampleRate(_ rate: Double, deviceID: String) {
        #if os(iOS)
        updateRoutedSession { session, logger in
            guard session.currentRoute.inputs.first?.uid == deviceID, abs(session.sampleRate - rate) >= 1 else { return }
            do {
                try session.setPreferredSampleRate(rate)
            } catch {
                logger.error("Cannot set sample rate \(rate) Hz: \(error.localizedDescription, privacy: .public)")
            }
            // Some devices close the extra input channels when the rate changes.
            Self.openAllInputChannels(session, logger: logger)
        }
        #elseif os(macOS)
        let logger = self.logger
        DispatchQueue.global(qos: .userInitiated).async {
            Self.setCoreAudioNominalSampleRate(rate, deviceUID: deviceID, logger: logger)
        }
        #endif
    }

    /// Session library playback (library RF-2). iOS: `.playback` (not mixable), so audio plays through the
    /// speaker/route and the app owns Now Playing; when it ends, the recording configuration comes back.
    /// Returns once the session changed. Capture must be stopped before (the recording view model does it).
    func setPlaybackMode(_ active: Bool) async {
        #if os(iOS)
        guard isPlaybackMode != active else { return }
        isPlaybackMode = active
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            updateRoutedSession(change: { session, logger in
                if active {
                    do {
                        try session.setCategory(.playback, mode: .default, options: [])
                        try session.setActive(true)
                    } catch {
                        logger.error("Cannot configure playback: \(error.localizedDescription, privacy: .public)")
                    }
                } else {
                    Self.configure(session, logger: logger)
                    Self.openAllInputChannels(session, logger: logger)
                }
            }, beforeRefresh: {
                continuation.resume()
            })
        }
        #endif
    }

    /// The new channels arrive asynchronously through `devices`.
    func preferInput(deviceID: String) {
        #if os(iOS)
        let probe = SampleRateProbe()
        let needsProbe = probedSampleRates[deviceID] == nil
        updateRoutedSession(change: { session, logger in
            if let port = session.availableInputs?.first(where: { $0.uid == deviceID }),
               session.currentRoute.inputs.first?.uid != deviceID {
                do {
                    try session.setPreferredInput(port)
                } catch {
                    logger.error("Cannot route input to \(port.portName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            // Probe before opening the channels: rate changes can close them again.
            if needsProbe, session.currentRoute.inputs.first?.uid == deviceID {
                probe.rates = Self.probeSampleRates(session)
            }
            Self.openAllInputChannels(session, logger: logger)
        }, beforeRefresh: { [weak self] in
            if !probe.rates.isEmpty {
                self?.probedSampleRates[deviceID] = probe.rates
            }
        })
        #endif
    }

    func refreshPermissionState() {
        permissionState = Self.currentPermissionState()
    }

    func requestPermissionForDeviceSelection() async {
        let mediaType: AVMediaType = .audio
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch status {
        case .authorized:
            permissionState = .granted
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: mediaType)
            permissionState = granted ? .granted : .denied
        case .denied:
            permissionState = .denied
        case .restricted:
            permissionState = .restricted
        @unknown default:
            permissionState = .denied
        }
        if permissionState == .granted {
            refreshDevices()
        }
    }

    private func observeDeviceChanges() {
        let center = NotificationCenter.default
        #if os(iOS)
        // Connecting/disconnecting a USB interface or headset changes the audio route.
        let routeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // While the app is not active, iOS reports a temporarily reduced route (fewer channels);
                // devices are refreshed when the app becomes active again.
                guard UIApplication.shared.applicationState == .active, self?.isPlaybackMode == false else { return }
                self?.updateRoutedSession { session, logger in
                    Self.openAllInputChannels(session, logger: logger)
                }
            }
        }
        observers.append(routeObserver)
        #endif
        let names: [Notification.Name] = [
            AVCaptureDevice.wasConnectedNotification,
            AVCaptureDevice.wasDisconnectedNotification
        ]
        for name in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshDevices()
                }
            }
            observers.append(observer)
        }
    }

    private func observePermissionChangesIfNeeded() {
        #if os(macOS)
        // macOS does not post a universal capture-permission change notification; UI refresh is driven
        // by user retry/selection actions and app lifecycle checks.
        #else
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // In the background iOS may deactivate the session and close the extra input channels
                // without a route change, so restore them when the app is active again.
                self?.refreshPermissionState()
                // While the library plays, the playback configuration stays (restored when playback ends).
                guard self?.isPlaybackMode == false else { return }
                self?.updateRoutedSession { session, logger in
                    Self.configure(session, logger: logger)
                    Self.openAllInputChannels(session, logger: logger)
                }
            }
        }
        observers.append(observer)
        #endif
    }

    #if os(iOS)
    /// `.measurement` disables voice processing (gain/EQ/noise reduction) so line-level sources stay untouched.
    /// `.mixWithOthers` keeps other apps' audio playing while the app only shows devices or meters.
    /// Runs `change` on the session queue, then refreshes the device list.
    /// With `completion`, it runs on the main actor instead and is responsible for the refresh.
    private func updateSession(
        change: @escaping @Sendable (AVAudioSession, Logger) -> Void,
        completion: (@MainActor @Sendable () -> Void)? = nil
    ) {
        let logger = self.logger
        sessionQueue.async { [weak self] in
            change(AVAudioSession.sharedInstance(), logger)
            Task { @MainActor [weak self] in
                if let completion {
                    completion()
                } else {
                    self?.refreshDevices()
                }
            }
        }
    }

    private func updateSession(_ change: @escaping @Sendable (AVAudioSession, Logger) -> Void) {
        updateSession(change: change, completion: nil)
    }

    /// Like `updateSession`, but marks the session as changing (`isRoutingInput`) until it is done.
    /// `beforeRefresh` runs on the main actor before the final device refresh.
    private func updateRoutedSession(
        change: @escaping @Sendable (AVAudioSession, Logger) -> Void,
        beforeRefresh: (@MainActor @Sendable () -> Void)? = nil
    ) {
        pendingSessionChanges += 1
        isRoutingInput = true
        updateSession(change: change, completion: { [weak self] in
            guard let self else { return }
            beforeRefresh?()
            pendingSessionChanges -= 1
            isRoutingInput = pendingSessionChanges > 0
            // Refresh again with the change finished, so the selection is re-evaluated with final channels.
            refreshDevices()
        })
    }

    private func updateRoutedSession(_ change: @escaping @Sendable (AVAudioSession, Logger) -> Void) {
        updateRoutedSession(change: change, beforeRefresh: nil)
    }

    nonisolated private static func configure(_ session: AVAudioSession, logger: Logger) {
        do {
            if session.category != .playAndRecord || session.mode != .measurement
                || !session.categoryOptions.contains(.mixWithOthers) {
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers])
            }
            try session.setActive(true)
        } catch {
            logger.error("Cannot configure audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// iOS may open fewer channels than the device has (e.g., 1 or 2 of a mixer's inputs).
    /// Asks for each candidate rate and keeps the ones the hardware applies; restores the previous rate.
    nonisolated private static func probeSampleRates(_ session: AVAudioSession) -> [Double] {
        let original = session.sampleRate
        var supported: [Double] = []
        for rate in probeCandidateRates {
            guard (try? session.setPreferredSampleRate(rate)) != nil else { continue }
            if abs(session.sampleRate - rate) < 1 {
                supported.append(rate)
            }
        }
        try? session.setPreferredSampleRate(original)
        return supported
    }

    nonisolated private static func openAllInputChannels(_ session: AVAudioSession, logger: Logger) {
        let maximum = session.maximumInputNumberOfChannels
        guard maximum > 0, session.inputNumberOfChannels < maximum,
              session.currentRoute.inputs.first?.portType != .builtInMic else { return }
        do {
            try session.setPreferredInputNumberOfChannels(maximum)
        } catch {
            logger.error("Cannot open \(maximum) input channels: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated private static func discoverAudioSessionInputs(probedSampleRates: [String: [Double]]) -> [AudioInputDevice] {
        let session = AVAudioSession.sharedInstance()
        let routeInput = session.currentRoute.inputs.first
        return (session.availableInputs ?? [])
            .filter { !$0.uid.isEmpty }
            .map { port in
                // Channel details are reliable only for the port in the current route.
                let isRouteInput = port.uid == routeInput?.uid
                let described = (isRouteInput ? routeInput?.channels : port.channels) ?? []
                // Use the hardware maximum, not the currently open count, so the channel list does not
                // shrink while iOS is still opening the channels (openAllInputChannels).
                let routeChannelCount = isRouteInput && port.portType != .builtInMic
                    ? max(session.inputNumberOfChannels, session.maximumInputNumberOfChannels)
                    : 0
                let count = max(described.count, routeChannelCount, 1)
                // Device-provided channel names are not shown (only numbers), so they are not read.
                let channels = (1...count).map { number in
                    AudioInputChannel(id: "\(port.uid):\(number)", number: number, name: nil)
                }
                return AudioInputDevice(
                    id: port.uid,
                    displayName: port.portName,
                    channels: channels,
                    // Only wired USB interfaces/mixers count as external (RF-7); headsets and Bluetooth do not.
                    isExternal: port.portType == .usbAudio,
                    // Probed rates when known; otherwise the rate the route currently runs at.
                    supportedSampleRates: probedSampleRates[port.uid] ?? (isRouteInput ? [session.sampleRate] : [])
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }
    #endif

    private static func currentPermissionState() -> AudioInputPermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .notDetermined:
            return .unknown
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    private static func discoverInputDevices() -> [AudioInputDevice] {
        #if os(macOS)
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.microphone, .external]
        #elseif os(iOS)
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.microphone]
        if #available(iOS 17.0, *) {
            deviceTypes.append(.external)
        }
        #else
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.microphone]
        #endif

        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .audio,
            position: .unspecified
        )

        return session.devices
            .filter { !$0.uniqueID.isEmpty }
            .map { device in
                AudioInputDevice(
                    id: device.uniqueID,
                    displayName: device.localizedName,
                    channels: inputChannels(for: device),
                    isExternal: isExternalDevice(device),
                    supportedSampleRates: supportedSampleRates(for: device)
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private static func isExternalDevice(_ device: AVCaptureDevice) -> Bool {
        #if os(macOS)
        // On macOS USB interfaces are reported as `.microphone`, so use the Core Audio transport type.
        // Only wired hardware counts as external; Bluetooth, virtual, aggregate and Continuity inputs do not.
        let wiredTransportTypes: Set<UInt32> = [
            kAudioDeviceTransportTypeUSB,
            kAudioDeviceTransportTypeThunderbolt,
            kAudioDeviceTransportTypeFireWire,
            kAudioDeviceTransportTypePCI,
            kAudioDeviceTransportTypeAVB
        ]
        return wiredTransportTypes.contains(UInt32(bitPattern: device.transportType))
        #elseif os(iOS)
        return device.deviceType == .external
        #else
        return false
        #endif
    }

    /// Common rates checked against the device's continuous sample-rate ranges.
    private static let standardSampleRates: [Double] = [
        8_000, 11_025, 16_000, 22_050, 32_000, 44_100, 48_000, 88_200, 96_000, 176_400, 192_000
    ]

    private static func supportedSampleRates(for device: AVCaptureDevice) -> [Double] {
        #if os(macOS)
        let coreAudioRates = coreAudioNominalSampleRates(deviceUID: device.uniqueID)
        if !coreAudioRates.isEmpty {
            return coreAudioRates
        }
        #endif
        let rates = device.formats.compactMap { format in
            CMAudioFormatDescriptionGetStreamBasicDescription(format.formatDescription)?.pointee.mSampleRate
        }
        return Array(Set(rates.filter { $0 > 0 })).sorted()
    }

    #if os(macOS)
    /// Nominal sample rates reported by Core Audio for the device with this UID (same as `AVCaptureDevice.uniqueID`).
    private static func coreAudioNominalSampleRates(deviceUID: String) -> [Double] {
        guard let deviceID = coreAudioDeviceID(uid: deviceUID) else { return [] }
        var size = UInt32(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyAvailableNominalSampleRates,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ranges = [AudioValueRange](repeating: AudioValueRange(), count: Int(size) / MemoryLayout<AudioValueRange>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &ranges) == noErr else { return [] }

        var rates = Set<Double>()
        for range in ranges {
            if range.mMinimum == range.mMaximum {
                rates.insert(range.mMinimum)
            } else {
                standardSampleRates
                    .filter { $0 >= range.mMinimum && $0 <= range.mMaximum }
                    .forEach { rates.insert($0) }
            }
        }
        return rates.filter { $0 > 0 }.sorted()
    }

    /// Core Audio device for a UID (same as `AVCaptureDevice.uniqueID`).
    nonisolated private static func coreAudioDeviceID(uid deviceUID: String) -> AudioObjectID? {
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var uid = deviceUID as CFString
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let translateStatus = withUnsafeMutablePointer(to: &uid) { uidPointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString>.size),
                uidPointer,
                &size,
                &deviceID
            )
        }
        guard translateStatus == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    /// Sets the device's hardware sample rate (system-wide, as audio apps do) so capture needs no resampling.
    nonisolated private static func setCoreAudioNominalSampleRate(_ rate: Double, deviceUID: String, logger: Logger) {
        guard let deviceID = coreAudioDeviceID(uid: deviceUID) else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var current = Float64(0)
        var size = UInt32(MemoryLayout<Float64>.size)
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &current) == noErr, current == rate {
            return
        }
        var newRate = Float64(rate)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float64>.size), &newRate)
        if status != noErr {
            logger.error("Cannot set sample rate \(rate) Hz: OSStatus \(status)")
        }
    }
    #endif

    private static func inputChannels(for device: AVCaptureDevice) -> [AudioInputChannel] {
        #if os(macOS)
        let formatDescription = device.activeFormat.formatDescription
        let channelCount: Int
        if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee {
            channelCount = Int(asbd.mChannelsPerFrame)
        } else {
            channelCount = 0
        }
        if channelCount >= 1 {
            return (1...channelCount).map { number in
                AudioInputChannel(id: "\(device.uniqueID):\(number)", number: number, name: nil)
            }
        }
        // Fallback: expose a single input channel when layout details are unavailable.
        return [AudioInputChannel(id: "\(device.uniqueID):1", number: 1, name: nil)]
        #else
        let formatDescription = device.activeFormat.formatDescription
        if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee {
            let channelCount = Int(asbd.mChannelsPerFrame)
            if channelCount >= 1 {
                return (1...channelCount).map { number in
                    AudioInputChannel(id: "\(device.uniqueID):\(number)", number: number, name: nil)
                }
            }
        }
        return [AudioInputChannel(id: "\(device.uniqueID):1", number: 1, name: nil)]
        #endif
    }
}

#if canImport(UIKit) && !os(macOS)
import UIKit
#endif
