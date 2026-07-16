import Foundation
import Testing
@testable import MushafImad

// All tests run on the main actor because QuranPlayerCoordinator and
// QuranPlayerViewModel are both @MainActor-isolated.
@Suite(.serialized)
@MainActor
struct QuranPlayerCoordinatorTests {

    // Reset shared state before every test so tests are independent.
    init() {
        QuranPlayerCoordinator.shared.unregisterActivePlayer(
            QuranPlayerCoordinator.shared.activePlayer ?? QuranPlayerViewModel()
        )
    }

    // MARK: - registerActivePlayer

    @Test func registerSetsActivePlayer() {
        let player = QuranPlayerViewModel()
        QuranPlayerCoordinator.shared.registerActivePlayer(player)
        #expect(QuranPlayerCoordinator.shared.activePlayer === player)
    }

    @Test func registerReplacesExistingPlayer() {
        let first  = QuranPlayerViewModel()
        let second = QuranPlayerViewModel()
        QuranPlayerCoordinator.shared.registerActivePlayer(first)
        QuranPlayerCoordinator.shared.registerActivePlayer(second)
        #expect(QuranPlayerCoordinator.shared.activePlayer === second)
    }

    // MARK: - unregisterActivePlayer

    @Test func unregisterClearsActivePlayer() {
        let player = QuranPlayerViewModel()
        QuranPlayerCoordinator.shared.registerActivePlayer(player)
        QuranPlayerCoordinator.shared.unregisterActivePlayer(player)
        #expect(QuranPlayerCoordinator.shared.activePlayer == nil)
    }

    @Test func unregisterIgnoresMismatchedInstance() {
        let registered = QuranPlayerViewModel()
        let other      = QuranPlayerViewModel()
        QuranPlayerCoordinator.shared.registerActivePlayer(registered)
        // Attempting to unregister a different instance must be a no-op.
        QuranPlayerCoordinator.shared.unregisterActivePlayer(other)
        #expect(QuranPlayerCoordinator.shared.activePlayer === registered)
    }

    @Test func unregisterOnEmptyCoordinatorIsNoop() {
        // Should not crash or change state when nothing is registered.
        let player = QuranPlayerViewModel()
        QuranPlayerCoordinator.shared.unregisterActivePlayer(player)
        #expect(QuranPlayerCoordinator.shared.activePlayer == nil)
    }

    // MARK: - hasActivePlayer

    @Test func hasActivePlayerFalseWhenEmpty() {
        #expect(QuranPlayerCoordinator.shared.hasActivePlayer == false)
    }

    @Test func hasActivePlayerFalseForUnconfiguredPlayer() {
        // A player with no baseURL / chapterNumber is not "valid".
        let player = QuranPlayerViewModel()
        QuranPlayerCoordinator.shared.registerActivePlayer(player)
        #expect(QuranPlayerCoordinator.shared.hasActivePlayer == false)
    }

    @Test func hasActivePlayerTrueForConfiguredPlayer() {
        let player = QuranPlayerViewModel(
            baseURL: URL(string: "https://audio.example.com")!,
            chapterNumber: 1,
            chapterName: "الفاتحة"
        )
        QuranPlayerCoordinator.shared.registerActivePlayer(player)
        #expect(QuranPlayerCoordinator.shared.hasActivePlayer == true)
    }

    // MARK: - Weak reference

    @Test func activePlayerBecomesNilWhenOwnerIsDeallocated() {
        var player: QuranPlayerViewModel? = QuranPlayerViewModel()
        QuranPlayerCoordinator.shared.registerActivePlayer(player!)
        #expect(QuranPlayerCoordinator.shared.activePlayer != nil)

        // Releasing the only strong reference should nil-out the weak storage.
        player = nil
        #expect(QuranPlayerCoordinator.shared.activePlayer == nil)
    }

    // MARK: - NowPlaying projection

    private func configuredPlayer(chapter: Int) -> QuranPlayerViewModel {
        QuranPlayerViewModel(
            baseURL: URL(string: "https://audio.example.com")!,
            chapterNumber: chapter,
            chapterName: "test"
        )
    }

    @Test func nowPlayingIsNilWhenNothingIsRegistered() {
        #expect(QuranPlayerCoordinator.shared.nowPlaying == nil)
    }

    @Test func activePlayerVerseUpdateIsPublished() {
        let player = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(player)

        QuranPlayerCoordinator.shared.playerDidUpdateVerse(player, chapter: 2, verse: 5)

        #expect(QuranPlayerCoordinator.shared.nowPlaying
                == QuranPlayerCoordinator.NowPlaying(chapterNumber: 2, verseNumber: 5))
    }

    /// Basmala is verse 0 and must survive the projection; MushafView relies on it to
    /// navigate without highlighting.
    @Test func basmalaVerseZeroIsPublished() {
        let player = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(player)

        QuranPlayerCoordinator.shared.playerDidUpdateVerse(player, chapter: 2, verse: 0)

        #expect(QuranPlayerCoordinator.shared.nowPlaying?.verseNumber == 0)
    }

    /// stop() sets currentVerseNumber = nil, which pushes nil. That is how the highlight clears.
    @Test func nilVerseClearsNowPlaying() {
        let player = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(player)
        QuranPlayerCoordinator.shared.playerDidUpdateVerse(player, chapter: 2, verse: 5)

        QuranPlayerCoordinator.shared.playerDidUpdateVerse(player, chapter: 2, verse: nil)

        #expect(QuranPlayerCoordinator.shared.nowPlaying == nil)
    }

    /// A player that lost the active slot must not move the highlight from under the new one.
    @Test func staleUpdateFromInactivePlayerIsIgnored() {
        let old = configuredPlayer(chapter: 2)
        let new = configuredPlayer(chapter: 3)
        QuranPlayerCoordinator.shared.registerActivePlayer(old)
        QuranPlayerCoordinator.shared.registerActivePlayer(new)
        QuranPlayerCoordinator.shared.playerDidUpdateVerse(new, chapter: 3, verse: 1)

        QuranPlayerCoordinator.shared.playerDidUpdateVerse(old, chapter: 2, verse: 99)

        #expect(QuranPlayerCoordinator.shared.nowPlaying
                == QuranPlayerCoordinator.NowPlaying(chapterNumber: 3, verseNumber: 1))
    }

    @Test func registeringNewPlayerClearsPreviousNowPlaying() {
        let first = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(first)
        QuranPlayerCoordinator.shared.playerDidUpdateVerse(first, chapter: 2, verse: 5)

        // `second` must be held in a local. Registering a temporary would let it deallocate
        // immediately, and nowPlaying would go nil via the weak reference rather than via the
        // clear this test is about — passing for the wrong reason.
        let second = configuredPlayer(chapter: 3)
        QuranPlayerCoordinator.shared.registerActivePlayer(second)

        #expect(QuranPlayerCoordinator.shared.nowPlaying == nil)
        #expect(QuranPlayerCoordinator.shared.activePlayer === second)
    }

    @Test func unregisterClearsNowPlaying() {
        let player = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(player)
        QuranPlayerCoordinator.shared.playerDidUpdateVerse(player, chapter: 2, verse: 5)

        QuranPlayerCoordinator.shared.unregisterActivePlayer(player)

        #expect(QuranPlayerCoordinator.shared.nowPlaying == nil)
    }

    /// A weak referent's deallocation fires no notification, so a stored projection would
    /// strand the highlight on a dead player.
    @Test func nowPlayingClearsWhenActivePlayerIsDeallocated() {
        var player: QuranPlayerViewModel? = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(player!)
        QuranPlayerCoordinator.shared.playerDidUpdateVerse(player!, chapter: 2, verse: 5)
        #expect(QuranPlayerCoordinator.shared.nowPlaying != nil)

        player = nil

        #expect(QuranPlayerCoordinator.shared.nowPlaying == nil)
    }

    /// Re-registering the active player must not pause it — a player would stop its own audio
    /// on its second play().
    @Test func reregisteringActivePlayerKeepsItActive() {
        let player = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(player)
        QuranPlayerCoordinator.shared.playerDidUpdateVerse(player, chapter: 2, verse: 5)

        QuranPlayerCoordinator.shared.registerActivePlayer(player)

        #expect(QuranPlayerCoordinator.shared.activePlayer === player)
        #expect(QuranPlayerCoordinator.shared.nowPlaying?.verseNumber == 5)
    }
}
