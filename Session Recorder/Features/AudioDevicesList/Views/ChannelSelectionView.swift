import SwiftUI

struct ChannelSelectionView: View {
    @EnvironmentObject private var viewModel: AudioSourceSelectionViewModel

    var body: some View {
            if viewModel.selectedDeviceID != nil {
                channelSection
            }
    }

    @ViewBuilder
    private var channelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.showsPermissionPrompt, let message = viewModel.userMessage, message.kind == .permissionRequired {
                Text(message.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    viewModel.retryPermission()
                }
            } else if viewModel.permissionState == .granted {
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
    }

    private var modeBinding: Binding<AudioChannelMode> {
        Binding(
            get: { viewModel.selectedMode },
            set: { viewModel.selectMode($0) }
        )
    }

    @ViewBuilder
    private var channelRows: some View {
        if viewModel.selectedMode == .stereo {
            stereoChannelColumns
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.displayedChannels) { channel in
                    monoChannelRow(channel)
                }
            }
        }
    }

    private func monoChannelRow(_ channel: AudioInputChannel) -> some View {
        Button {
            viewModel.selectMonoChannel(id: channel.id)
        } label: {
            HStack {
                Text(AudioDeviceSelectionHelper.formatChannelLabel(number: channel.number, optionalName: channel.name))
                Spacer()
                channelSelectionIndicator(for: channel.id)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var stereoChannelColumns: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a channel for Left and Right.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                stereoChannelColumn(title: "Left", side: .left)
                stereoChannelColumn(title: "Right", side: .right)
            }
        }
    }

    private enum StereoSide {
        case left
        case right
    }

    private func stereoChannelColumn(title: String, side: StereoSide) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            ForEach(viewModel.displayedChannels) { channel in
                Button {
                    switch side {
                    case .left:
                        viewModel.selectStereoLeftChannel(id: channel.id)
                    case .right:
                        viewModel.selectStereoRightChannel(id: channel.id)
                    }
                } label: {
                    HStack {
                        Text(AudioDeviceSelectionHelper.formatChannelLabel(number: channel.number, optionalName: channel.name))
                            .lineLimit(1)
                        Spacer()
                        stereoColumnIndicator(for: channel.id, side: side)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(isStereoChannelDisabled(channelID: channel.id, side: side))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func channelSelectionIndicator(for channelID: String) -> some View {
        if viewModel.activeSelection?.mode == .mono, viewModel.activeSelection?.monoChannelID == channelID {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
        }
    }

    @ViewBuilder
    private func stereoColumnIndicator(for channelID: String, side: StereoSide) -> some View {
        switch side {
        case .left:
            let selectedLeft = viewModel.activeSelection?.mode == .stereo
                ? viewModel.activeSelection?.stereoLeftChannelID
                : viewModel.stereoLeftCandidateID
            if selectedLeft == channelID {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        case .right:
            if viewModel.activeSelection?.mode == .stereo, viewModel.activeSelection?.stereoRightChannelID == channelID {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
    }

    private func isStereoChannelDisabled(channelID: String, side: StereoSide) -> Bool {
        switch side {
        case .left:
            if viewModel.activeSelection?.mode == .stereo {
                return viewModel.activeSelection?.stereoRightChannelID == channelID
            }
            return false
        case .right:
            let left = viewModel.activeSelection?.mode == .stereo
                ? viewModel.activeSelection?.stereoLeftChannelID
                : viewModel.stereoLeftCandidateID
            return left == channelID
        }
    }
}
