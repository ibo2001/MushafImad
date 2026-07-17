# Unified Quran Player — Manual Verification Record

**Date:** 2026-07-16
**Branch:** `fix/yahia-architecture-and-defect-repor`
**Device:** iPhone 17 Pro simulator, `68F46D53-9452-4E1C-99DF-0D7DC07FCDA7` (iOS 26.2)
**Build:** `xcodebuild build -project Example/Example.xcodeproj -scheme Example -destination 'platform=iOS Simulator,id=68F46D53-9452-4E1C-99DF-0D7DC07FCDA7' CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""` → `BUILD SUCCEEDED`
**App:** installed and launched successfully (`com.qraiqe.mushaf.imad.Example`), home screen ("MushafImad Examples") rendered correctly.

## Overall state — read this first

**None of the four target behaviors were directly observed end-to-end.** The app builds and
launches, and I confirmed that *some* playback genuinely starts and progresses (verse counter and
elapsed time advanced across two screenshots on the "Audio Player UI" screen). Beyond that single
data point, **all four checks below are NOT VERIFIED** — not because anything looked wrong, but
because I could not drive the required multi-screen navigation (open reader → background app →
return → swap demo → background again → lock-screen controls) through synthetic input in this
environment. I did not observe the reader highlight tracking, the page turn, the exclusive-pause
behavior, or any lock-screen/Control-Center interaction. Do not treat the code changes as proven
correct by this record — they are proven to **build** and the app is proven to **launch and play
something**, and that is genuinely as far as automation got.

This is an expected outcome per the task brief, which pre-warned that `cliclick` could not
dismiss SwiftUI sheets or drive `TabView` paging in this app. What's new in this session: it
*also* could not reliably hit the reader's/player's back-chevron button (see "Automation notes"
below), which blocked reaching the multi-screen scenarios needed for checks 1–3 at all. Check 4
(binding-host regression) requires a long-press gesture that was not attempted, again per the
brief's guidance to not spend many turns fighting `cliclick`.

All screenshots referenced below are at:
`/Users/qraiqe/Swift/MushafImad/.superpowers/sdd/task-5-screenshots/`
(git-ignored; copy them elsewhere if you need them to survive `git clean`).

---

## Check 1 — Reader follows recitation (the defect being fixed)

**Status: NOT VERIFIED**

**What I did:** Attempted to open "Read the Mushaf" and navigate to Al-Baqarah specifically (via
the Suras List, to get a multi-page sura where a page turn is observable), intending to then
background, start playback from "Audio Player UI", and return to watch the highlight/page follow
along.

**What I observed:** Tapping the "Read the Mushaf" row's approximate location instead landed on
"Suras List" (`02-tap-test.png`) due to imprecise coordinate calibration; after recalibrating
against the Simulator window's device-bezel offset, a corrected tap did open the Mushaf reader —
but on Sūrat Āli 'Imrān / page 50 (the default/last-read page), not Al-Fātiḥah or Al-Baqarah
(`03-mushaf-attempt.png`). The reader has a tap-anywhere-to-toggle-chrome gesture that intercepts
taps intended for the visible back button: two separate attempts to tap the back chevron
(`04-back-to-home.png` → `05-chrome-back.png`, and again `06-back-attempt2.png`) only toggled the
toolbar/chrome visibility rather than navigating back, even when the computed tap coordinates fell
well inside the button's visible circular background. I could not get past this screen to reach
Al-Baqarah, could not start playback from another screen and return, and therefore never observed
whether the highlight tracks the recited verse or whether the page turns at a boundary. The
"seed the highlight on appear while already playing" behavior was also not exercised.

**Why not verified:** Synthetic taps (`cliclick`) could not reliably actuate the reader's
back-navigation control — it either missed the button's real hit-target or lost the gesture race
to the reader's own tap-to-toggle-chrome recognizer. I did not find a coordinate that reliably hit
the button in three attempts, and the task brief caps automation-fighting at roughly 10 tool
calls, which I had used before shifting to other checks.

**What a human needs to do (≈2 minutes):**
1. Launch the Example app on `68F46D53-9452-4E1C-99DF-0D7DC07FCDA7` (or any simulator/device).
2. Tap "Read the Mushaf" → tap the menu/sura-list icon → select "2 - Al-Baqarah" (page 2).
3. Go back to the examples list (without closing the reader's audio), open "Audio Player UI",
   and start playback of a Baqarah verse (or use "Verse by Verse Playback" set to Al-Baqarah, if
   it supports sura selection — otherwise use whichever demo can target Al-Baqarah).
4. Return to the reader. Confirm: the highlighted verse updates as recitation proceeds, and the
   page flips forward when the recited verse crosses onto the next mushaf page.
5. Separately: with playback already running, open the reader fresh and confirm the current verse
   is highlighted immediately on appear (not only after the next verse boundary fires).

---

## Check 2 — Exclusive playback

**Status: NOT VERIFIED**

**What I did:** Opened "Audio Player UI" from the home screen (tap succeeded — `08-audio-player-ui.png`).
Confirmed playback was live: a second screenshot ~60 seconds later (`09-back-from-player.png`)
showed elapsed time advance from `00:00` to `00:21` and the verse label change from (implicit)
verse 1 to "Al-Fātiḥah : 4", i.e. real, running playback state — not a static mock. I then
attempted to navigate back to reach "Verse by Verse Playback" and start it as the second player,
to see whether the first player's UI reflected a pause.

**What I observed:** The back-chevron tap on the Audio Player screen did not navigate anywhere —
the screen and its advancing playback were unchanged in the follow-up screenshot. I was blocked
from reaching "Verse by Verse Playback" at all, so I never started a second player and never
observed whether the first one paused (visually) or whether only one recitation was audible.

**Why not verified:** Same back-navigation limitation as Check 1. Also, simulator audio is not
audible to me in this environment regardless — even if I had reached the second screen and
started playback there, I could not have confirmed "only one recitation is audible" by listening;
that half of this check requires a human's ears in any case.

**What a human needs to do (≈2 minutes):**
1. Open "Audio Player UI", start playback, confirm audio.
2. Go back, open "Verse by Verse Playback", start playback.
3. Confirm only the second recitation is audible, and that the first demo's UI (if still visible
   in a tab/stack) shows a paused state.

---

## Check 3 — Lock screen survives a player swap

**Status: NOT VERIFIED**

**What I did:** Not attempted. This check requires backgrounding the app and driving the
lock-screen/Control-Center transport controls, which needs either physical/simulated hardware
button presses and system-UI interaction well outside what `cliclick` can do reliably in this
app (per the brief, `cliclick` drags register as long-presses and could not drive comparable
system-level interactions), and it is gated on first completing Check 1/2's navigation, which was
already blocked.

**Why not verified:** Not attempted, given the navigation blocker above and the instruction to
cap automation attempts rather than fight the tooling.

**What a human needs to do (≈2 minutes):** This is the most important check to do by hand — it's
the one regression this change specifically targets ("previously died permanently after the first
player").
1. Open "Audio Player UI", start playback, background the app (swipe up / Cmd+Shift+H).
2. Open Control Center (or lock the simulator) and use the transport controls (play/pause,
   skip). Confirm they drive the audible Audio Player UI playback.
3. Return to the app, open "Verse by Verse Playback", start playback (this should register as
   the new active player and pause the first).
4. Background again, use the lock-screen/Control-Center controls again. Confirm they now drive
   Verse-by-Verse playback — not silently do nothing, and not still target the first player.

---

## Check 4 — No regression for binding hosts

**Status: NOT VERIFIED**

**What I did:** Not attempted. This requires a long-press gesture on "Verse by Verse Playback",
and I did not reach that screen (blocked by the same back-navigation issue), nor did I attempt a
`cliclick` long-press given the brief's explicit note that `cliclick` drags register as
long-presses in this app rather than the intended gesture.

**Why not verified:** Not attempted — blocked on navigation, and long-press synthesis is called
out in the brief as unreliable here.

**What a human needs to do (≈1 minute):**
1. Open "Verse by Verse Playback".
2. Long-press a verse to start playback from it.
3. Confirm behavior is unchanged from before this change: the verse highlights per the view's own
   binding, playback starts at the pressed verse, and there's no visible difference from prior
   released behavior.

---

## Automation notes (for whoever picks this up next)

- A second simulator (iPhone 17 Pro Max) was booted at the start of this session and was shut
  down before testing, per the brief's warning about it stealing clicks.
- Basic single-tap navigation on plain list rows (home screen → "Suras List", home screen →
  "Audio Player UI") worked fine once the Simulator-window-to-screen-point coordinate mapping was
  calibrated (the window reported by AppleScript includes a top device-bezel inset of roughly
  135pt that isn't proportional to the rest of the window — screenshots are the ground truth, not
  the raw window frame).
- The back-chevron button used throughout this app's demo screens (both the Mushaf reader and the
  Audio Player screen) could not be reliably actuated by `cliclick` taps in four attempts across
  two different screens, even at recalculated, verified-in-bounds coordinates. This is consistent
  with — and extends — the brief's pre-existing note that `cliclick` cannot dismiss sheets or
  drive `TabView` paging in this app. A human should expect plain taps to work but should not
  assume any scripted UI walkthrough of this app will work unattended.
- Screenshots are saved under `.superpowers/sdd/task-5-screenshots/` (git-ignored). Key ones:
  - `01-launch.png` — home screen.
  - `03-mushaf-attempt.png` — reader opened, but on the wrong page (Āli 'Imrān / page 50).
  - `08-audio-player-ui.png` / `09-back-from-player.png` — evidence of real, advancing playback
    (00:00→00:21, verse 1→4) that a back-tap could not escape from.
