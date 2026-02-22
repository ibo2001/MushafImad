import Testing
@testable import MushafImad

// All tests run on the main actor because QuranPlayerCoordinator and
// QuranPlayerViewModel are both @MainActor-isolated.
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
}
