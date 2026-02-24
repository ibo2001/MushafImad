# Roadmap for MushafImad 🚀

This document outlines the high-level goals and planned features for **MushafImad**. We welcome contributions that align with this roadmap, especially during the **Ramadan Impact** campaign.

## 📍 Phase 1: Foundation & Stability (Ramadan Impact Focus)
**Goal:** harden the core experience and ensure the codebase is robust for new contributors.

- [ ] **Test Coverage**:
    - [ ] Unit tests for `RealmService` (Chapter/Verse retrieval).
    - [ ] Unit tests for `ChaptersDataCache`.
    - [ ] UI Tests for `MushafView` basic navigation.
- [ ] **Accessibility (A11y)**:
    - [ ] VoiceOver support for `QuranPageView` (announce Page/Surah).
    - [ ] Audit contrast ratios for `ReadingTheme.night`.
- [ ] **Documentation**:
    - [ ] Add DocC comments to all public APIs in `Sources/Core`.
    - [ ] Improve in-code comments for complex logic (e.g., `AyahTimingService`).

## 📍 Phase 2: Feature Expansion
**Goal:** Add essential features that users expect from a modern Quran app.

- [ ] **Search Functionality**:
    - [ ] UI for searching Verses (Ayahs) and Chapters (Surahs).
    - [ ] Highlight search terms in results.
    - [ ] Navigation from result to specific Ayah in `MushafView`.
- [ ] **Reading Experience**:
    - [ ] **Bookmarks**: Ability to save multiple bookmarks (not just last read).
    - [ ] **Notes**: Allow users to attach private notes to verses.
    - [ ] **Translation View**: Split-screen or overlay mode to show translations alongside the generic page view.
- [ ] **Audio Enhancements**:
    - [ ] Background audio playback controls (Command Center).
    - [ ] Repeat range (Ayah/Surah repeat loops for memorization).

## 📍 Phase 3: Platform Polish for macOS
**Goal:** Make the app feel truly native on macOS, not just a "Catalyst-style" port.

- [ ] **Menu Bar Support**: Add Quran controls/status to the macOS menu bar.
- [ ] **Keyboard Shortcuts**:
    - [ ] `Cmd+F` for Search.
    - [ ] Arrow keys for robust page navigation wrapped in app logic.
- [ ] **Windowing**: better support for multiple Mushaf windows.

## 💭 Future Ideas (Backlog)
- **Tafseer Integration**: Fetch and display Tafseer for verses.
- **Widgets**: iOS Home Screen widgets for "Verse of the Day" or "Last Read".
- **watchOS**: Simple companion app for controlling playback.
