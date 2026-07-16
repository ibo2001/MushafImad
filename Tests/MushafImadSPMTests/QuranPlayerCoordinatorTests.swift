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

    // MARK: - QuranPlayerViewModel wiring (didSet -> coordinator)

    /// setPreviewVerse is the public, side-effect-free way to move currentVerseNumber. This
    /// exercises the production didSet hook end-to-end, not the coordinator API directly.
    @Test func setPreviewVerseOnActivePlayerPublishesNowPlaying() {
        let player = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(player)

        player.setPreviewVerse(5)

        #expect(QuranPlayerCoordinator.shared.nowPlaying
                == QuranPlayerCoordinator.NowPlaying(chapterNumber: 2, verseNumber: 5))
    }

    /// stop() assigns currentVerseNumber = nil, which must clear the projection through the
    /// same didSet path used for real verse changes.
    @Test func stopOnActivePlayerClearsNowPlaying() {
        let player = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(player)
        player.setPreviewVerse(5)
        #expect(QuranPlayerCoordinator.shared.nowPlaying != nil)

        player.stop()

        #expect(QuranPlayerCoordinator.shared.nowPlaying == nil)
    }

    /// A player that never became active must not be able to move the highlight, even though
    /// its own currentVerseNumber's didSet still fires locally.
    @Test func setPreviewVerseOnInactivePlayerDoesNotDisturbActiveProjection() {
        let active = configuredPlayer(chapter: 2)
        let bystander = configuredPlayer(chapter: 3)
        QuranPlayerCoordinator.shared.registerActivePlayer(active)
        active.setPreviewVerse(5)

        bystander.setPreviewVerse(99)

        #expect(QuranPlayerCoordinator.shared.nowPlaying
                == QuranPlayerCoordinator.NowPlaying(chapterNumber: 2, verseNumber: 5))
    }

    /// Regression test for the resume-gap bug: player A is mid-verse, loses the active slot to
    /// player B (which clears the projection), then regains the slot via play(). Without a
    /// republish inside becomeActivePlayer(), A's currentVerseNumber is unchanged so the
    /// didSet never fires, and the highlight stays blank until the verse advances. play() is
    /// used (not registerActivePlayer directly) because the republish lives in the view
    /// model's private becomeActivePlayer(), which play() invokes synchronously before it ever
    /// touches an AVPlayer.
    @Test func regainingActiveSlotRepublishesCurrentVerse() {
        let first = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(first)
        first.setPreviewVerse(5)
        #expect(QuranPlayerCoordinator.shared.nowPlaying?.verseNumber == 5)

        let second = configuredPlayer(chapter: 3)
        QuranPlayerCoordinator.shared.registerActivePlayer(second)
        #expect(QuranPlayerCoordinator.shared.nowPlaying == nil)

        first.play()

        #expect(QuranPlayerCoordinator.shared.activePlayer === first)
        #expect(QuranPlayerCoordinator.shared.nowPlaying
                == QuranPlayerCoordinator.NowPlaying(chapterNumber: 2, verseNumber: 5))
    }

    /// Regression test for the silent-steal bug: a player that merely appears (autoPlay: false,
    /// e.g. seekToVerse queuing a seek before the AVPlayer exists) must not seize the active
    /// slot and pause whoever is actually playing.
    @Test func startIfNeededWithoutAutoPlayDoesNotStealActiveSlot() {
        let activePlayer = configuredPlayer(chapter: 2)
        QuranPlayerCoordinator.shared.registerActivePlayer(activePlayer)

        let appearing = configuredPlayer(chapter: 3)
        appearing.startIfNeeded(autoPlay: false)

        #expect(QuranPlayerCoordinator.shared.activePlayer === activePlayer)
    }

    // MARK: - Exclusivity across async loading

    /// Writes a silent WAV and returns the directory to use as a player `baseURL`. The file is
    /// named `001.mp3` because that is the path `resolveAudioURLForPlayback()` builds for
    /// chapter 1; AVFoundation sniffs the container rather than trusting the extension, so this
    /// reaches `.readyToPlay` from disk with no network and no fixture to check in.
    private func makeSilentAudioDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sampleRate = 8000, channels = 1, bitsPerSample = 16
        let byteCount = sampleRate * channels * bitsPerSample / 8  // one second
        var wav = Data()
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { wav.append(contentsOf: $0) } }
        wav.append(contentsOf: Array("RIFF".utf8)); append32(UInt32(36 + byteCount))
        wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8)); append32(16); append16(1)
        append16(UInt16(channels)); append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * channels * bitsPerSample / 8))
        append16(UInt16(channels * bitsPerSample / 8)); append16(UInt16(bitsPerSample))
        wav.append(contentsOf: Array("data".utf8)); append32(UInt32(byteCount))
        wav.append(Data(count: byteCount))

        try wav.write(to: directory.appendingPathComponent("001.mp3"))
        return directory
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// The core exclusivity guarantee across an asynchronous load: player A taps play and starts
    /// loading, player B takes the slot while A is still `.loading`, and A's item then becomes
    /// ready. A must honour the hand-over and settle at `.ready` instead of firing its pending
    /// auto-start, which would re-register A and silently pause B — overriding the user's *later*
    /// choice. `pause()` cannot deliver this on its own: it no-ops unless the player is already
    /// `.playing`, and A is `.loading` with no AVPlayer at hand-over time, so the outgoing player
    /// sails straight past it. Only cancelling the deferred start does.
    @Test func registeringNewPlayerCancelsPendingAutoStartOfLoadingPlayer() async throws {
        let directory = try makeSilentAudioDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let loading = QuranPlayerViewModel(baseURL: directory, chapterNumber: 1, chapterName: "test")
        loading.play()
        #expect(QuranPlayerCoordinator.shared.activePlayer === loading)
        #expect(loading.playbackState == .loading)

        // `second` must be held in a local: a temporary would deallocate and hand the slot back
        // through the weak reference, passing for the wrong reason.
        let second = configuredPlayer(chapter: 3)
        QuranPlayerCoordinator.shared.registerActivePlayer(second)
        #expect(QuranPlayerCoordinator.shared.activePlayer === second)

        await waitUntil { loading.playbackState != .loading }

        #expect(loading.playbackState == .ready)
        #expect(QuranPlayerCoordinator.shared.activePlayer === second)
    }
}
