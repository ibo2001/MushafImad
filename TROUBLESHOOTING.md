# Troubleshooting Guide

## Audio Player Not Working - "Server with specified hostname could not be found"

### Problem
When running the Example app on macOS, the audio player shows an error: "A server with the specified hostname could not be found."

### Root Causes

1. **Missing Network Permissions (macOS)**
   - macOS apps require explicit network permissions to access external resources
   - The audio files are hosted on external servers (mp3quran.net)
   - Without proper entitlements, network requests will fail

2. **Missing Info.plist Configuration**
   - App Transport Security (ATS) needs to be configured to allow HTTP/HTTPS connections
   - The Example app was missing an Info.plist file

### Solutions

#### Solution 1: Add Network Entitlements (macOS)

1. Open the Example project in Xcode
2. Select the Example target
3. Go to "Signing & Capabilities" tab
4. Add the "App Sandbox" capability if not present
5. Under "Network", enable "Outgoing Connections (Client)"

Alternatively, add the `Example.entitlements` file to your project with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.network.client</key>
	<true/>
</dict>
</plist>
```

#### Solution 2: Configure Info.plist

Add an `Info.plist` file to the Example app with App Transport Security settings:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
	</dict>
</dict>
</plist>
```

#### Solution 3: Add Files to Xcode Project

The files `Info.plist` and `Example.entitlements` have been created in the `Example/Example/` directory. You need to add them to your Xcode project:

1. Open `Example.xcodeproj` in Xcode
2. Right-click on the "Example" group in the project navigator
3. Select "Add Files to Example..."
4. Navigate to `Example/Example/` and select:
   - `Info.plist`
   - `Example.entitlements`
5. Make sure "Copy items if needed" is unchecked (they're already in the right location)
6. Click "Add"

7. Select the Example target in Xcode
8. Go to "Build Settings"
9. Search for "Info.plist File"
10. Set the value to: `Example/Info.plist`

11. Search for "Code Signing Entitlements"
12. Set the value to: `Example/Example.entitlements`

### Verification

After applying these fixes:

1. Clean the build folder (Cmd+Shift+K)
2. Build and run the Example app
3. Navigate to "Audio Player UI" in the sidebar
4. The audio player should now load successfully
5. Check the console logs for:
   ```
   ReciterService: Loaded X reciters
   ReciterService: Selected default reciter: Ibrahim Al-Akdar (ID: 1)
   ReciterService: Audio base URL: https://server6.mp3quran.net/akdr/
   QuranPlayer: Loading audio from URL: https://server6.mp3quran.net/akdr/001.mp3
   ```

## Images Not Loading

### Problem
Quran page images are not displaying in the MushafView.

### Root Cause
Images are downloaded from a remote CDN and also require network permissions.

### Solution
The same network permissions fixes above will also resolve image loading issues.

### Additional Notes

- Images are cached locally after first download
- The default CDN is: `https://mushaf-imad.qraiqe.no/files/data/quran-images`
- You can change the image base URL in the "Download Management" demo

## Debugging Tips

### Enable Logging

The package uses `AppLogger` for debugging. Check the Xcode console for log messages:

- `ReciterService` logs show reciter loading status
- `QuranPlayer` logs show audio URL being loaded
- `AyahTimingService` logs show JSON file loading status

### Common Issues

1. **"No reciters loaded from JSON files"**
   - This is normal - the package falls back to embedded reciter data
   - JSON timing files are loaded on-demand when needed

2. **"Could not find JSON file for reciter X"**
   - Check that the `Resources/Res/ayah_timing/` directory is included in the package
   - Verify the JSON files are present in the built app bundle

3. **Network errors**
   - Verify internet connectivity
   - Check that network entitlements are properly configured
   - Try accessing the audio URL directly in a browser to verify it's accessible

### Testing Network Connectivity

You can test if the audio URLs are accessible by running this in Terminal:

```bash
curl -I https://server6.mp3quran.net/akdr/001.mp3
```

If this returns a 200 OK response, the server is accessible and the issue is with app permissions.

## iOS Considerations

iOS apps have different permission requirements:

- iOS apps don't use entitlements files for basic network access
- The Info.plist with ATS configuration should be sufficient
- iOS 14+ may require additional privacy permissions for certain network operations

## Production Recommendations

For production apps:

1. **Don't use `NSAllowsArbitraryLoads`** - Instead, configure specific exception domains:

```xml
<key>NSAppTransportSecurity</key>
<dict>
	<key>NSExceptionDomains</key>
	<dict>
		<key>mp3quran.net</key>
		<dict>
			<key>NSExceptionAllowsInsecureHTTPLoads</key>
			<true/>
			<key>NSIncludesSubdomains</key>
			<true/>
		</dict>
		<key>qraiqe.no</key>
		<dict>
			<key>NSExceptionAllowsInsecureHTTPLoads</key>
			<false/>
			<key>NSIncludesSubdomains</key>
			<true/>
		</dict>
	</dict>
</dict>
```

2. **Consider offline mode** - Pre-download audio files and images for offline use
3. **Handle network errors gracefully** - Show user-friendly error messages with retry options
4. **Cache aggressively** - The package already implements caching, but you can pre-load content

## Need More Help?

If you're still experiencing issues:

1. Check the console logs for specific error messages
2. Verify all files are properly added to the Xcode project
3. Clean build folder and rebuild
4. Check that you're running on a supported platform (iOS 17+ or macOS 14+)
5. Open an issue on GitHub with:
   - Console log output
   - Steps to reproduce
   - macOS/iOS version
   - Xcode version

