# Unify Quran Playback Behind The Coordinator — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `QuranPlayerCoordinator` the single source of truth for what is playing, so remote commands, the menu-bar popover, and `MushafView` all follow the audible player.

**Architecture:** Players self-register with the coordinator when playback starts; registering pauses the outgoing player. The active player *pushes* its verse to the coordinator, which republishes a tiny `NowPlaying` projection. `MushafView` observes that projection instead of owning a player. Default lock-screen commands resolve `activePlayer` at invocation time instead of capturing a player.

**Tech Stack:** Swift 6, SwiftUI, Combine, AVFoundation, MediaPlayer, swift-testing (`@Test`/`#expect`), realm-swift 20.x.

**Spec:** `docs/superpowers/specs/2026-07-16-unify-quran-player-design.md`

## Global Constraints

- **Additive only.** No existing public symbol may be removed or have its signature changed. Library is tagged 1.0.4; this ships as 1.1.0.
- `QuranPlayerCoordinator`, `QuranPlayerViewModel`, `BackgroundPlaybackHelper`, `LockScreenMetadataManager` are all `@MainActor`. Tests touching them must be `@MainActor`.
- The contract "apps may call `LockScreenMetadataManager.shared.setupRemoteCommands(...)` at launch to replace the defaults" must keep working. Do not remove the `hasRegisteredCommands()` check.
- Do **not** reinstate end-of-surah auto-advance (see spec, "What removing MushafView's player deletes").
- `currentVerseNumber` and `playbackState` are `@Published public private(set)`. Do **not** widen these setters and do **not** add test-only mutators.

### Build/test commands

Run tests:
```bash
xcodebuild test -scheme MushafImad \
  -destination 'platform=iOS Simulator,id=68F46D53-9452-4E1C-99DF-0D7DC07FCDA7' \
  -only-testing:MushafImadTests/QuranPlayerCoordinatorTests 2>&1 \
  | grep -E "error:|✔ Test |✘ Test |Test run with"
```

Build the Example app:
```bash
xcodebuild build -project Example/Example.xcodeproj -scheme Example \
  -destination 'platform=iOS Simulator,id=68F46D53-9452-4E1C-99DF-0D7DC07FCDA7' \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" 2>&1 \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

**Gotchas:**
- The SwiftPM test target is named `MushafImadTests` even though the directory is `Tests/MushafImadSPMTests`. `-only-testing:MushafImadSPMTests/...` fails with "isn't a member of the specified test plan".
- `-only-testing:` only matches tests inside a suite type. `TafseerTests.swift` holds free `@Test` functions, so filtering by it silently runs **0 tests and reports TEST SUCCEEDED**. Always check the `Test run with N tests` line.
- If any device id is stale, list options with `xcrun simctl list devices available | grep iPhone`.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Sources/MushafImad/AudioPlayer/Services/QuranPlayerCoordinator.swift` | Single source of truth: active player + `NowPlaying` projection | Modify |
| `Sources/MushafImad/AudioPlayer/ViewModels/QuranPlayerViewModel.swift` | Self-register on play; push verse changes | Modify (`:35`, `:306`) |
| `Sources/MushafImad/AudioPlayer/Services/BackgroundPlaybackHelper.swift` | Late-bound default remote commands | Modify (`:37-49`) |
| `Sources/MushafImad/MushafView.swift` | Follow `nowPlaying` instead of owning a player | Modify (`:77`, `:194-217`, `:245-260`) |
| `Tests/MushafImadSPMTests/QuranPlayerCoordinatorTests.swift` | Coordinator behaviour | Modify (extend existing suite) |

---

### Task 1: Coordinator — `NowPlaying` projection and exclusive registration

**Files:**
- Modify: `Sources/MushafImad/AudioPlayer/Services/QuranPlayerCoordinator.swift`
- Test: `Tests/MushafImadSPMTests/QuranPlayerCoordinatorTests.swift` (extend; do not recreate)

**Interfaces:**
- Consumes: `QuranPlayerViewModel` (existing; `init(baseURL:chapterNumber:chapterName:reciterName:)` is trivial — no `AVPlayer`, no I/O — so real instances are cheap in tests). `QuranPlayerViewModel.pause()`.
- Produces:
  - `QuranPlayerCoordinator.NowPlaying` — `struct { let chapterNumber: Int; let verseNumber: Int }`, `Equatable, Sendable`, memberwise `public init`.
  - `QuranPlayerCoordinator.nowPlaying: NowPlaying?` — computed, `nil` when nothing is playing or the active player died.
  - `QuranPlayerCoordinator.playerDidUpdateVerse(_ player: QuranPlayerViewModel, chapter: Int, verse: Int?)`
  - Existing `activePlayer`, `hasActivePlayer`, `registerActivePlayer(_:)`, `unregisterActivePlayer(_:)` keep their signatures.

**Context you need:** The existing suite already covers `registerReplacesExistingPlayer`, `unregisterIgnoresMismatchedInstance`, and `activePlayerBecomesNilWhenOwnerIsDeallocated`. Its `init()` resets the shared singleton before each test. Keep that pattern; add to it.

- [ ] **Step 1: Mark the existing suite serialized**

The suite mutates a singleton. Its tests are currently synchronous so they do not interleave, but the tests added below must not race. At the top of `Tests/MushafImadSPMTests/QuranPlayerCoordinatorTests.swift`, change:

```swift
@MainActor
struct QuranPlayerCoordinatorTests {
```

to:

```swift
@Suite(.serialized)
@MainActor
struct QuranPlayerCoordinatorTests {
```

- [ ] **Step 2: Write the failing tests**

Append inside `QuranPlayerCoordinatorTests`, before the closing brace:

```swift
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
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test -scheme MushafImad \
  -destination 'platform=iOS Simulator,id=68F46D53-9452-4E1C-99DF-0D7DC07FCDA7' \
  -only-testing:MushafImadTests/QuranPlayerCoordinatorTests 2>&1 \
  | grep -E "error:|✔ Test |✘ Test |Test run with"
```

Expected: compile errors — `type 'QuranPlayerCoordinator' has no member 'NowPlaying'` and `value of type 'QuranPlayerCoordinator' has no member 'nowPlaying'` / `'playerDidUpdateVerse'`. That is the correct RED: the feature is missing.

- [ ] **Step 4: Implement**

Replace the body of `Sources/MushafImad/AudioPlayer/Services/QuranPlayerCoordinator.swift` between `public final class QuranPlayerCoordinator: ObservableObject {` and its closing brace with:

```swift
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

    /// Call when a player view appears and becomes the primary playback surface.
    /// Playback is exclusive: the outgoing player is paused.
    public func registerActivePlayer(_ player: QuranPlayerViewModel) {
        guard _activePlayer !== player else { return }
        objectWillChange.send()
        _activePlayer?.pause()
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
```

- [ ] **Step 5: Run tests to verify they pass**

Same command as Step 3. Expected: `Test run with 18 tests in 1 suite passed` (9 pre-existing + 9 new). Check the count, not just the word "passed": a filter that matches nothing reports success over zero tests.

- [ ] **Step 6: Commit**

```bash
git add Sources/MushafImad/AudioPlayer/Services/QuranPlayerCoordinator.swift \
        Tests/MushafImadSPMTests/QuranPlayerCoordinatorTests.swift
git commit -m "feat: publish a now-playing projection from the coordinator

Adds NowPlaying (chapter + verse) so views can follow playback without
holding a player, and makes registration exclusive: the outgoing player is
paused, and re-registering the active player is a no-op so a player never
pauses itself on a second play().

nowPlaying is computed over the weak active player because deallocation
fires no notification; a stored value would strand a highlight on a dead
player. Pushes from a player that is no longer active are ignored."
```

---

### Task 2: Player self-registers and pushes its verse

**Files:**
- Modify: `Sources/MushafImad/AudioPlayer/ViewModels/QuranPlayerViewModel.swift` (`:35` didSet, `:306` play())

**Interfaces:**
- Consumes: `QuranPlayerCoordinator.shared.registerActivePlayer(_:)`, `QuranPlayerCoordinator.shared.playerDidUpdateVerse(_:chapter:verse:)` (Task 1).
- Produces: no new public symbols. Behaviour only: any player that starts playing becomes the active player, and its verse changes reach the coordinator.

**Context you need:** `currentVerseNumber` (`:35`) is the single place the playing verse changes. `updateCurrentVerse()` (`:260`) sets it during playback; `stop()` (`:189`) sets it to `nil`. Hanging the push off `didSet` therefore covers playing, seeking and stopping with one hook — do not add pushes at call sites.

**Correction (applied after review).** This section originally claimed the task had no unit test, because `currentVerseNumber` is `@Published public private(set)`. That was wrong: the public `setPreviewVerse(_:)` assigns it and the public `stop()` nils it, both with no `AVPlayer` and no I/O, so the push path is testable through the real public API. The wiring is covered in `QuranPlayerCoordinatorTests`. Only registration on a real `play()` needs the simulator (Task 5).

- [ ] **Step 1: Push verse changes from `didSet`**

At `Sources/MushafImad/AudioPlayer/ViewModels/QuranPlayerViewModel.swift:35`, change:

```swift
    @Published public private(set) var currentVerseNumber: Int? = nil
```

to:

```swift
    @Published public private(set) var currentVerseNumber: Int? = nil {
        didSet {
            guard currentVerseNumber != oldValue else { return }
            QuranPlayerCoordinator.shared.playerDidUpdateVerse(
                self, chapter: chapterNumber, verse: currentVerseNumber
            )
        }
    }
```

- [ ] **Step 2: Add the registration helper**

Immediately above `private func ensureBackgroundSupport()` (around `:279`), add:

```swift
    /// A player that starts playing becomes the active one. Doing this here rather than in a
    /// view means a host cannot forget to register (which is how VerseByVerseDemo's remote
    /// commands went dead).
    ///
    /// Registration clears the coordinator's projection, so push current state straight after:
    /// `didSet` fires only on *change*, and a player resuming on the verse it was already on
    /// reassigns nothing. Without this push the highlight stays blank until the next verse.
    /// The push is a pure projection write, so doing it redundantly is harmless.
    private func becomeActivePlayer() {
        QuranPlayerCoordinator.shared.registerActivePlayer(self)
        QuranPlayerCoordinator.shared.playerDidUpdateVerse(
            self, chapter: chapterNumber, verse: currentVerseNumber
        )
    }
```

- [ ] **Step 3: Register from `play()` only**

**Correction (applied after review).** This step originally also called `becomeActivePlayer()` from `startIfNeeded(autoPlay:)`. That was wrong: `startIfNeeded` runs from `QuranPlayer.swift:73`'s `.task` on appear and from `seekToVerse` with `autoPlay: false`, so a player that never plays would seize the slot and silently pause the one that *is* playing — contradicting this task's own premise that a player which **starts playing** becomes active.

Register from `play()` only. Insert `becomeActivePlayer()` as its first line:

```swift
    public func play() {
        becomeActivePlayer()

        guard let player else {
            preparePlayer(autoPlay: true)
            return
        }
```

This is sufficient: every real start funnels through `play()`. The `.idle`/`.failed` path goes `preparePlayer(autoPlay:)` → async load → `observeStatus` (`:567-568`) → `play()` when `shouldAutoStart`; the `.paused`/`.ready`/`.finished` path calls `play()` directly when `autoPlay`. So `autoPlay: false` never registers, and nothing that plays is missed.

- [ ] **Step 4: Verify nothing regressed**

```bash
xcodebuild test -scheme MushafImad \
  -destination 'platform=iOS Simulator,id=68F46D53-9452-4E1C-99DF-0D7DC07FCDA7' 2>&1 \
  | grep -E "error:|Suite .* (passed|failed)|Test run with"
```

Expected: `QuranPlayerCoordinatorTests`, `MushafViewFollowVerseTests`, `ReciterDataProviderTests`, `LRUCacheTests`, `ChaptersDataCacheTests` all pass. `FallbackGazeEstimatorTests`, `GazeToVerseMapperTests` and one `ReadingProgressTrackerTests` case fail — these are **pre-existing** eye-tracking failures unrelated to this work. Do not fix them here.

- [ ] **Step 5: Commit**

```bash
git add Sources/MushafImad/AudioPlayer/ViewModels/QuranPlayerViewModel.swift
git commit -m "feat: players self-register and push their verse to the coordinator

Registration no longer depends on a view remembering to call
registerActivePlayer, which is why VerseByVerseDemo's remote commands
never worked. The verse push hangs off currentVerseNumber's didSet, the
single place the playing verse changes; stop() already nils it, so the
highlight clears with no separate stop hook."
```

---

### Task 3: Late-bind the default remote commands

**Files:**
- Modify: `Sources/MushafImad/AudioPlayer/Services/BackgroundPlaybackHelper.swift:37-49`

**Interfaces:**
- Consumes: `QuranPlayerCoordinator.shared.activePlayer` (pre-existing).
- Produces: no new symbols.

**Context you need:** This is the lock-screen bug. `attach(to:)` registers defaults only `if !LockScreenMetadataManager.shared.hasRegisteredCommands()`, and captures `[weak player]`. `hasRegisteredCommands()` reads the *global* `MPRemoteCommandCenter` enabled flags and `detach()` never clears them, so the first player to play owns the lock screen forever; once it deallocates the handlers become dead no-ops nothing can reclaim. Resolving `activePlayer` at invocation time fixes it without touching the registration guard.

`BackgroundPlaybackHelper` is `@MainActor`, and `RemoteCommandConfig`'s closures are non-`Sendable` `(() -> Void)?`, so a closure literal written here inherits main-actor isolation — call the player directly, exactly as the current code does. Do not wrap in `Task`.

This mirrors what `Example/Example/ContentView_iOS.swift:301` already does; keep the two consistent.

- [ ] **Step 1: Replace the captured player with a coordinator lookup**

In `attach(to:)`, change:

```swift
    if !LockScreenMetadataManager.shared.hasRegisteredCommands() {
      LockScreenMetadataManager.shared.setupRemoteCommands(
        .init(
          onPlayPause: { [weak player] in player?.togglePlayback() },
          onSkipForward: { [weak player] in _ = player?.seekToNextVerse() },
          onSkipBackward: { [weak player] in _ = player?.seekToPreviousVerse() }
        )
      )
    }
```

to:

```swift
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
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild build -project Example/Example.xcodeproj -scheme Example \
  -destination 'platform=iOS Simulator,id=68F46D53-9452-4E1C-99DF-0D7DC07FCDA7' \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" 2>&1 \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`. If the compiler complains about main-actor isolation in the closures, do **not** widen isolation on `RemoteCommandConfig`; wrap each body in `Task { @MainActor in ... }` as `ContentView_iOS.swift:301` does, and note it for review.

- [ ] **Step 3: Commit**

```bash
git add Sources/MushafImad/AudioPlayer/Services/BackgroundPlaybackHelper.swift
git commit -m "fix: resolve the active player when a remote command fires

The default handlers captured [weak player] at attach time, while the
registration guard only lets the first player ever register and detach()
never clears MPRemoteCommandCenter. So the first player owned the lock
screen for the process lifetime and, once deallocated, left dead no-op
handlers no later player could reclaim.

Resolving activePlayer at invocation time matches the pattern the Example
app already uses and leaves the app-override contract untouched."
```

---

### Task 4: `MushafView` follows `nowPlaying`

**Files:**
- Modify: `Sources/MushafImad/MushafView.swift` (`:77`, `:194-217`, `:245-260`)

**Interfaces:**
- Consumes: `QuranPlayerCoordinator.shared.nowPlaying` (Task 1); `MushafView.ViewModel.followVerse(_:)` (already exists, covered by `MushafViewFollowVerseTests`); `RealmService.shared.getVerse(chapterNumber:verseNumber:)`.
- Produces: no new public symbols. `MushafView` no longer owns a `QuranPlayerViewModel`.

**Context you need:** Read the spec section "What removing MushafView's player deletes" before starting. Three things go together and it is easy to delete one and orphan another:

1. `@StateObject private var playerViewModel` (`:77`).
2. `.onChange(of: playerViewModel.playbackState)` (`:194-217`) — including the `.finished` auto-advance branch, which is **not** reinstated.
3. `.onChange(of: playerViewModel.currentVerseNumber)` (`:245-256`) — replaced by an equivalent handler on `nowPlaying`.
4. `@EnvironmentObject private var reciterService` (`:79`) — read only by the branch in (2).

Keep `@State private var playingVerse` (`:83`) and the precedence chain at `:337-339`. Keep the `highlightedVerseBinding` handler added in `3fdb7ac`.

- [ ] **Step 1: Swap the player for the coordinator**

At `:77`, replace:

```swift
    @StateObject private var playerViewModel = QuranPlayerViewModel()
```

with:

```swift
    @ObservedObject private var playerCoordinator = QuranPlayerCoordinator.shared
```

- [ ] **Step 2: Delete both player-driven handlers**

Delete the entire `.onChange(of: playerViewModel.playbackState) { ... }` modifier (`:194-217`, the `switch` with `.idle` and `.finished` cases) and the entire `.onChange(of: playerViewModel.currentVerseNumber) { ... }` modifier (`:245-256`).

Do not preserve the `.finished` chapter auto-advance. It cannot fire today, and re-pointing it at the active player would turn a dead branch into a live behaviour that starts audio on its own — out of scope per the spec.

Then delete the now-dead environment object at `:79`:

```swift
    @EnvironmentObject private var reciterService: ReciterService
```

`reciterService` is read only at `:200-201`, inside the branch you just deleted, and `MushafView` presents neither `PlayerViewUI` nor `QuranPlayer`. Leaving it would keep a dependency the view no longer has — and because SwiftUI only traps on *access*, an unread `@EnvironmentObject` is a latent crash for any host that does not inject one. Removing it relaxes a requirement, so it cannot break a host: `ReciterService` is still injected at the app root (README:150) for `PlayerViewUI`, which does read it.

If the compiler reports `reciterService` used somewhere this plan did not anticipate, keep the property and note it for review rather than chasing the reference.

- [ ] **Step 3: Follow the coordinator instead**

In the same modifier chain, immediately above the existing `.onChange(of: highlightedVerseBinding?.wrappedValue?.page1441?.number)` handler, add:

**Correction (applied after review).** The guard below originally tested `highlightedVerseBinding == nil` alone. That was wrong: `MushafView`'s *static* init (`MushafView(highlightedVerse: someVerse)`) leaves the binding nil, so the guard passed for a host that had supplied its own verse — playback overrode it and popped it back at every basmala. Both ownership forms must be excluded. The handler body also had to be extracted into a private `followNowPlaying(_:)` and seeded from the `.task` *after* `initializePageView`, which sets `scrollPosition` unconditionally and would otherwise clobber the seed.

```swift
        // Follow playback only when the host owns no highlight of its own — neither a binding
        // nor a static verse. Both stay authoritative exactly as before.
        .onChange(of: playerCoordinator.nowPlaying) { _, nowPlaying in
            guard highlightedVerseBinding == nil, staticHighlightedVerse == nil else { return }
            guard let nowPlaying else { playingVerse = nil; return }
            let isOpeningBasmala = nowPlaying.verseNumber < 1
            guard let verse = RealmService.shared.getVerse(
                chapterNumber: nowPlaying.chapterNumber,
                verseNumber: max(nowPlaying.verseNumber, 1)
            ) else { return }
            playingVerse = isOpeningBasmala ? nil : verse
            withAnimation { viewModel.followVerse(verse) }
        }
```

- [ ] **Step 4: Verify it builds and tests still pass**

```bash
xcodebuild build -project Example/Example.xcodeproj -scheme Example \
  -destination 'platform=iOS Simulator,id=68F46D53-9452-4E1C-99DF-0D7DC07FCDA7' \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" 2>&1 \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`.

Then run the full suite and confirm only the pre-existing eye-tracking failures remain (see Task 2, Step 4).

- [ ] **Step 5: Commit**

```bash
git add Sources/MushafImad/MushafView.swift
git commit -m "fix: MushafView follows the coordinator's now-playing verse (#3)

MushafView owned a private @StateObject player that nothing could start:
it is private so no host could reach it, and the only startIfNeeded call
sat in the .finished branch, which needs playback that can never begin.
Both of its handlers were therefore dead.

It now observes the coordinator's now-playing projection, so it follows
whatever is audible without the host wiring anything. A host-supplied
highlightedVerse binding still wins, so existing integrations are
unchanged.

The unreachable end-of-surah auto-advance is dropped rather than
re-pointed at the active player: that would convert dead code into a live
behaviour that starts audio and moves the reader on its own."
```

---

### Task 5: Verify on the simulator and record what was checked

**Files:**
- Create: `docs/superpowers/plans/2026-07-16-unify-quran-player-verification.md`

**Interfaces:**
- Consumes: everything from Tasks 1-4.
- Produces: a written record of what was observed running, and what was not.

**Context you need:** Three behaviours in this change cannot be unit-tested and must be observed: the audio pause on swap (`pause()` no-ops on an unconfigured player so no test can see it), lock-screen late binding (global `MPRemoteCommandCenter`), and the page turn. Synthetic gestures via `cliclick` proved unable to dismiss SwiftUI sheets or drive `TabView` paging in this app, so these are **manual** checks. Report honestly; do not mark unobserved items as passing.

Note: a second simulator (iPhone 17 Pro Max) may be booted with an overlapping window and can silently steal clicks. Check with `xcrun simctl list devices booted`.

- [ ] **Step 1: Launch the Example app**

```bash
xcrun simctl boot 68F46D53-9452-4E1C-99DF-0D7DC07FCDA7 2>/dev/null; open -a Simulator
xcrun simctl install 68F46D53-9452-4E1C-99DF-0D7DC07FCDA7 \
  ~/Library/Developer/Xcode/DerivedData/Example-*/Build/Products/Debug-iphonesimulator/Example.app
xcrun simctl launch 68F46D53-9452-4E1C-99DF-0D7DC07FCDA7 com.qraiqe.mushaf.imad.Example
```

- [ ] **Step 2: Check each behaviour by hand and record the result**

Drive these manually in the Simulator window:

1. **Reader follows recitation (the defect).** Open "Read the Mushaf" (no binding — the coordinator path). Start playback from "Audio Player UI" in another screen, return to the reader. Expect: the highlight tracks the recited verse and the page turns at a page boundary. Use Al-Baqarah — Al-Fātiḥah is a single page and can never show a page turn.
2. **Exclusive playback.** Start "Audio Player UI", then start "Verse by Verse Playback". Expect: only one recitation is audible.
3. **Lock screen survives a player swap.** Play in one demo, background the app, use the lock-screen/Control-Centre controls. Return, open the other demo, play, background again, use the controls. Expect: the controls drive the audible player both times. This is the bug that previously died permanently.
4. **No regression for binding hosts.** "Verse by Verse Playback" long-press → play. Expect: identical behaviour to before this change.

- [ ] **Step 3: Write the verification record**

Create `docs/superpowers/plans/2026-07-16-unify-quran-player-verification.md` with one line per check: what was done, what was observed, and PASS/FAIL. For anything not observed, write "not verified" and why — do not infer a pass from the unit tests.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/2026-07-16-unify-quran-player-verification.md
git commit -m "docs: record manual verification of the unified player"
```

---

## Done when

- All 23 `QuranPlayerCoordinatorTests` pass (9 pre-existing + 9 from Task 1 + 5 covering Task 2's push path), and `MushafViewFollowVerseTests` / `ReciterDataProviderTests` still pass.
- The Example app builds and runs.
- The four manual checks in Task 5 are recorded with honest results.
- Only the 11 pre-existing eye-tracking failures remain in the suite.
- No public symbol removed or changed (`git diff main...HEAD -- Sources/` shows only additions to public API).
