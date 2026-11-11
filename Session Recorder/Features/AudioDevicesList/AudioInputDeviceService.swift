import AVFoundation
#if os(macOS)
import CoreAudio
#endif
import Combine
import CoreMedia
import Foundation

@MainActor
final class AudioInputDeviceService: ObservableObject {
    @Published private(set) var devices: [AudioInputDevice] = []
    @Published private(set) var permissionState: AudioInputPermissionState = .unknown

    private var observers: [NSObjectProtocol] = []

    init() {
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
        let discovered = Self.discoverInputDevices()
        devices = discovered
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
                self?.refreshPermissionState()
                if self?.permissionState == .granted {
                    self?.refreshDevices()
                }
            }
        }
        observers.append(observer)
        #endif
    }

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
                    isExternal: isExternalDevice(device)
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
