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
    public let verseNumber: Int?   // nil until timing resolves; 0 = basmala
}

@Published public private(set) var nowPlaying: NowPlaying?
```

Deliberately minimal — chapter and verse only. It exists so views can follow playback without
holding a player. Anything larger becomes a mirror that drifts.

### Push, not subscribe

The player pushes its verse to the coordinator:

```swift
public func playerDidUpdateVerse(_ player: QuranPlayerViewModel, chapter: Int, verse: Int?)
```

`QuranPlayerViewModel` updates `currentVerseNumber` in exactly one place
(`QuranPlayerViewModel.swift:273`) and calls this alongside it.

This is chosen over a Combine subscription for two reasons. It removes subscription lifecycle
entirely (no re-subscribing when `activePlayer` swaps, no cancellable bookkeeping). And it is
testable: `currentVerseNumber` and `playbackState` are `@Published public private(set)`, which
`@testable` cannot bypass, so a test can never drive a real player's published state. A
coordinator that observed the player could not be unit-tested without widening those setters
(exposing mutability publicly) or adding a test-only method (an anti-pattern). Pushing keeps the
production path and the test path identical.

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
pass a binding — a silent behavior change. Instead the new path is scoped:

- **Host passed a `highlightedVerse` binding** → the binding wins, exactly as today.
  `VerseByVerseDemo` is unchanged; zero regression risk.
- **No binding** → the coordinator drives following. `MushafReaderDemo` ("Read the Mushaf")
  gains automatic recitation-following.

This keeps the new capability strictly additive.

## Edge cases

- **Re-registering the same player must not pause it.** Guard `_activePlayer !== player` before
  pausing, or a player pauses itself on its second `play()`.
- **Stale push.** `playerDidUpdateVerse` ignores any player that is not `_activePlayer`, so a
  late tick from the outgoing player cannot move the highlight.
- **Basmala (verse 0)** keeps current semantics: navigate to it, do not highlight it.
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
- `MushafView.ViewModel.followVerse` — already covered by `MushafViewFollowVerseTests`

`QuranPlayerViewModel.init` is trivial (no `AVPlayer`, no I/O), so real instances are cheap to
construct in tests.

**Not unit-testable — verify by running, and say so rather than claiming coverage:**

- the actual audio pause on swap (`pause()` no-ops on an unconfigured player, so a test cannot
  observe it)
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
