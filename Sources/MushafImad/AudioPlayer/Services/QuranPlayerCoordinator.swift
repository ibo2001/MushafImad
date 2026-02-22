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

    // Weak so the coordinator never prevents the view model from being
    // deallocated — important on macOS where onDisappear may not fire
    // reliably when a window is force-quit or closed via Cmd+W.
    private weak var _activePlayer: QuranPlayerViewModel?

    /// The player instance that is currently active (most recently registered).
    /// Returns nil automatically if the owning view has been deallocated.
    public var activePlayer: QuranPlayerViewModel? { _activePlayer }

    /// Whether any player is currently registered and has a valid configuration.
    public var hasActivePlayer: Bool {
        _activePlayer?.hasValidConfiguration ?? false
    }

    private init() {}

    /// Call when a player view appears and becomes the primary playback surface.
    public func registerActivePlayer(_ player: QuranPlayerViewModel) {
        objectWillChange.send()
        _activePlayer = player
    }

    /// Call when a player view disappears. Only unregisters if it matches the
    /// current active player to avoid race conditions during navigation.
    public func unregisterActivePlayer(_ player: QuranPlayerViewModel) {
        guard _activePlayer === player else { return }
        objectWillChange.send()
        _activePlayer = nil
    }
}
