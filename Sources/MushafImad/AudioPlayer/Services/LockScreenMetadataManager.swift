//
//  LockScreenMetadataManager.swift
//  MushafImad
//
//  Service that owns the `MPNowPlayingInfoCenter` and  `MPRemoteCommandCenter`
//  configuration used to display
//  metadata on the lock screen and respond to remote controls.
//

import Foundation
import MediaPlayer

@MainActor
public final class LockScreenMetadataManager {
  public static let shared = LockScreenMetadataManager()

  private init() {}

  /// Configuration container used to register remote command handlers.
  public struct RemoteCommandConfig {
    public var onPlayPause: (() -> Void)?
    public var onNextTrack: (() -> Void)?
    public var onPreviousTrack: (() -> Void)?
    /// Called for skip-forward remote command (if supported).
    public var onSkipForward: (() -> Void)?
    /// Called for skip-backward remote command (if supported).
    public var onSkipBackward: (() -> Void)?

    public init(
      onPlayPause: (() -> Void)? = nil,
      onNextTrack: (() -> Void)? = nil,
      onPreviousTrack: (() -> Void)? = nil,
      onSkipForward: (() -> Void)? = nil,
      onSkipBackward: (() -> Void)? = nil
    ) {
      self.onPlayPause = onPlayPause
      self.onNextTrack = onNextTrack
      self.onPreviousTrack = onPreviousTrack
      self.onSkipForward = onSkipForward
      self.onSkipBackward = onSkipBackward
    }
  }

  /// Updates the system "Now Playing" info dictionary. The host
  /// application calls this whenever playback state or content changes.
  public func setNowPlayingInfo(
    surahName: String,
    reciterName: String,
    duration: TimeInterval,
    artwork: MPMediaItemArtwork? = nil
  ) {
    var info: [String: Any] = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
    info[MPMediaItemPropertyTitle] = surahName
    info[MPMediaItemPropertyArtist] = reciterName
    info[MPMediaItemPropertyPlaybackDuration] = duration
    if let artwork = artwork {
      info[MPMediaItemPropertyArtwork] = artwork
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  /// Updates only the elapsed playback time.  Call this repeatedly (e.g. once
  /// per second) without touching the other metadata fields.
  public func updateElapsedTime(_ currentTime: TimeInterval) {
    guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  /// Register remote command handlers using the provided configuration.
  ///
  /// The configuration is fully optional — pass only the handlers you want the
  /// system to react to. Commands without handlers will be disabled. Doing
  /// nothing is a valid customization; commands will be ignored if the
  /// corresponding closure is nil.
  public func setupRemoteCommands(_ config: RemoteCommandConfig) {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Helper to register or clear a command
    func register(_ command: MPRemoteCommand, handler: (() -> Void)?) {
      command.removeTarget(nil)
      if let h = handler {
        command.addTarget { _ in
          h()
          return .success
        }
        command.isEnabled = true
      } else {
        command.isEnabled = false
      }
    }

    // Play / Pause share the same handler
    register(commandCenter.playCommand, handler: config.onPlayPause)
    register(commandCenter.pauseCommand, handler: config.onPlayPause)

    // Track navigation
    register(commandCenter.nextTrackCommand, handler: config.onNextTrack)
    register(commandCenter.previousTrackCommand, handler: config.onPreviousTrack)

    // Optional skip commands (supported on some remotes)
    register(commandCenter.skipForwardCommand, handler: config.onSkipForward)
    register(commandCenter.skipBackwardCommand, handler: config.onSkipBackward)

  }

  /// Convenience: remove all registered remote command handlers and disable commands.
  public func clearRemoteCommands() {
    let commandCenter = MPRemoteCommandCenter.shared()

    func clear(_ command: MPRemoteCommand) {
      command.removeTarget(nil)
      command.isEnabled = false
    }

    clear(commandCenter.playCommand)
    clear(commandCenter.pauseCommand)
    clear(commandCenter.nextTrackCommand)
    clear(commandCenter.previousTrackCommand)
    clear(commandCenter.skipForwardCommand)
    clear(commandCenter.skipBackwardCommand)

  }

  /// Returns true if any remote command has been enabled/registered.
  public func hasRegisteredCommands() -> Bool {
    let cc = MPRemoteCommandCenter.shared()
    return cc.playCommand.isEnabled || cc.pauseCommand.isEnabled || cc.nextTrackCommand.isEnabled
      || cc.previousTrackCommand.isEnabled || cc.skipForwardCommand.isEnabled
      || cc.skipBackwardCommand.isEnabled
  }
}
