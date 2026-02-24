# Xcode Setup Steps - Visual Guide

## Step-by-Step Instructions with Screenshots

### Step 1: Add Files to Project

1. **Open the project in Xcode:**
   ```bash
   open Example.xcodeproj
   ```

2. **In the Project Navigator (left sidebar):**
   - Right-click on the "Example" folder (the one with the blue icon)
   - Select "Add Files to Example..."

3. **In the file picker:**
   - Navigate to `Example/Example/` directory
   - Select both files:
     - ✅ `Info.plist`
     - ✅ `Example.entitlements`
   - **IMPORTANT:** Uncheck "Copy items if needed" (files are already in correct location)
   - **IMPORTANT:** Make sure "Example" is checked under "Add to targets"
   - Click "Add"

### Step 2: Configure Info.plist in Build Settings

1. **Select the project** (top item in Project Navigator - "Example" with blue icon)

2. **Select the "Example" target** (under TARGETS section)

3. **Click "Build Settings" tab** (at the top)

4. **Search for "Info.plist"** (use the search box at the top right)

5. **Find "Info.plist File" setting:**
   - Double-click the value field
   - Enter: `Example/Info.plist`
   - Press Enter

### Step 3: Configure Code Signing Entitlements

1. **Still in Build Settings tab**

2. **Search for "entitlements"** (use the search box)

3. **Find "Code Signing Entitlements" setting:**
   - Double-click the value field
   - Enter: `Example/Example.entitlements`
   - Press Enter

### Step 4: Configure App Sandbox

1. **Click "Signing & Capabilities" tab** (at the top)

2. **Check if "App Sandbox" capability exists:**
   - If YES: Skip to step 3
   - If NO: Continue to add it

3. **To add App Sandbox (if not present):**
   - Click "+ Capability" button (top left)
   - Type "App Sandbox" in the search
   - Double-click "App Sandbox" to add it

4. **Configure Network Access:**
   - Under "App Sandbox" section
   - Find "Network" subsection
   - Check ✅ "Outgoing Connections (Client)"

### Step 5: Verify Configuration

1. **Check Project Navigator:**
   ```
   Example/
   ├── Example/
   │   ├── Assets.xcassets/
   │   ├── ContentView.swift
   │   ├── ContentView_iOS.swift
   │   ├── ContentView_macOS.swift
   │   ├── ExampleApp.swift
   │   ├── Info.plist          ← Should be visible here
   │   └── Example.entitlements ← Should be visible here
   └── Example.xcodeproj/
   ```

2. **Check Build Settings:**
   - Info.plist File: `Example/Info.plist` ✅
   - Code Signing Entitlements: `Example/Example.entitlements` ✅

3. **Check Signing & Capabilities:**
   - App Sandbox present ✅
   - Outgoing Connections (Client) checked ✅

### Step 6: Clean and Build

1. **Clean Build Folder:**
   - Menu: Product → Clean Build Folder
   - Or press: `Cmd + Shift + K`

2. **Build:**
   - Menu: Product → Build
   - Or press: `Cmd + B`

3. **Wait for build to complete** (should succeed with no errors)

### Step 7: Run and Verify

1. **Run the app:**
   - Menu: Product → Run
   - Or press: `Cmd + R`

2. **Navigate to "Audio Player UI"** in the sidebar

3. **Verify success:**
   - No error banner at top
   - Audio player controls visible
   - Reciter name displayed (should be "Ibrahim Al-Akdar")
   - Chapter name displayed (should be "Al-Fātihah")

4. **Check Console (Cmd + Shift + C):**
   ```
   ReciterService: Loaded 18 reciters
   ReciterService: Selected default reciter: Ibrahim Al-Akdar (ID: 1)
   ReciterService: Audio base URL: https://server6.mp3quran.net/akdr/
   QuranPlayer: Loading audio from URL: https://server6.mp3quran.net/akdr/001.mp3
   ```

## Common Mistakes to Avoid

### ❌ Wrong: Copying files
- Don't check "Copy items if needed" when adding files
- Files are already in the correct location

### ❌ Wrong: Wrong target
- Make sure "Example" target is selected when adding files
- Check "Target Membership" in File Inspector

### ❌ Wrong: Incorrect path
- Info.plist path should be `Example/Info.plist`
- NOT `Example/Example/Info.plist`
- NOT `Info.plist`

### ❌ Wrong: Missing entitlements
- Entitlements path should be `Example/Example.entitlements`
- Make sure the file is added to the project
- Check it appears in Project Navigator

### ❌ Wrong: Sandbox not configured
- Must enable "Outgoing Connections (Client)"
- Not just adding the capability

## Troubleshooting Build Errors

### Error: "Info.plist file not found"
**Solution:**
1. Check the path in Build Settings
2. Verify file exists at `Example/Example/Info.plist`
3. Make sure file is added to the project (visible in Project Navigator)

### Error: "Code signing entitlements file not found"
**Solution:**
1. Check the path in Build Settings
2. Verify file exists at `Example/Example/Example.entitlements`
3. Make sure file is added to the project

### Error: "Target membership" issues
**Solution:**
1. Select the file in Project Navigator
2. Open File Inspector (right sidebar, Cmd+Opt+1)
3. Check "Example" under "Target Membership"

### Build succeeds but still getting network errors
**Solution:**
1. Verify "Outgoing Connections (Client)" is checked
2. Clean build folder (Cmd+Shift+K)
3. Delete derived data:
   - Xcode → Preferences → Locations
   - Click arrow next to Derived Data path
   - Delete the "Example-..." folder
4. Rebuild

## Alternative: Using Xcode's GUI

If you prefer not to manually edit paths:

1. **For Info.plist:**
   - Select project in Project Navigator
   - Select target
   - Go to "Info" tab
   - The Info.plist should be automatically detected

2. **For Entitlements:**
   - Select project in Project Navigator
   - Select target
   - Go to "Signing & Capabilities"
   - Entitlements should be automatically detected if file is in project

## Verification Checklist

Before running the app, verify:

- [ ] `Info.plist` is visible in Project Navigator under Example/Example/
- [ ] `Example.entitlements` is visible in Project Navigator under Example/Example/
- [ ] Build Settings → Info.plist File = `Example/Info.plist`
- [ ] Build Settings → Code Signing Entitlements = `Example/Example.entitlements`
- [ ] Signing & Capabilities → App Sandbox is present
- [ ] Signing & Capabilities → Outgoing Connections (Client) is checked
- [ ] Build succeeds with no errors
- [ ] Console shows reciter loading logs
- [ ] Audio player UI shows no error banner

## Still Having Issues?

1. **Check the files exist:**
   ```bash
   ls -la Example/Example/Info.plist
   ls -la Example/Example/Example.entitlements
   ```

2. **Verify file contents:**
   ```bash
   cat Example/Example/Info.plist
   cat Example/Example/Example.entitlements
   ```

3. **Check Xcode version:**
   - Minimum: Xcode 15.0
   - Recommended: Latest stable version

4. **Try the automated script:**
   ```bash
   ./configure_example_project.sh
   ```

5. **See detailed troubleshooting:**
   - Read `../TROUBLESHOOTING.md`
   - Check console logs for specific errors
   - Open a GitHub issue with details

---

**Need help?** Open an issue with:
- Xcode version
- macOS version
- Console log output
- Screenshots of Build Settings and Signing & Capabilities

