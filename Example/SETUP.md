# Example App Setup Guide

## Quick Start

This Example app demonstrates the MushafImad package features. Before running, you need to configure network permissions.

## Prerequisites

- Xcode 15.0 or later
- macOS 14+ (for macOS target) or iOS 17+ (for iOS target)
- Internet connection (for downloading audio and images)

## Setup Steps

### Option 1: Automated Setup (Recommended)

Run the configuration script from the repository root:

```bash
cd /path/to/MushafImad
./configure_example_project.sh
```

Follow the on-screen instructions to complete the setup in Xcode.

### Option 2: Manual Setup

1. **Open the project in Xcode:**
   ```bash
   open Example.xcodeproj
   ```

2. **Add required files:**
   - In Project Navigator, right-click on "Example" group
   - Select "Add Files to Example..."
   - Navigate to `Example/Example/` and select:
     - `Info.plist`
     - `Example.entitlements`
   - **Important:** Uncheck "Copy items if needed"
   - Click "Add"

3. **Configure Build Settings:**
   - Select the "Example" target
   - Go to "Build Settings" tab
   - Search for "Info.plist File"
   - Set value to: `Example/Info.plist`
   - Search for "Code Signing Entitlements"
   - Set value to: `Example/Example.entitlements`

4. **Configure Signing & Capabilities:**
   - Select the "Example" target
   - Go to "Signing & Capabilities" tab
   - If "App Sandbox" is not present, click "+ Capability" and add it
   - Under "App Sandbox", check "Outgoing Connections (Client)"

5. **Clean and Build:**
   - Press `Cmd+Shift+K` to clean
   - Press `Cmd+B` to build
   - Press `Cmd+R` to run

## Verifying Setup

After running the app, you should see:

1. **Sidebar Navigation** (macOS) or **Tab Bar** (iOS) with demo options
2. **No network errors** when selecting "Audio Player UI"
3. **Images loading** when viewing the Mushaf pages
4. **Console logs** showing successful initialization:
   ```
   ReciterService: Loaded 18 reciters
   ReciterService: Selected default reciter: Ibrahim Al-Akdar (ID: 1)
   QuranPlayer: Loading audio from URL: https://server6.mp3quran.net/akdr/001.mp3
   ```

## Common Issues

### "Server hostname not found" error

**Cause:** Network permissions not configured properly.

**Solution:**
1. Verify `Example.entitlements` is added to the project
2. Check that "Outgoing Connections (Client)" is enabled in App Sandbox
3. Ensure `Info.plist` is set in Build Settings

### Images not loading

**Cause:** Same as audio - network permissions issue.

**Solution:** Follow the same steps as above.

### Build errors about missing files

**Cause:** Files not properly added to Xcode project.

**Solution:**
1. Check that `Info.plist` and `Example.entitlements` exist in `Example/Example/` directory
2. In Xcode, verify they appear in the Project Navigator
3. Check their "Target Membership" includes the Example target

### "Could not find module 'MushafImad'"

**Cause:** Swift Package dependencies not resolved.

**Solution:**
1. In Xcode, go to File → Packages → Resolve Package Versions
2. Wait for Swift Package Manager to download dependencies
3. Clean and rebuild

## Features to Explore

Once setup is complete, try these demos:

### 1. Suras List
- Browse all 114 chapters
- Click any chapter to jump to its first page
- Tap the page to toggle navigation chrome

### 2. Read the Mushaf
- Swipe to navigate between pages
- Tap verses to see selection
- Long-press verses for contextual actions

### 3. Audio Player UI
- Play complete chapters
- Switch between 18 different reciters
- Control playback speed
- Navigate by verse or chapter

### 4. Verse by Verse Playback
- Long-press any verse to start playback
- Watch live highlighting sync with audio
- Navigate between verses while playing

### 5. Download Management
- Configure custom image CDN
- Pre-download entire Mushaf for offline use
- Monitor download progress

### 6. Custom Branding
- Override default colors and images
- See how to customize the package appearance
- Toggle between default and custom branding

## Development Tips

### Viewing Console Logs

1. Run the app from Xcode
2. Open the Console (Cmd+Shift+C)
3. Filter by "MushafImad" to see package logs
4. Look for categories: UI, Network, Realm, Audio

### Testing Network Connectivity

Test audio URLs directly:
```bash
curl -I https://server6.mp3quran.net/akdr/001.mp3
```

Should return `HTTP/1.1 200 OK` if the server is accessible.

### Resetting State

To reset the app to initial state:
1. Delete the app from your device/simulator
2. Clean build folder (Cmd+Shift+K)
3. Rebuild and run

## Need Help?

- See [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for detailed troubleshooting
- Check [../README.md](../README.md) for package documentation
- Open an issue on GitHub with console logs and steps to reproduce

## Platform-Specific Notes

### macOS
- App Sandbox is **required** for Mac App Store distribution
- Network entitlements are **mandatory** for external connections
- Window management works best with minimum size 800x600

### iOS
- App Transport Security (ATS) is configured in Info.plist
- Network access is allowed by default (no sandbox)
- Haptic feedback works on physical devices only

## Next Steps

After verifying the Example app works:

1. Explore the source code in `ContentView_macOS.swift` and `ContentView_iOS.swift`
2. Study how `MushafView` is integrated
3. Learn how `ReciterService` and `ToastManager` are injected
4. Experiment with customization options
5. Build your own app using MushafImad!

---

**Happy coding! 🚀**

