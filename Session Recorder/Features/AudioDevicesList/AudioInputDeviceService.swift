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

    private var observers: [NSObjectProtocol] = []
    private let logger = Logger(subsystem: "SessionRecorder", category: "AudioInputDevices")

    init() {
        #if os(iOS)
        configureAudioSession()
        #endif
        refreshPermissionState()
        refreshDevices()
        observeDeviceChanges()
        observePermissionChangesIfNeeded()
    }

    deinit {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
    }

    func refreshDevices() {
        #if os(iOS)
        devices = Self.discoverAudioSessionInputs()
        #else
        devices = Self.discoverInputDevices()
        #endif
    }

    /// Routes audio input to the selected device so its channels and capture use it.
    /// iOS only (one input route at a time); macOS captures from any device directly.
    func preferInput(deviceID: String) {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        guard let port = session.availableInputs?.first(where: { $0.uid == deviceID }) else { return }
        if session.currentRoute.inputs.first?.uid != deviceID {
            do {
                try session.setPreferredInput(port)
            } catch {
                logger.error("Cannot route input to \(port.portName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        openAllInputChannels()
        refreshDevices()
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
                guard UIApplication.shared.applicationState == .active else { return }
                self?.openAllInputChannels()
                self?.refreshDevices()
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
                self?.configureAudioSession()
                self?.openAllInputChannels()
                self?.refreshPermissionState()
                if self?.permissionState == .granted {
                    self?.refreshDevices()
                }
            }
        }
        observers.append(observer)
        #endif
    }

    #if os(iOS)
    /// `.measurement` disables voice processing (gain/EQ/noise reduction) so line-level sources stay untouched.
    /// `.mixWithOthers` keeps other apps' audio playing while the app only shows devices or meters.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            logger.error("Cannot configure audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// iOS may open fewer channels than the device has (e.g., 1 or 2 of a mixer's inputs).
    private func openAllInputChannels() {
        let session = AVAudioSession.sharedInstance()
        let maximum = session.maximumInputNumberOfChannels
        guard maximum > 0, session.inputNumberOfChannels < maximum,
              session.currentRoute.inputs.first?.portType != .builtInMic else { return }
        do {
            try session.setPreferredInputNumberOfChannels(maximum)
        } catch {
            logger.error("Cannot open \(maximum) input channels: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func discoverAudioSessionInputs() -> [AudioInputDevice] {
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
                    // iOS does not list supported rates; the current hardware rate is what the route runs at.
                    supportedSampleRates: isRouteInput ? [session.sampleRate] : []
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
        guard translateStatus == noErr, deviceID != kAudioObjectUnknown else { return [] }

        address = AudioObjectPropertyAddress(
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
