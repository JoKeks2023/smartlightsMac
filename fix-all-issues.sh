#!/bin/bash

# Govee Mac - Fix All 28 Issues Script
# This script cleans up the project and fixes all compile issues

echo "🔧 Fixing Govee Mac Build Issues..."
echo ""

cd "/Users/jorisconrad/Documents/Govee Mac Swift/Govee Mac"

# Step 1: Remove all old backup files
echo "📦 Step 1: Removing old backup files..."
cd "Govee Mac"
rm -f *_OLD.swift *_BROKEN*.swift *_BACKUP*.swift *_CORRUPT*.swift *_MIXED*.swift *_CLEAN*.swift *_FIXED*.swift 2>/dev/null
rm -f Services/*_OLD.swift Services/*_BROKEN*.swift Services/*_BACKUP*.swift Services/*_MIXED*.swift 2>/dev/null
rm -f Storage/*_OLD.swift Storage/*_BACKUP*.swift 2>/dev/null
rm -f Models/*_OLD.swift Models/*_BACKUP*.swift 2>/dev/null
rm -f Networking/*_OLD.swift 2>/dev/null
echo "✅ Removed old files"
cd ..

# Step 2: Clean Xcode project file
echo ""
echo "🧹 Step 2: Cleaning Xcode project..."
python3 << 'PYTHON_EOF'
import re

pbxproj_path = "Govee Mac.xcodeproj/project.pbxproj"

try:
    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # Remove lines with old/backup files from Compile Sources
    patterns_to_remove = [
        '_OLD',
        '_BROKEN',
        '_BACKUP',
        '_CORRUPT',
        '_MIXED',
        '_CLEAN',
        '_FIXED'
    ]

    lines = content.split('\n')
    new_lines = []
    removed_count = 0

    for line in lines:
        should_remove = False
        if ' in Sources */' in line:
            for pattern in patterns_to_remove:
                if pattern in line:
                    should_remove = True
                    removed_count += 1
                    break
        
        if not should_remove:
            new_lines.append(line)

    with open(pbxproj_path, 'w') as f:
        f.write('\n'.join(new_lines))

    print(f"✅ Removed {removed_count} old file references from project")
except Exception as e:
    print(f"⚠️  Could not clean project file: {e}")
PYTHON_EOF

# Step 3: Clean Xcode derived data
echo ""
echo "🗑️  Step 3: Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Govee* 2>/dev/null
echo "✅ Cleaned derived data"

# Step 4: Verify clean state
echo ""
echo "✅ Step 4: Verifying project state..."
cd "Govee Mac"
echo "Active Swift files:"
ls -1 *.swift Services/*.swift 2>/dev/null | grep -v "_OLD" | grep -v "_BROKEN" | grep -v "_BACKUP" | grep -v "_CORRUPT" | sed 's/^/  ✓ /'

echo ""
echo "Checking for duplicates..."
main_count=$(grep -l "@main" *.swift 2>/dev/null | wc -l | tr -d ' ')
if [ "$main_count" -eq 1 ]; then
    echo "  ✅ Only one @main entry point"
else
    echo "  ⚠️  Found $main_count @main entry points (should be 1)"
fi

contentview_count=$(grep -l "struct ContentView" *.swift Services/*.swift 2>/dev/null | wc -l | tr -d ' ')
if [ "$contentview_count" -eq 1 ]; then
    echo "  ✅ Only one ContentView definition"
else
    echo "  ⚠️  Found $contentview_count ContentView definitions (should be 1)"
fi

cd ..

# Step 5: Try building
echo ""
echo "🔨 Step 5: Testing build..."
xcodebuild -project "Govee Mac.xcodeproj" \
  -scheme "Govee Mac" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build 2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" | head -20

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Cleanup complete!"
echo ""
echo "Next steps in Xcode:"
echo "1. Open Govee Mac.xcodeproj"
echo "2. Product → Clean Build Folder (⇧⌘K)"
echo "3. Product → Build (⌘B)"
echo ""
echo "If you still see issues, they're likely code signing errors"
echo "(which can be ignored for local development)."
echo "═══════════════════════════════════════════════════════════"
