# Ramadan Impact - Project Board 🌙

This document serves as the central hub for our campaign tasks. You can use this to create a GitHub Project implementation or just track it here.

## 📌 Board Columns

### 1. 💡 Triage & Ideas
*New suggestions that need discussion or refinement.*
- [ ] **Feature:** "Verse of the Day" Widget for iOS.
- [ ] **Feature:** macOS Menu Bar App for quick playback control.
- [ ] **Data:** Import Tafseer data (Tafseer Al-Jalalayn or similar).

### 2. 📋 To Do (Ready for Dev)
*Tasks that are well-defined and ready to be assigned.*

#### 🆕 Good First Issues (Beginner Friendly)
1.  **[UI] Fix Dark Mode Contrast in Settings**
    *   *Context:* Some settings text might be hard to read in `.night` theme.
    *   *Task:* Audit `MushafView` settings sheet and ensure `foregroundStyle` adapts to color scheme.
2.  **[Docs] Add DocC Comments to `ReciterService`**
    *   *Context:* Public properties like `reciterName` are undocumented.
    *   *Task:* Add `///` comments explaining what each property does.
3.  **[Refactor] Move Reciter IDs to JSON**
    *   *Context:* `ReciterService.swift` has a hardcoded array `[1, 5, 9...]`.
    *   *Task:* Move this list to a `reciters_manifest.json` file in Resources and load it dynamically.

#### 🚀 Features (Intermediate/Advanced)
4.  **[Audio] Implement Background Audio & Lock Screen Controls**
    *   *Context:* Currently, audio stops when the app is backgrounded.
    *   *Task:* Configure `AVAudioSession` category to `.playback` and implement `MPNowPlayingInfoCenter` to show Reciter/Surah name on Lock Screen.
    *   *See:* `QuranPlayerViewModel.swift`.
5.  **[Perf] Implement LRU Cache for `QuranDataCacheService`**
    *   *Context:* The cache grows indefinitely as the user scrolls.
    *   *Task:* Limit `cachedVerses` to 50 pages. Evict the least recently used pages when the limit is reached.
6.  **[Search] Build Search UI**
    *   *Context:* Backend search exists, UI is missing.
    *   *Task:* Create a SwiftUI view to search for Surahs (by name) and Verses (by text).

### 3. 🏗 In Progress
*Tasks currently being worked on.*
- [x] Create `CONTRIBUTING.md` (Completed)
- [x] Create `ROADMAP.md` (Completed)

### 4. ✅ Done
*Completed tasks.*
- [x] Initial Repository audit.

---

## 📝 GitHub Issue Templates

Copy these exactly to populate your "To Do" column.

### Issue: Background Audio Support
**Title:** `[Feat] Enable Background Audio & Lock Screen Controls`
**Labels:** `enhancement`, `priority: high`, `Ramadan-Impact`
**Body:**
```markdown
**Context:**
Users cannot listen to the Quran while using other apps or when the screen is locked. This is a critical feature for any audio-focused app.

**Technical Details:**
1.  **AVAudioSession:** In `QuranPlayerViewModel`, configure the session:
    ```swift
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    try? AVAudioSession.sharedInstance().setActive(true)
    ```
2.  **Background Modes:** Ensure the Xcode Project Capabilities has "Audio, AirPlay, and Picture in Picture" enabled.
3.  **Lock Screen:** Use `MPNowPlayingInfoCenter.default()` to update the title, artist (Reciter), and artwork.
4.  **Remote Commands:** Handle Play/Pause/Next track events from the Control Center using `MPRemoteCommandCenter`.

**Acceptance Criteria:**
- Audio continues playing when the app is minimized.
- Lock screen shows "Surah Al-Fatiha" and the Reciter's name.
- Play/Pause buttons on lock screen work.
```

### Issue: LRU Cache Eviction
**Title:** `[Perf] Implement LRU Eviction Policy in QuranDataCacheService`
**Labels:** `optimization`, `swift`, `Ramadan-Impact`
**Body:**
```markdown
**Context:**
`QuranDataCacheService` currently stores every visited page in `cachedVerses` dictionary. If a user reads the entire Quran, this could consume significant memory (604 pages + metadata).

**Task:**
Refactor `cachedVerses` to use an LRU properties or simple count check.
1.  Set a limit (e.g., `MAX_PAGES = 50`).
2.  When adding a new page, if count > MAX, remove the oldest accessed page.
3.  You might need to track "access time" or use an `NSCache` (though `NSCache` is objective-c based, a native Swift wrapper is often better for Structs).

**File:** `Sources/MushafImad/Core/Services/QuranDataCacheService.swift`
```

### Issue: Dynamic Reciter Configuration
**Title:** `[Refactor] Load Reciter ID List from JSON`
**Labels:** `good first issue`, `refactoring`, `Ramadan-Impact`
**Body:**
```markdown
**Context:**
`ReciterService.swift` (Line 73) has a hardcoded array:
`let reciterIds = [1, 5, 9, 10, ...]`

**Task:**
1.  Create a file `Reciters.json` in `Sources/Resources`.
2.  Structure it as `{"available_ids": [1, 5, 9, ...]}`.
3.  Update `ReciterService.loadAvailableRecitersSync()` to read this file instead of using the hardcoded array.
4.  This allows us to add new reciters by just updating a JSON file.
```
