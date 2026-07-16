# Unify Quran playback behind the coordinator (defect #3)

**Date:** 2026-07-16
**Status:** Approved, ready for implementation planning
**Branch:** `fix/yahia-architecture-and-defect-repor`

## Problem

Playback is spread across independent `QuranPlayerViewModel` instances that do not know about
each other. Four are real; a fifth (`AudioPlayer/Views/QuranPlayer.swift:337`) is a `#Preview`.

| Instance | Registers with coordinator? |
|---|---|
| `MushafView.swift:77` (private `@StateObject`) | No — and nothing can start it |
| `PlayerViewUI.swift:12` | Yes (`:75` / `:78`) |
| `Example/ContentView_iOS.swift:388` (`VerseByVerseDemo`) | No |
| `Example/ContentView_macOS.swift:259` | No |

Four defects follow from this.

**1. Registration depends on a view remembering.** Only `PlayerViewUI` registers, so
`QuranPlayerCoordinator.shared.activePlayer` is stale or nil while another player is audibly
playing. Anything routed through the coordinator — the macOS menu-bar popover
(`MenuBarPlayerView.swift:20`), the Example's custom remote commands — then targets the wrong
player or none.

**2. The lock screen dies permanently.** `QuranPlayerViewModel:281` (`ensureBackgroundSupport`)
gives each player its own `BackgroundPlaybackHelper`. `attach` registers default remote commands
only `if !LockScreenMetadataManager.shared.hasRegisteredCommands()`, and captures the player
eagerly as `[weak player]`. `hasRegisteredCommands()` reads the *global*
`MPRemoteCommandCenter` enabled flags, and `detach()` never clears them — it only drops the
Combine subscriptions and nils its player reference.

So the first player to ever play owns the lock screen for the life of the process. When it
deallocates, its `[weak player]` handlers resolve to nil and the commands become dead no-ops
that no later player can reclaim, because the commands are still *enabled*. Lock-screen and
Bluetooth controls stop working and never recover.

**3. Two winner rules disagree.** The coordinator is last-registered-wins; remote commands are
first-attached-wins. They can point at different players simultaneously.

**4. Nothing pauses anything.** Two players can stream concurrently, overlapping recitation.

Separately, `MushafView`'s player is unreachable dead weight: it is `private`, so no host can
start it, and the only `startIfNeeded` call sits in the `.finished` branch
(`MushafView.swift:215`), which requires playback that can never begin. The verse action bar
offers only tafsir and close. This is why defect #1's page-following had to be re-wired onto the
`highlightedVerse` binding (commit `3fdb7ac`).

## Constraints

- **Additive only.** Tagged 1.0.4 and the README documents `QuranPlayerViewModel` as public API.
  Existing host code that constructs its own player must keep compiling and working. Ships 1.1.0.
- The Example app is the only known consumer, but the API stays conservative regardless.
- The documented contract "apps may call `LockScreenMetadataManager.shared.setupRemoteCommands`
  at launch to replace the defaults" must survive.

## Key insight

The Example's Custom Remote Commands demo (`ContentView_iOS.swift:301-357`) already registers
handlers that resolve `QuranPlayerCoordinator.shared.activePlayer` **at invocation time**:

```swift
config.onPlayPause = { QuranPlayerCoordinator.shared.activePlayer?.togglePlayback() }
```

Late binding is already the established idiom here. The library's own defaults are the
exception. Most of this design is making the library follow the pattern its own Example
demonstrates.

## Design

### Coordinator as the single source of truth

`QuranPlayerCoordinator` keeps its existing public surface (`activePlayer`, `hasActivePlayer`,
`registerActivePlayer`, `unregisterActivePlayer`) and gains one small published projection:

```swift
public struct NowPlaying: Equatable, Sendable {
    public let chapterNumber: Int
    public let verseNumber: Int     // 0 = basmala
}

public var nowPlaying: NowPlaying?   // nil when nothing is playing or no verse resolved
```

Deliberately minimal — chapter and verse only. It exists so views can follow playback without
holding a player. Anything larger becomes a mirror that drifts.

`verseNumber` is non-optional and the whole projection is optional, rather than an optional
verse inside a non-optional projection. A double optional would make "playing but no verse
resolved yet" and "not playing" two spellings of the same visual state, and every consumer would
have to unwrap twice to say the same thing. One optional, one meaning: `nil` means nothing to
follow.

`nowPlaying` is a computed property backed by `@Published private var storedNowPlaying`, so it
can return `nil` the moment the weak `_activePlayer` dies — a stored property could not, since
deallocation of a weak referent fires no notification.

### Push, not subscribe

The player pushes its verse to the coordinator:

```swift
public func playerDidUpdateVerse(_ player: QuranPlayerViewModel, chapter: Int, verse: Int?)
```

The push hangs off a `didSet` on `currentVerseNumber` rather than being sprinkled at call sites.
That property is the single place the playing verse changes, and it already covers stopping:
`stop()` sets `currentVerseNumber = nil` (`QuranPlayerViewModel.swift:189`), which pushes `nil`
and clears `nowPlaying` — reproducing the old `.idle → playingVerse = nil` behaviour with no
separate stop hook to keep in sync.

This is chosen over a Combine subscription because it removes subscription lifecycle entirely:
no re-subscribing when `activePlayer` swaps, no cancellable bookkeeping.

It is also directly testable. `currentVerseNumber` is `@Published public private(set)`, but the
public `setPreviewVerse(_:)` assigns it and the public `stop()` nils it, both without an
`AVPlayer` or any I/O — so the whole push path can be driven through the real public API, with
no widened setter and no test-only seam.

An earlier draft of this spec claimed the opposite — that no test could reach that state — and
used it to justify shipping the wiring untested. That was wrong, and it cost something concrete:
`registerActivePlayer` clears the projection, while `didSet` fires only on *change*, so a player
resuming on an unchanged verse republished nothing and left the highlight blank for the rest of
the ayah. The tests that premise excused are exactly the ones that catch it.

Auto-registration already requires the player to reference the coordinator, so this adds no new
coupling direction.

### The four changes (all additive)

1. **`QuranPlayerViewModel` self-registers on playback start.** No signature change; it simply
   stops depending on a view remembering. Fixes defect 1.
2. **`registerActivePlayer` pauses the outgoing player** and re-points the projection. Makes
   playback exclusive. Fixes defect 4.
3. **`BackgroundPlaybackHelper` default commands become late-bound** —
   `{ QuranPlayerCoordinator.shared.activePlayer?.togglePlayback() }` instead of `[weak player]`.
   The `hasRegisteredCommands()` check stays, preserving the app-override contract. Fixes
   defects 2 and 3: it no longer matters which player attached first, and a deallocated player
   cannot strand the commands.
4. **`MushafView` drops its private player** and observes `coordinator.nowPlaying`.

### What removing MushafView's player deletes

The private `@StateObject` is not the only thing that goes. Two attached handlers go with it,
and both are unreachable today:

- **The verse handler added in `3fdb7ac`.** That commit wired
  `.onChange(of: playerViewModel.currentVerseNumber)` and deliberately left it in place "so it
  works if the players are ever unified (defect #3)". This is that unification, and it arrives
  differently than assumed: `MushafView` ends up with no player at all, so the handler is
  replaced by an equivalent one on `coordinator.nowPlaying`. The `playingVerse` state and the
  basmala rule survive unchanged; only the source moves.
- **The `.finished` auto-advance branch** (`MushafView.swift:199`), which navigates to the next
  surah and starts playing it. It cannot fire today, because reaching `.finished` requires
  playback that can never begin.

Auto-advance is **not** reinstated on the coordinator path. Re-pointing it at the active player
would turn a dead branch into a live library behavior that silently starts audio and moves the
reader — a new feature, not a defect fix, and outside the additive-only remit. Hosts that want
it already do it themselves: the Example's Custom Remote Commands demo advances chapters in its
own `onNextTrack` (`ContentView_iOS.swift:305-323`). If the library should own auto-advance, it
belongs behind an explicit opt-in in its own change.

### Data flow

```
host taps play
  -> QuranPlayerViewModel.play()
  -> coordinator.registerActivePlayer(self)      // pauses previous, clears its projection
  -> player pushes playerDidUpdateVerse(...)     // on each verse change
  -> coordinator publishes nowPlaying
  -> MushafView resolves the verse via RealmService
  -> viewModel.followVerse(verse)                // page scrolls, highlight moves

lock screen / Bluetooth
  -> MPRemoteCommandCenter
  -> late-bound default handler
  -> coordinator.activePlayer                    // whatever is actually audible
```

### Highlight precedence

Today the chain is `playingVerse ?? highlightedVerseBinding ?? staticHighlightedVerse`
(`MushafView.swift:337-339`), and `playingVerse` is always nil, so the binding always wins.

Letting coordinator-driven `playingVerse` keep first place would start overriding hosts that
supply their own highlight — a silent behavior change. Instead the new path is scoped by asking
whether the host owns the highlight at all. `MushafView` has two mutually exclusive inits, and
**both** forms of ownership must be respected:

- **Host passed a `highlightedVerse` binding** → the binding wins, exactly as today.
  `VerseByVerseDemo` is unchanged; zero regression risk.
- **Host passed a static `highlightedVerse: Verse?`** → that verse wins, exactly as today.
- **Host passed no highlight at all** (`MushafView()` / `MushafView(initialPage:)`, which reach
  the static init with `highlightedVerse` defaulting to `nil`) → the coordinator drives
  following. `MushafReaderDemo` ("Read the Mushaf") gains automatic recitation-following.

So the guard is `highlightedVerseBinding == nil && staticHighlightedVerse == nil`, not the
binding alone.

An earlier draft of this section named only the binding case, and the plan turned that into a
`guard highlightedVerseBinding == nil` — which passes for the static init, since that init leaves
the binding nil. A static-highlight host would then have had its verse overridden during playback
and popped back at every basmala (`playingVerse` returns to nil there, and `staticHighlightedVerse`
is a `let` that can never be cleared). That is precisely the breakage the additive-only constraint
exists to prevent, and the enumeration above is what closes it.

This keeps the new capability strictly additive.

## Edge cases

- **Re-registering the same player must not pause it.** Guard `_activePlayer !== player` before
  pausing, or a player pauses itself on its second `play()`.
- **Stale push.** `playerDidUpdateVerse` ignores any player that is not `_activePlayer`, so a
  late tick from the outgoing player cannot move the highlight.
- **Basmala (verse 0)** keeps current semantics: navigate to it, do not highlight it.
- **Reader opened while playback is already running.** `.onChange` fires only on transitions, so
  the handler must also be seeded on appear — otherwise the most common path (start playback,
  navigate to the reader) shows no highlight until the next verse boundary. Both call the same
  private method so they cannot drift.
- **Active player deallocates.** The weak ref nils; `nowPlaying` must clear, or the highlight
  pins to a corpse.
- **Playback stops** (`.idle` / `.finished`) → clear `nowPlaying` → clear highlight, matching the
  existing `playbackState` handler.
- **Verse not found in Realm** → leave the highlight as-is rather than clearing it.
- `pause()` guards on `playbackState == .playing` and a non-nil `AVPlayer`
  (`QuranPlayerViewModel.swift:329`), so pausing a not-yet-playing previous player is a safe
  no-op.

## Testing

**Unit-testable (no simulator, no audio, no network):**

- register A then B → `activePlayer === B`
- re-registering A while A is active → no self-pause
- `unregisterActivePlayer` for a non-active player → no-op
- active player deallocates → `activePlayer` and `nowPlaying` both clear
- `playerDidUpdateVerse` from a non-active player → `nowPlaying` unchanged
- `nowPlaying` projection, including verse 0
- the player's push path, driven via the public `setPreviewVerse(_:)` / `stop()`: publish on
  change, clear on nil, ignore when not active, and republish on regaining the active slot
- `MushafView.ViewModel.followVerse` — already covered by `MushafViewFollowVerseTests`

`QuranPlayerViewModel.init` is trivial (no `AVPlayer`, no I/O), so real instances are cheap to
construct in tests.

**Not unit-testable — verify by running, and say so rather than claiming coverage:**

- the actual audio pause on swap (`pause()` no-ops on an unconfigured player, so a test cannot
  observe it)
- registration on a real `play()`, which needs an `AVPlayer` reaching `.playing`
- lock-screen late binding (global `MPRemoteCommandCenter`)
- the page turn during playback

## Out of scope

- Defects #9/#10 (main-thread blocking I/O in `AyahTimingService` / `getCurrentVerse`).
- The 11 pre-existing eye-tracking test failures.
- Removing the public `QuranPlayerViewModel.init` or introducing a shared singleton — both
  rejected by the additive-only constraint.
- Adding a play control to `MushafView`'s verse action bar.
- Reinstating end-of-surah auto-advance as a live library behavior (see above).

## Migration notes

None required. Every change is additive or internal:

- Hosts that construct their own player keep working and now get correct remote commands and
  automatic registration for free.
- Hosts that pass a `highlightedVerse` binding see identical behavior.
- Hosts that call `registerActivePlayer` manually keep working; it becomes redundant but
  harmless (guarded against self-pause).
- `MushafView` with no binding gains recitation-following — the only intended behavior change,
  and it is the reported defect.

The one removal is end-of-surah auto-advance inside `MushafView`. Because that branch is
unreachable today, no shipped behavior changes and no host can be depending on it.
