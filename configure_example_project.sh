#!/bin/bash

# Script to configure the Example project with necessary permissions
# This script helps set up the Xcode project for network access

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$PROJECT_DIR/Example"
EXAMPLE_PROJECT="$EXAMPLE_DIR/Example.xcodeproj"
PBXPROJ="$EXAMPLE_PROJECT/project.pbxproj"

echo "🔧 Configuring Example project for network access..."
echo "📁 Project directory: $PROJECT_DIR"

# Check if project exists
if [ ! -f "$PBXPROJ" ]; then
    echo "❌ Error: Could not find Example.xcodeproj"
    echo "   Expected location: $EXAMPLE_PROJECT"
    exit 1
fi

# Backup the project file
echo "📦 Creating backup of project.pbxproj..."
cp "$PBXPROJ" "$PBXPROJ.backup"

# Check if Info.plist exists
if [ ! -f "$EXAMPLE_DIR/Example/Info.plist" ]; then
    echo "❌ Error: Info.plist not found at $EXAMPLE_DIR/Example/Info.plist"
    echo "   Please ensure the file exists before running this script."
    exit 1
fi

# Check if entitlements file exists
if [ ! -f "$EXAMPLE_DIR/Example/Example.entitlements" ]; then
    echo "❌ Error: Example.entitlements not found at $EXAMPLE_DIR/Example/Example.entitlements"
    echo "   Please ensure the file exists before running this script."
    exit 1
fi

echo "✅ Found Info.plist and Example.entitlements"
echo ""
echo "⚠️  Manual Steps Required:"
echo ""
echo "1. Open the project in Xcode:"
echo "   open \"$EXAMPLE_PROJECT\""
echo ""
echo "2. Add files to the project:"
echo "   - Right-click on 'Example' group in Project Navigator"
echo "   - Select 'Add Files to Example...'"
echo "   - Navigate to Example/Example/ and select:"
echo "     • Info.plist"
echo "     • Example.entitlements"
echo "   - Uncheck 'Copy items if needed'"
echo "   - Click 'Add'"
echo ""
echo "3. Configure Build Settings:"
echo "   - Select the 'Example' target"
echo "   - Go to 'Build Settings' tab"
echo "   - Search for 'Info.plist File'"
echo "   - Set to: Example/Info.plist"
echo "   - Search for 'Code Signing Entitlements'"
echo "   - Set to: Example/Example.entitlements"
echo ""
echo "4. Configure Signing & Capabilities:"
echo "   - Select the 'Example' target"
echo "   - Go to 'Signing & Capabilities' tab"
echo "   - Under 'App Sandbox', enable 'Outgoing Connections (Client)'"
echo ""
echo "5. Clean and rebuild:"
echo "   - Press Cmd+Shift+K to clean"
echo "   - Press Cmd+B to build"
echo "   - Press Cmd+R to run"
echo ""
echo "📚 For more details, see TROUBLESHOOTING.md"
echo ""
echo "💾 A backup of your project file has been saved to:"
echo "   $PBXPROJ.backup"
echo ""

# Open Xcode if available
if command -v open &> /dev/null; then
    read -p "Would you like to open the project in Xcode now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "$EXAMPLE_PROJECT"
        echo "✅ Opened project in Xcode"
    fi
fi

echo ""
echo "✨ Configuration guide complete!"

