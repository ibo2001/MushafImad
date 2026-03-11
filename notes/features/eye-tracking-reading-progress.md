# Issue #22: Eye-Tracking-Assisted Reading Progress

## Implementation Status (2026-03-11)

Phases 1, 2, 4, 5 implemented. Phase 3 (ARKit) deferred.

### Files Created
- `Sources/MushafImad/EyeTracking/GazePoint.swift` - Normalized gaze coordinate model
- `Sources/MushafImad/EyeTracking/GazeTrackingProtocol.swift` - Provider protocol
- `Sources/MushafImad/EyeTracking/ScrollBasedGazeProvider.swift` - Heuristic provider (all devices)
- `Sources/MushafImad/EyeTracking/GazeToVerseResolver.swift` - Maps gaze to verses via VerseHighlight
- `Sources/MushafImad/EyeTracking/ReadingProgressTracker.swift` - Saves to RecentReading/MyKhatma
- `Sources/MushafImad/EyeTracking/GazeTrackingService.swift` - Main coordinator (like TiltScrollManager)
- `Sources/MushafImad/EyeTracking/GazeSettingsView.swift` - Settings UI
- `Tests/MushafImadSPMTests/GazePointTests.swift` - GazePoint unit tests
- `Tests/MushafImadSPMTests/ScrollBasedGazeProviderTests.swift` - Provider tests
- `Tests/MushafImadSPMTests/ReadingProgressTrackerTests.swift` - Tracker tests

### Files Modified
- `Sources/MushafImad/MushafView.swift` - Added GazeTrackingService integration

### Build Note
SPM CLI (`swift build`) has pre-existing macro expansion failures (#Preview, @Model, SwiftData).
All new code follows identical patterns to existing code. Builds correctly in Xcode.

## Research Notes (2026-03-11)

### Repository Architecture Summary

**Swift Package**: `MushafImad` (Swift 6.0, iOS 17+, macOS 14+)
**UI Framework**: SwiftUI
**Data Layer**: Realm (bundled `quran.realm`) + SwiftData (for user models like `MyKhatma`)
**State**: `@Observable` ViewModels, `@AppStorage` for preferences

#### Key Architectural Patterns
- Pages rendered as 15 line images per page (1440x232 px each)
- Verse positions are pre-mapped in Realm with `VerseHighlight` (line, left, right normalized coords) and `VerseMarker` (line, centerX, centerY)
- `MushafView` -> `PageContainer` -> `QuranPageView` -> `LineImageView` rendering chain
- Existing sensor feature: `TiltScrollManager` uses CoreMotion for tilt-to-scroll (good architectural precedent)
- `TiltSettingsView` shows the settings UI pattern (Form + Toggle + Slider + AppStorage)
- Reading progress already tracked via `MyKhatma` (SwiftData) with `lastReadPage`
- `RecentReading` model tracks surah/verse/timestamp
- Platform-specific code uses `#if canImport(UIKit)` / `#if canImport(AppKit)`

#### Verse Layout Data Available in Realm
- `VerseHighlight`: `line: Int`, `left: Float`, `right: Float` (normalized 0-1 coords)
- `VerseMarker`: `line: Int`, `centerX: Float`, `centerY: Float` (normalized)
- Each page has 15 lines (0-14), verses span across lines
- Highlights are per-verse, per-line (a verse spanning 2 lines has 2 highlight entries)

### Feasibility Analysis: Eye Tracking on iOS

#### Apple ARKit Eye Tracking (ARFaceTrackingConfiguration)
- **Available on**: iPhone X+ and iPad Pro (TrueDepth camera required)
- **API**: `ARFaceTrackingConfiguration` provides `lookAtPoint` (CGPoint in face coordinate space)
- **Accuracy**: ~1-2 degree gaze accuracy; translates to roughly 1-2cm on screen at reading distance
- **Privacy**: Camera feed processed on-device; no data leaves the device
- **Limitation**: Requires ARSession running, which is power-intensive
- **SwiftUI integration**: Need ARSCNView/ARView wrapped in UIViewRepresentable

#### Apple Accessibility Eye Tracking (iOS 15+)
- **Available on**: iPads with M-series chips (not iPhones as of iOS 17)
- **API**: AssistiveTouch eye tracking - system-level, not app-accessible via API
- **Not directly usable** for custom gaze mapping

#### Vision Framework (VNDetectFaceLandmarksRequest)
- Can detect face landmarks including eye positions from camera feed
- Lower-level than ARKit; requires more work to estimate gaze direction
- Works on any device with a front camera
- Less accurate than ARKit for gaze estimation

#### Practical Assessment
- **ARKit face tracking** is the most viable approach for real eye tracking
- Only works on TrueDepth-camera devices (iPhone X+, iPad Pro)
- Battery impact is significant (continuous AR session)
- Accuracy of ~1-2 degrees may not be sufficient to distinguish individual Quran lines (15 lines on a screen = very dense)
- **Arabic RTL text** adds complexity: reading direction right-to-left must be accounted for
- **Fallback heuristics** (scroll position + dwell time) would cover all devices

### Proposed Implementation Approach

#### Phase 1: Foundation (GazeTrackingService + Protocol)
Create an abstraction layer so different tracking methods can be swapped:

```
Sources/MushafImad/EyeTracking/
  GazeTrackingProtocol.swift    - Protocol defining gaze data interface
  GazeTrackingService.swift     - Manager that coordinates tracking + verse mapping
  GazePoint.swift               - Model for normalized gaze coordinates
  EyeTrackingSettings.swift     - AppStorage-based settings (enabled, sensitivity, etc.)
  EyeTrackingSettingsView.swift - Settings UI (like TiltSettingsView pattern)
```

**GazeTrackingProtocol**: Defines `startTracking()`, `stopTracking()`, and publishes `GazePoint` (x, y normalized to screen).

#### Phase 2: Fallback Heuristic Provider
Before real eye tracking, implement a scroll-position + dwell-time heuristic:
- Track which lines are visible on screen
- Estimate reading position based on time spent on page + scroll position
- Map visible area to verses using existing `VerseHighlight` data
- This works on ALL devices and provides immediate value

```
Sources/MushafImad/EyeTracking/
  ScrollBasedGazeProvider.swift  - Heuristic: visible area + dwell time
```

#### Phase 3: ARKit Eye Tracking Provider
Real gaze estimation using ARFaceTrackingConfiguration:
- Wrap ARSession in a non-rendering configuration (front camera only)
- Extract `lookAtPoint` from face anchors
- Convert to screen coordinates
- Map to verse positions using VerseHighlight data

```
Sources/MushafImad/EyeTracking/
  ARKitGazeProvider.swift        - ARKit-based real gaze tracking (iOS only)
```

#### Phase 4: Verse Resolution + Auto-Progress
- `GazeToVerseResolver`: takes normalized gaze point + current page -> resolves to specific verse using VerseHighlight/VerseMarker data from Realm
- Auto-save: persist current reading verse to `RecentReading` or `MyKhatma.lastReadPage`
- Optional auto-advance: when gaze reaches last line of page for sustained duration, flip to next page
- Optional active verse highlighting

#### Phase 5: Integration with MushafView
- Add `EyeTrackingManager` (like `TiltScrollManager`) as `@StateObject` in `MushafView`
- Wire gaze -> verse resolution -> highlight binding
- Add settings toggle in app preferences

### Key Files to Modify

**New files** (under `Sources/MushafImad/EyeTracking/`):
- `GazeTrackingProtocol.swift`
- `GazePoint.swift`
- `GazeTrackingService.swift`
- `ScrollBasedGazeProvider.swift`
- `ARKitGazeProvider.swift` (iOS only)
- `GazeToVerseResolver.swift`
- `EyeTrackingSettingsView.swift`

**Existing files to modify**:
- `MushafView.swift` - Add EyeTrackingManager state, wire to highlight binding
- `QuranPageView.swift` - Possibly add coordinate space name for gaze mapping
- `MushafView+ViewModel.swift` - Add auto-save reading progress, auto-advance logic
- `Package.swift` - No new dependencies needed (ARKit is a system framework)
- `MyReadsModels.swift` - Possibly extend `RecentReading` with gaze-source metadata

### Concerns and Blockers

1. **Accuracy vs. density**: Quran pages have 15 tightly-packed lines. ARKit gaze accuracy (~1-2 degrees) may not reliably distinguish adjacent lines. Testing on real devices is essential before committing to the approach.

2. **Battery drain**: Continuous ARSession for face tracking is power-intensive. Need aggressive session management (pause when backgrounded, timeout after inactivity, respect Low Power Mode).

3. **Device coverage**: TrueDepth camera required for ARKit face tracking. Older iPhones (8, SE 2nd gen) and all macOS devices are excluded. The fallback heuristic path is essential.

4. **Privacy**: ARKit camera access requires `NSCameraUsageDescription` in Info.plist. Even though data stays local, the camera permission prompt may concern users. Must be clearly opt-in with good UX explaining why.

5. **Swift 6 concurrency**: The package uses Swift 6 strict concurrency. ARKit callbacks come on arbitrary threads; need careful `@MainActor` / `@Sendable` handling.

6. **macOS**: ARKit face tracking is iOS-only. macOS would only get the scroll-based heuristic fallback. Use `#if canImport(UIKit)` guards.

7. **Testing**: Real eye tracking is nearly impossible to unit test. Focus tests on the verse resolution logic (GazeToVerseResolver) which can be tested with mock gaze points against known verse highlight data.

8. **Collaborative issue**: 4 assignees. Need clear phase ownership to avoid conflicts.

### Recommendation

Start with Phase 1 (protocol/abstraction) + Phase 2 (scroll heuristic) + Phase 4 (verse resolution). This delivers immediate user value on all devices without camera permissions. Phase 3 (ARKit) can be added later as an enhancement once the foundation is proven.

The existing `TiltScrollManager` is an excellent architectural template -- follow the same patterns for the eye tracking feature (ObservableObject, activate/deactivate lifecycle, settings view with AppStorage).
