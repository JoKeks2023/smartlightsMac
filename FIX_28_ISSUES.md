# Fix Remaining 28 Issues in Xcode

## Quick Fix Steps

### 1. Remove Old Files from Compile Sources

In Xcode:
1. Select the **Govee Mac** project in Navigator
2. Select the **Govee Mac** target
3. Go to **Build Phases** tab
4. Expand **Compile Sources** (should show all .swift files)
5. **Remove** these files if present (look for files with these patterns):
   - Any file ending in `_OLD.swift`
   - Any file ending in `_BROKEN.swift`
   - Any file ending in `_BACKUP.swift`
   - Any file ending in `_CORRUPT.swift`
   - Any file ending in `_MIXED.swift`
   - Any file ending in `_CLEAN.swift`
   - Any file ending in `_FIXED.swift`

**Files to KEEP** (these should be the ONLY ones in Compile Sources):
- ✅ `GoveeModels.swift`
- ✅ `ContentView.swift`
- ✅ `Govee_MacApp.swift`
- ✅ `MenuBarController.swift`
- ✅ `Services/APIKeyKeychain.swift` (if present)
- ✅ `Services/StubServices.swift` (if present)

### 2. Clean Build Folder

1. In Xcode menu: **Product → Clean Build Folder** (⇧⌘K)
2. Wait for it to complete

### 3. Rebuild

1. Press **⌘B** to build
2. All errors should be gone!

## If You Still See 28 Issues

### Check for Duplicate Type Definitions

Run this in Terminal to find duplicates:

```bash
cd "/Users/jorisconrad/Documents/Govee Mac Swift/Govee Mac/Govee Mac"

# Find duplicate ContentView
grep -l "struct ContentView" *.swift Services/*.swift 2>/dev/null

# Find duplicate WelcomeView  
grep -l "struct WelcomeView" *.swift Services/*.swift 2>/dev/null

# Find duplicate SettingsView
grep -l "struct SettingsView" *.swift Services/*.swift 2>/dev/null

# Find duplicate GoveeDevice
grep -l "struct GoveeDevice" *.swift Models/*.swift 2>/dev/null

# Find duplicate @main
grep -l "@main" *.swift 2>/dev/null
```

**Expected results:**
- `struct ContentView`: Should ONLY be in `ContentView.swift`
- `struct WelcomeView`: Should ONLY be in `ContentView.swift`
- `struct SettingsView`: Should ONLY be in `ContentView.swift`
- `struct GoveeDevice`: Should ONLY be in `GoveeModels.swift`
- `@main`: Should ONLY be in `Govee_MacApp.swift`

If you find duplicates, **delete or rename** the extra files.

### Common Issues and Fixes

#### Issue: "Invalid redeclaration of 'ContentView'"
**Fix:** Remove `ContentView_FIXED_OLD.swift` and `ContentView_BROKEN_OLD.swift` from project

#### Issue: "Invalid redeclaration of 'GoveeDevice'"
**Fix:** Remove files in `Models/` folder - everything is now in `GoveeModels.swift`

#### Issue: "Multiple @main entry points"
**Fix:** Remove `Govee_MacApp_BACKUP_OLD.swift` from project

#### Issue: "Cannot find 'APIKeyKeychain' in scope"
**Fix:** This is now defined in `GoveeModels.swift` - no external file needed

### Remove Files Completely from Xcode

To completely remove a file from the project:

1. Right-click the file in Project Navigator
2. Choose **Delete**
3. Select **"Move to Trash"** (not just "Remove Reference")

Do this for ALL files ending in `_OLD`, `_BROKEN`, `_BACKUP`, `_CORRUPT`

## Verification Script

Run this to verify your project is clean:

```bash
cd "/Users/jorisconrad/Documents/Govee Mac Swift/Govee Mac/Govee Mac"

echo "=== Checking for problematic files ==="
ls -1 *_OLD.swift *_BROKEN.swift *_BACKUP*.swift *_CORRUPT*.swift 2>/dev/null && echo "⚠️  Found old files! Delete them." || echo "✅ No old files found"

echo ""
echo "=== Checking for duplicate @main ==="
grep -l "@main" *.swift 2>/dev/null | wc -l | xargs -I {} bash -c 'if [ {} -eq 1 ]; then echo "✅ Only one @main"; else echo "⚠️  Multiple @main found!"; fi'

echo ""
echo "=== Active Swift files ==="
ls -1 *.swift Services/*.swift 2>/dev/null | grep -v "_OLD" | grep -v "_BROKEN" | grep -v "_BACKUP" | grep -v "_CORRUPT"
```

Expected output:
```
=== Checking for problematic files ===
✅ No old files found

=== Checking for duplicate @main ===
✅ Only one @main

=== Active Swift files ===
ContentView.swift
GoveeModels.swift
Govee_MacApp.swift
MenuBarController.swift
Services/APIKeyKeychain.swift
Services/StubServices.swift
```

## Still Having Issues?

If you're still seeing 28 errors after trying the above:

1. **Close Xcode completely**
2. Run this terminal command:
   ```bash
   cd "/Users/jorisconrad/Documents/Govee Mac Swift/Govee Mac"
   rm -rf ~/Library/Developer/Xcode/DerivedData/Govee*
   ```
3. **Reopen Xcode**
4. **Clean Build Folder** (⇧⌘K)
5. **Build** (⌘B)

## Nuclear Option: Fresh Project

If nothing else works, here's how to create a clean project:

1. In Xcode: File → New → Project → macOS → App
2. Name it "Govee Mac Fresh"
3. Copy ONLY these files into the new project:
   - `GoveeModels.swift`
   - `ContentView.swift`
   - `Govee_MacApp.swift`
   - `MenuBarController.swift`
   - `Services/APIKeyKeychain.swift`
4. Add entitlements manually
5. Build (should work immediately)

---

**The 28 issues are likely:**
- 15-20 code signing errors (ignore these for local development)
- 5-8 duplicate type definition errors (fix by removing old files)
- 2-3 warnings (safe to ignore)

**After cleaning up old files from Compile Sources, you should have 0-2 warnings max!**
