<h1 align="center">
   مصحف عماد <br />
  MushafImad
</h1>

<p align="center">
  <a href="https://swiftpackageindex.com/ibo2001/MushafImad">
    <img alt="Swift Package Index" src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fibo2001%2FMushafImad%2Fbadge%3Ftype%3Dswift-versions">
  </a>
  <a href="https://swiftpackageindex.com/ibo2001/MushafImad">
    <img alt="Supported Platforms" src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fibo2001%2FMushafImad%2Fbadge%3Ftype%3Dplatforms">
  </a>
  <img alt="iOS 17+" src="https://img.shields.io/badge/iOS-17%2B-blue?logo=apple">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-blue?logo=apple">
  <img alt="SwiftPM Compatible" src="https://img.shields.io/badge/SwiftPM-compatible-brightgreen?logo=swift">
  <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-black">
  <a href="https://github.com/ibo2001/MushafImad/actions">
    <img alt="CI Status" src="https://img.shields.io/github/actions/workflow/status/ibo2001/MushafImad/swift.yml?label=CI&logo=github">
  </a>
</p>

<div align="center">
  <h3>✨ Proud Participant in <a href="https://github.com/Ramadan-Impact">Ramadan Impact</a> ✨</h3>
  <p><i>An initiative by the Itqan Community to elevate open-source Islamic software.</i></p>
</div>

---


# MushafImad

A Swift Package that delivers a fully featured Mushaf (Quran) reading experience for iOS 17+ and macOS 14+. The package ships page images, verse metadata, timing information, audio helpers, and polished SwiftUI components so apps can embed a complete Quran reader with audio playback, toast feedback, and contextual navigation.

## Highlights

- **🎯 True Cross-Platform** – Native support for iOS 17+ and macOS 14+ with platform-specific UI adaptations and zero compromises.
- **📱 Rich Mushaf View** – `MushafView` renders all 604 pages with selectable verses, RTL paging, and theming via `ReadingTheme`.
- **💾 Realm-backed data** – Bundled `quran.realm` database powers fast, offline access to chapters, verses, parts (juz'), hizb metadata, and headers.
- **⚡ Aggressive caching** – `ChaptersDataCache`, `QuranDataCacheService`, and `QuranImageProvider` keep Realm objects and page images warm for smooth scrolling.
- **🎵 Integrated audio playback** – `QuranPlayerViewModel` coordinates `AVPlayer`, `ReciterService`, and `AyahTimingService` to sync highlighting with audio recitation.
- **🧩 Reusable UI components** – Toasts, hizb progress indicators, loading views, and sheet headers are available in `Sources/Components`.
- **📦 Example app** – The `Example` target demonstrates embedding `MushafView` on both iOS and macOS with very little wiring.

## Package Layout

- `Package.swift` – Declares the `MushafImad` library target and brings in the `RealmSwift` dependency. Resources include image assets, fonts, timing JSON, and the Realm database.
- `Sources/Core`
  - `Models` – Realm object models such as `Chapter`, `Verse`, `Page`, `Part`, and supporting DTOs (e.g. `HizbQuarterProgress`, `VerseHighlight`).
  - `Services` – Core infrastructure:
    - `RealmService` bootstraps the bundled Realm file into an application-support directory and exposes read APIs for chapters, pages, hizb, and search.
    - `ChaptersDataCache` lazily loads and groups chapters by juz, hizb, and Meccan/Medinan type.
    - `QuranDataCacheService` (notably used by the Mushaf view model) memoizes frequently accessed page metadata.
    - `FontRegistrar`, `AppLogger`, `ToastManager`, and `ChaptersDataCache` provide support utilities.
  - `Extensions` – Convenience helpers for colors, fonts, numbers, bundle access, and RTL-friendly UI utilities.
- `Sources/Services` – UI-facing services specific to the Mushaf reader:
  - `MushafView+ViewModel` orchestrates page state, caching, and navigation.
  - `QuranImageProvider` loads line images from the bundle with memory caching.
- `Sources/AudioPlayer`
  - `ViewModels/QuranPlayerViewModel` bridges `AVPlayer` with verse timing for audio playback.
  - `Services/AyahTimingService` loads JSON timing data; `ReciterService` and `ReciterDataProvider` expose available reciters; `ReciterPickerView` renders selection UI.
  - `Views/QuranPlayer` and supporting SwiftUI components power the player sheet.
- `Sources/Components` – Shared SwiftUI building blocks, including `FloatingToastView`, `ToastOverlayView`, loading/UI chrome, and progress displays.
- `Sources/Media.xcassets` – All imagery used by the reader (page UI, icons, color definitions).
- `Sources/Resources`
  - `Res/quran.realm` – Bundled offline database.
  - `Res/fonts` – Quran-specific fonts registered at runtime.
  - `Res/ayah_timing/*.json` – Verse timing for supported reciters.
  - `Localizable.xcstrings` – Localization content.
- `Tests/MushafImadSPMTests` – Placeholder for package-level tests.

## Data & Image Flow

1. **Startup**
   - Call `RealmService.shared.initialize()` during app launch to copy the bundled Realm into a writable location.
   - Invoke `FontRegistrar.registerFontsIfNeeded()` so custom Quran fonts are available to SwiftUI.
2. **Rendering pages**
   - `MushafView` instantiates `ViewModel`, which pulls chapter metadata from `ChaptersDataCache` and prefetches page data.
   - `PageContainer` loads `Page` objects lazily via `RealmService.fetchPageAsync(number:)` and hands them to `QuranPageView`.
   - `QuranImageProvider` loads line images directly from the bundle with memory caching for fast re-access.
3. **Audio playback**
   - `ReciterService` exposes reciter metadata, persisting selections via `@AppStorage`.
   - `QuranPlayerViewModel` configures `AVPlayer` with the selected reciter’s base URL and uses `AyahTimingService` to highlight verses in sync with playback.

## Using the Package

### SwiftData Model Container Setup (Required for Eye Tracking)

If you plan to use the **eye-tracking reading progress feature**, you must include the `ReadingSession` model in your app's SwiftData `ModelContainer` schema. This model persists reading sessions locally for progress tracking and resumption.

**Add to your App initialization:**

```swift
import SwiftUI
import SwiftData
import MushafImad

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            ReadingSession.self  // Required for eye tracking persistence
        ])
    }
}
```

**Why is this required?**
- The `ReadingSession` model uses SwiftData's `@Model` macro for persistence
- Apps that don't include it in their schema will crash at runtime when eye tracking attempts to save sessions
- This is only needed if you enable the eye tracking feature

**Migration for existing apps:**
If your app already has a `ModelContainer`, simply add `ReadingSession.self` to your existing model array:

```swift
.modelContainer(for: [
    YourExistingModel.self,
    ReadingSession.self  // Add this
])
```

### Basic Setup

1. **Add the dependency**

   ```swift
   .package(url: "https://github.com/ibo2001/MushafImad", from: "1.0.4")
   ```

   Then add `MushafImad` to your target dependencies.

2. **Bootstrap infrastructure early**

   ```swift
   import MushafImad

   @main
   struct MyApp: App {
       init() {
           try? RealmService.shared.initialize()
           FontRegistrar.registerFontsIfNeeded()
       }

       var body: some Scene {
           WindowGroup {
               MushafScene()
                   .environmentObject(ReciterService.shared)
                   .environmentObject(ToastManager())
           }
           .modelContainer(for: [ReadingSession.self])  // Required for eye tracking
       }
   }
   ```

3. **Present the Mushaf reader**

   ```swift
   struct MushafScene: View {
       var body: some View {
           MushafView(initialPage: 1)
               .task { await MushafView.ViewModel().loadData() }
       }
   }
   ```

4. **Optional configuration**
   - Use `AppStorage` keys (`reading_theme`, `scrolling_mode`, `selectedReciterId`) to persist user preferences.
   - Add `ToastOverlayView()` at the root of your layout so toasts can appear above the UI.
   - Keep reading colors stable across system Light/Dark by providing a custom `ReadingTheme`.
   - React to user interaction with `onVerseLongPress` and `onPageTap` to drive surrounding UI, such as showing toolbars or presenting sheets.

```swift
// Per-instance reading theme override
MushafView(
    initialPage: 1,
    readingTheme: ReadingTheme(
        backgroundColor: Color(hex: "#F6F0DF"),
        textColor: .naturalBlack
    )
)

// Or set a package-level default for a subtree
MushafView(initialPage: 1)
    .mushafReadingTheme(
        ReadingTheme(
            backgroundColor: Color(hex: "#1F2420"),
            textColor: .naturalWhite
        )
    )
```

Theme resolution in `MushafView` follows this precedence: `explicitReadingTheme ?? environmentReadingTheme ?? readingThemePreset.theme` (an explicit per-instance `readingTheme` passed to `MushafView` wins first, then any package-level/environment-provided theme, and finally the persisted preset default).

```swift
struct ReaderContainer: View {
    @State private var highlightedVerse: Verse?
    @State private var isChromeVisible = true

    var body: some View {
        MushafView(
            initialPage: 1,
            highlightedVerse: $highlightedVerse,
            onVerseLongPress: { verse in highlightedVerse = verse },
            onPageTap: { withAnimation { isChromeVisible.toggle() } }
        )
        .toolbarVisibility(isChromeVisible ? .visible : .hidden, for: .navigationBar)
    }
}
```

### Advanced: Custom Page Layouts

As of version 1.0.3, `MushafView` exposes its internal page layout functions as public APIs, allowing you to build custom reading experiences while reusing the package's page rendering logic:

- **`horizontalPageView(currentHighlight:)`** – Returns a horizontal `TabView`-based paging layout (iOS-style page flipping).
- **`verticalPageView(currentHighlight:)`** – Returns a vertical scrolling layout with snap-to-page behavior.
- **`pageContent(for:highlight:)`** – Returns the content view for a single page, including verse interaction handlers.

These functions give you full control over how pages are presented. For example, you can embed them in custom navigation structures, add overlays, or implement alternative scrolling behaviors:

```swift
struct CustomMushafLayout: View {
    @State private var mushafView = MushafView(initialPage: 1)
    @State private var showOverlay = false
    
    var body: some View {
        ZStack {
            // Use the built-in horizontal page view
            mushafView.horizontalPageView(currentHighlight: nil)
            
            // Add your custom overlay
            if showOverlay {
                CustomControlsOverlay()
            }
        }
    }
}
```

You can also mix and match layouts or switch between them dynamically based on device orientation or user preferences.

### Customizing Assets

The package ships a full asset catalog (`Media.xcassets`) that includes color definitions and decorative images such as `fasel`, `pagenumb`, and `suraNameBar`. To override them without forking the package, configure `MushafAssets` at launch:

```swift
import MushafImad

@main
struct MyApp: App {
    init() {
        // Use colors and images from the host app's asset catalog when available.
        MushafAssets.configuration = MushafAssetConfiguration(
            colorBundle: .main,
            imageBundle: .main
        )
    }
    // ...
}
```

If you only want to override a subset, provide custom closures instead:

```swift
MushafAssets.configuration = MushafAssetConfiguration(
    colorProvider: { name in
        name == "Brand 500" ? Color("PrimaryBrand", bundle: .main) : nil
    },
    imageProvider: { name in
        switch name {
        case "fasel":
            return Image("CustomAyahMarker", bundle: .main)
        default:
            return nil
        }
    }
)
```

Call `MushafAssets.reset()` to restore the defaults (useful inside tests or sample views).

## Example Project

The `Example` directory contains a minimal SwiftUI app that imports the package and displays `MushafView`. Open `Example/Example.xcodeproj` to experiment with the reader, swap reciters, or tweak theming.

> **Note:** The Example app requires network permissions for audio streaming. Images are bundled with the package and load instantly.

Demos include:

- **Quick Start** – Open the Mushaf with sensible defaults.
- **Suras List** – Browse every chapter, jump to its first page, and use `onPageTap` to toggle the navigation chrome.
- **Verse by Verse** – Long-press any ayah to open the audio sheet, highlight it in the Mushaf, and play from that verse while the highlight follows live playback.
- **Audio Player UI** – Explore the rich `QuranPlayer` controls, reciter switching, and chapter navigation.

## Platform-Specific Features

MushafImad provides a **native experience** on each platform with carefully crafted adaptations:

### iOS 17+
- **📳 Haptic feedback** – Verse selection triggers light haptic feedback for tactile confirmation.
- **📡 AirPlay support** – Built-in `AVRoutePickerView` for streaming audio to external devices.
- **🎡 Wheel picker** – Native iOS wheel-style picker for reciter selection.
- **👆 Tab view paging** – Smooth page-style navigation with native iOS gestures.
- **📱 Inset grouped lists** – iOS-native list styling for settings and navigation.
- **🎨 Navigation bar controls** – Standard iOS toolbar placement and styling.

### macOS 14+
- **🖱️ Native controls** – Menu-style pickers and macOS-appropriate UI components.
- **⌨️ Keyboard navigation** – Full keyboard support for page navigation and controls.
- **🪟 Window management** – Adapts to macOS window resizing and split-view layouts with `NavigationSplitView`.
- **🖼️ Cross-platform images** – Automatic handling of UIImage/NSImage conversion.
- **📐 Sidebar navigation** – macOS-native sidebar list style for better desktop experience.
- **🎯 Form styling** – Grouped form style optimized for macOS.

### Cross-Platform Compatibility

The package uses **conditional compilation** to ensure seamless operation on both platforms:

```swift
#if canImport(UIKit)
// iOS-specific code
import UIKit
#elseif canImport(AppKit)
// macOS-specific code
import AppKit
#endif
```

**Platform-specific APIs** are properly isolated:
- `UIScreen`, `UIApplication`, `UIImpactFeedbackGenerator` → iOS only
- `NSColor`, `NSImage`, `NSBezierPath` → macOS only
- Shared SwiftUI code works identically on both platforms

**Example app** demonstrates best practices with separate `ContentView_iOS.swift` and `ContentView_macOS.swift` implementations, ensuring optimal UX on each platform.

## Development Notes

- **Logging** – Use `AppLogger.shared` for colored console output and optional file logging. Categories (`LogCategory`) cover UI, audio, downloads, Realm, and more.
- **Caching** – `QuranDataCacheService` and `ChaptersDataCache` are singletons; clear caches with their `clearCache()` helpers during debugging.
- **Fonts** – All fonts live under `Sources/Resources/Res/fonts`. Update `FontRegistrar.fontFileNames` when adding or removing font assets.
- **Resources** – Additional surah timing JSON or page imagery must be added to `Resources/Res` and declared via `.process` in `Package.swift`.
- **Theming** – Reading theme colors live in `Media.xcassets/Colors`. App-specific palettes can override or extend them.
- **Platform testing** – Use `swift build` to verify compilation on macOS. The package automatically adapts UI components based on the target platform.

## Testing & Verification

### iOS Testing
- Launch the example app on iOS and scroll through several pages to confirm image prefetching.
- Trigger audio playback using the player UI to ensure verse highlighting and reciter switching behave as expected.
- Test haptic feedback on verse selection.
- Verify AirPlay functionality with external devices.

### macOS Testing
- Launch the example app on macOS and verify window management and resizing.
- Test keyboard navigation through pages and controls.
- Verify sidebar navigation and form styling.
- Confirm all UI elements render correctly without iOS-specific APIs.

### Package Testing
- Run `swift build` to verify compilation on macOS.
- Run unit tests with `swift test` (tests are currently scaffolding; add coverage as new features land).
- Test on both Intel and Apple Silicon Macs for architecture compatibility.

## Troubleshooting

If you encounter issues with:
- Audio playback not working ("server hostname not found")
- Images not loading
- Network connectivity errors

Please refer to the comprehensive [TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide for solutions and configuration steps.

## Contributing

We are actively seeking contributors for the **Ramadan Impact** campaign!
Please read our **[CONTRIBUTING.md](CONTRIBUTING.md)** guide specifically designed to help you get started quickly and follow our contribution workflow.

---

This package is designed to be composable: reuse just the data services, or drop in the entire reader. Explore `Sources/` for more detailed documentation added alongside the code.
