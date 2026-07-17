//
//  QuranPlayerCoordinator.swift
//  MushafImad
//
//  Singleton that tracks the currently active audio player so that
//  secondary surfaces (e.g. the macOS menu-bar popover) can observe
//  and control playback without a direct reference to the view model.
//

import Foundation

@MainActor
public final class QuranPlayerCoordinator: ObservableObject {
    public static let shared = QuranPlayerCoordinator()

    /// What the active player is currently reciting. Small on purpose: it lets a view follow
    /// playback without holding a player, and anything larger becomes a mirror that drifts.
    public struct NowPlaying: Equatable, Sendable {
        public let chapterNumber: Int
        /// 0 is the opening basmala.
        public let verseNumber: Int

        public init(chapterNumber: Int, verseNumber: Int) {
            self.chapterNumber = chapterNumber
            self.verseNumber = verseNumber
        }
    }

    // Weak so the coordinator never prevents the view model from being
    // deallocated — important on macOS where onDisappear may not fire
    // reliably when a window is force-quit or closed via Cmd+W.
    private weak var _activePlayer: QuranPlayerViewModel?

    @Published private var storedNowPlaying: NowPlaying?

    /// The player instance that is currently active (most recently registered).
    /// Returns nil automatically if the owning view has been deallocated.
    public var activePlayer: QuranPlayerViewModel? { _activePlayer }

    /// Whether any player is currently registered and has a valid configuration.
    public var hasActivePlayer: Bool {
        _activePlayer?.hasValidConfiguration ?? false
    }

    /// Computed rather than stored: a weak referent's deallocation fires no notification, so a
    /// stored value would keep reporting a verse from a player that no longer exists.
    public var nowPlaying: NowPlaying? {
        _activePlayer == nil ? nil : storedNowPlaying
    }

    private init() {}

    /// Call when a player becomes the primary playback surface.
    /// Playback is exclusive: the outgoing player is told to stand down. `resignActivePlayback()`
    /// rather than `pause()` because pause() no-ops on a player that is not already `.playing` —
    /// one still loading or seeking would ignore it and start audio after losing the slot.
    public func registerActivePlayer(_ player: QuranPlayerViewModel) {
        guard _activePlayer !== player else { return }
        objectWillChange.send()
        _activePlayer?.resignActivePlayback()
        _activePlayer = player
        storedNowPlaying = nil
    }

    /// Call when a player view disappears. Only unregisters if it matches the
    /// current active player to avoid race conditions during navigation.
    public func unregisterActivePlayer(_ player: QuranPlayerViewModel) {
        guard _activePlayer === player else { return }
        objectWillChange.send()
        _activePlayer = nil
        storedNowPlaying = nil
    }

    /// Called by a player whenever its playing verse changes. A nil verse means nothing is
    /// being recited (for example after `stop()`), which clears the projection.
    public func playerDidUpdateVerse(_ player: QuranPlayerViewModel, chapter: Int, verse: Int?) {
        guard _activePlayer === player else { return }
        guard let verse, chapter > 0 else {
            storedNowPlaying = nil
            return
        }
        storedNowPlaying = NowPlaying(chapterNumber: chapter, verseNumber: verse)
    }
}
