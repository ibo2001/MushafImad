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
  - `QuranImageProvider`, `QuranImageDownloadManager`, and `QuranImageFileStore` manage disk/memory caching for line images.
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
   - `QuranImageProvider` streams line images, ensuring disk and memory caches stay warm around the current page.
3. **Audio playback**
   - `ReciterService` exposes reciter metadata, persisting selections via `@AppStorage`.
   - `QuranPlayerViewModel` configures `AVPlayer` with the selected reciter’s base URL and uses `AyahTimingService` to highlight verses in sync with playback.

## Using the Package

1. **Add the dependency**

   ```swift
   .package(url: "https://github.com/ibo2001/MushafImad", from: "1.0.1")
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
   - Customize colors via assets or override `ReadingTheme` cases if you add more themes.
   - React to user interaction with `onVerseLongPress` and `onPageTap` to drive surrounding UI, such as showing toolbars or presenting sheets.

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

### Remote Content Settings

Line images are downloaded from the default CDN (`https://mushaf-imad.qraiqe.no/files/data/quran-images`). You can point the package at your own mirror and optionally force a full pre-download:

```swift
import MushafImad

@MainActor
func configureMushaf() async {
    if let customURL = URL(string: "https://cdn.example.com/mushaf") {
        await QuranImageProvider.shared.updateImageBaseURL(customURL)
    }

    try await QuranImageProvider.shared.preloadEntireMushaf { completed, total in
        print("Downloaded \(completed) / \(total)")
    }
}
```

Call `await QuranImageProvider.shared.resetImageBaseURLToDefault()` to return to the packaged CDN.

## Example Project

The `Example` directory contains a minimal SwiftUI app that imports the package and displays `MushafView`. Open `Example/Example.xcodeproj` to experiment with the reader, swap reciters, or tweak theming. Demos include:

- **Quick Start** – Open the Mushaf with sensible defaults.
- **Suras List** – Browse every chapter, jump to its first page, and use `onPageTap` to toggle the navigation chrome.
- **Verse by Verse** – Long-press any ayah to open the audio sheet, highlight it in the Mushaf, and play from that verse while the highlight follows live playback.
- **Audio Player UI** – Explore the rich `QuranPlayer` controls, reciter switching, and chapter navigation.
- **Download Management** – Point the image provider at a custom CDN and prefetch the full Mushaf for offline use.

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

## Contributing

1. Fork and create a feature branch.
2. Add tests and documentation for changes.
3. Run `swift test` and lint your SwiftUI views.
4. Submit a pull request describing the update.

---

This package is designed to be composable: reuse just the data services, or drop in the entire reader. Explore `Sources/` for more detailed documentation added alongside the code.
