//
//  BackgroundPlaybackHelper.swift
//  MushafImad
//
//  Observes a QuranPlayerViewModel to configure the audio session, update
//  lock-screen metadata, handle remote commands, and respond to interruptions.
//  Extracting this logic keeps the view model focused on playback state.
//

import Combine
import Foundation
import MediaPlayer

@MainActor
public final class BackgroundPlaybackHelper {
  private var cancellables = Set<AnyCancellable>()
  private weak var playerViewModel: QuranPlayerViewModel?

  public init() {}

  /// Attaches the helper to a QuranPlayerViewModel. This configures the audio session, sets up interruption handling, registers remote command handlers, and subscribes to playback state updates to keep lock-screen metadata in sync. Call `detach()` to remove these handlers and subscriptions when the player is deinitialized or when background playback support is no longer needed.
  public func attach(to player: QuranPlayerViewModel) {
    guard playerViewModel !== player else { return }

    cancellables.removeAll()
    playerViewModel = player

    // ensure session + interruption handling
    // Resolve the player when the interruption fires, not when it is attached, mirroring the
    // remote-command handlers below. `setupInterruptionHandling` replaces the previous observer
    // on every call (last-attach-wins), so a captured player here would let whichever player last
    // called `startIfNeeded` (the only path that reaches `attach`) own interruption resume even
    // after another player has taken the active slot — resuming the wrong, silenced player after
    // a phone call.
    Task { @MainActor in
      AudioSessionManager.shared.setupInterruptionHandling(
        onInterruptionBegan: { QuranPlayerCoordinator.shared.activePlayer?.pause() },
        onInterruptionEnded: { QuranPlayerCoordinator.shared.activePlayer?.startIfNeeded(autoPlay: true) }
      )
    }

    // Register default remote command handlers only if the app hasn't already
    // configured custom handlers. Apps can call
    // `LockScreenMetadataManager.shared.setupRemoteCommands(...)` at launch to
    // replace these defaults (for example, to register skip ±10s instead of
    // next/previous).
    // Resolve the player when the command fires, not when it is registered. These handlers
    // outlive any single player: the first attach wins the registration guard above and
    // detach() cannot clear MPRemoteCommandCenter, so a captured player would strand the
    // lock screen on a dead reference.
    if !LockScreenMetadataManager.shared.hasRegisteredCommands() {
      LockScreenMetadataManager.shared.setupRemoteCommands(
        .init(
          onPlayPause: { QuranPlayerCoordinator.shared.activePlayer?.togglePlayback() },
          onSkipForward: { _ = QuranPlayerCoordinator.shared.activePlayer?.seekToNextVerse() },
          onSkipBackward: { _ = QuranPlayerCoordinator.shared.activePlayer?.seekToPreviousVerse() }
        )
      )
    }

    // subscribe to updates
    player.$playbackState
      .sink { [weak self] state in
        guard let self, let player = self.playerViewModel else { return }
        let interval: TimeInterval = TimeInterval(Int(player.duration))
        if state == .finished { LockScreenMetadataManager.shared.updateElapsedTime(interval) }
        
        if state == .playing {
          LockScreenMetadataManager.shared.setNowPlayingInfo(
            surahName: player.chapterName,
            reciterName: player.reciterName,
            duration: interval
          )
        }
      }
      .store(in: &cancellables)

    player.$currentTime
      .map { Double(Int($0)) }
      .removeDuplicates()
      .sink { [weak self] time in
        guard self != nil else { return }
          LockScreenMetadataManager.shared.updateElapsedTime(time)
      }
      .store(in: &cancellables)
  }

  /// Detaches the helper from its QuranPlayerViewModel, removing all handlers and subscriptions. Call this when the player is deinitialized or when background playback support is no longer needed.
  public func detach() {
    cancellables.removeAll()
    playerViewModel = nil
  }
}
