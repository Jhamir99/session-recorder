import SwiftUI

struct ChannelSelectionView: View {
    @EnvironmentObject private var viewModel: AudioSourceSelectionViewModel

    var body: some View {
        if viewModel.selectedDeviceID != nil {
            channelSection
        }
    }

    // Each element is its own form row inside the "Channels" section.
    @ViewBuilder
    private var channelSection: some View {
        if viewModel.permissionState != .granted {
            // Same notice as the Record tab (first-use RF-3): Allow Audio Input or Open Settings.
            AudioAccessNoticeView(
                access: AudioAccessLogic.accessState(for: viewModel.permissionState),
                onAllow: { Task { await viewModel.requestAccess() } },
                onOpenSettings: { SystemSettingsLink.openAudioInputSettings() }
            )
        } else {
            Picker("Mode", selection: modeBinding) {
                Text("Mono").tag(AudioChannelMode.mono)
                Text("Stereo").tag(AudioChannelMode.stereo)
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.selectedDevice == nil)

            if viewModel.displayedChannels.isEmpty {
                if viewModel.userMessage?.kind == .noChannelsAvailable {
                    Text(viewModel.userMessage?.text ?? "No channels are available for this device.")
                        .foregroundStyle(.secondary)
                }
            } else {
                channelRows
            }
        }
    }

    private var modeBinding: Binding<AudioChannelMode> {
        Binding(
            get: { viewModel.selectedMode },
            set: { viewModel.selectMode($0) }
        )
    }

    /// Compact menus (one row each) instead of a row per channel, so mixers with many inputs fit on screen.
    @ViewBuilder
    private var channelRows: some View {
        if viewModel.selectedMode == .stereo {
            channelPicker("Left", selection: stereoLeftBinding, excluding: stereoRightID)
            channelPicker("Right", selection: stereoRightBinding, excluding: stereoLeftID)
        } else {
            channelPicker("Channel", selection: monoBinding, excluding: nil)
        }
    }

    /// Menu of channel numbers; `excluding` hides the channel used by the other stereo side.
    private func channelPicker(_ title: LocalizedStringKey, selection: Binding<String?>, excluding excludedID: String?) -> some View {
        Picker(title, selection: selection) {
            if selection.wrappedValue == nil {
                Text("None").tag(String?.none)
            }
            ForEach(viewModel.displayedChannels.filter { $0.id != excludedID }) { channel in
                Text(verbatim: "\(channel.number)").tag(Optional(channel.id))
            }
        }
        .pickerStyle(.menu)
    }

    private var monoBinding: Binding<String?> {
        Binding(
            get: { viewModel.activeSelection?.mode == .mono ? viewModel.activeSelection?.monoChannelID : nil },
            set: { if let id = $0 { viewModel.selectMonoChannel(id: id) } }
        )
    }

    private var stereoLeftID: String? {
        viewModel.activeSelection?.mode == .stereo
            ? viewModel.activeSelection?.stereoLeftChannelID
            : viewModel.stereoLeftCandidateID
    }

    private var stereoRightID: String? {
        viewModel.activeSelection?.mode == .stereo ? viewModel.activeSelection?.stereoRightChannelID : nil
    }

    private var stereoLeftBinding: Binding<String?> {
        Binding(
            get: { stereoLeftID },
            set: { if let id = $0 { viewModel.selectStereoLeftChannel(id: id) } }
        )
    }

    private var stereoRightBinding: Binding<String?> {
        Binding(
            get: { stereoRightID },
            set: { if let id = $0 { viewModel.selectStereoRightChannel(id: id) } }
        )
    }
}
