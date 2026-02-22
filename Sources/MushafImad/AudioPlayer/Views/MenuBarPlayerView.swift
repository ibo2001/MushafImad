//
//  MenuBarPlayerView.swift
//  MushafImad
//
//  Compact player view designed for the macOS MenuBarExtra popover.
//  Reads playback state from QuranPlayerCoordinator.shared and
//  forwards control actions to the active QuranPlayerViewModel.
//

#if os(macOS)
import SwiftUI

public struct MenuBarPlayerView: View {
    @ObservedObject private var coordinator = QuranPlayerCoordinator.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if let player = coordinator.activePlayer,
               player.hasValidConfiguration {
                ActivePlayerContent(player: player)
            } else {
                idleContent
            }
        }
        .frame(width: 280)
    }

    // MARK: - Idle State

    private var idleContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text(String(localized: "No audio playing"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(height: 100)
    }
}

// MARK: - Active Player Content

/// Extracted into its own view so that SwiftUI subscribes to the
/// player's @Published properties via @ObservedObject.
private struct ActivePlayerContent: View {
    @ObservedObject var player: QuranPlayerViewModel

    var body: some View {
        VStack(spacing: 12) {
            // "Now Playing" header
            HStack {
                Image(systemName: "music.quarternote.3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(localized: "Now Playing"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Surah and Reciter info
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Text(player.chapterName)
                        .font(.system(size: 15, weight: .semibold))
                    if let verse = player.currentVerseNumber, verse > 0 {
                        Text(":")
                            .environment(\.layoutDirection, .leftToRight)
                        Text("\(verse)")
                    }
                    Spacer()
                }

                HStack {
                    Text(player.reciterName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 12)

            // Playback controls
            HStack(spacing: 28) {
                Button { _ = player.seekToPreviousVerse() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(String(localized: "Previous verse")))
                .disabled(player.isLoading)

                Button(action: player.togglePlayback) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(player.isPlaying
                    ? String(localized: "Pause")
                    : String(localized: "Play")))
                .disabled(player.isLoading && !player.isPlaying)

                Button { _ = player.seekToNextVerse() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(String(localized: "Next verse")))
                .disabled(player.isLoading)
            }
            .foregroundStyle(.brand900)
            .environment(\.layoutDirection, .leftToRight)
            .padding(.vertical, 8)

            // Playback state label
            playbackStateLabel
                .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var playbackStateLabel: some View {
        switch player.playbackState {
        case .loading:
            stateLabel(String(localized: "Loading…"), systemImage: "arrow.triangle.2.circlepath")
        case .paused:
            stateLabel(String(localized: "Paused"), systemImage: "pause.fill")
        case .playing:
            stateLabel(String(localized: "Playing"), systemImage: "waveform")
        case .finished:
            stateLabel(String(localized: "Finished"), systemImage: "checkmark.circle.fill")
        default:
            EmptyView()
        }
    }

    private func stateLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
#endif
