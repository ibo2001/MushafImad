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

    /// The player instance that is currently active (most recently registered).
    @Published public private(set) var activePlayer: QuranPlayerViewModel?

    /// Whether any player is currently registered and has a valid configuration.
    public var hasActivePlayer: Bool {
        activePlayer?.hasValidConfiguration ?? false
    }

    private init() {}

    /// Call when a player view appears and becomes the primary playback surface.
    public func registerActivePlayer(_ player: QuranPlayerViewModel) {
        activePlayer = player
    }

    /// Call when a player view disappears. Only unregisters if it matches the
    /// current active player to avoid race conditions during navigation.
    public func unregisterActivePlayer(_ player: QuranPlayerViewModel) {
        if activePlayer === player {
            activePlayer = nil
        }
    }
}
