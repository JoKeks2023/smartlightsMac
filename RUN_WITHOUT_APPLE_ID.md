# 🚀 Running Govee Mac WITHOUT Apple ID

## Quick Fix (2 minutes in Xcode)

You have Xcode open with 15 errors - these are ALL signing errors, not code errors!

### Solution: Disable Signing in Xcode

1. **In Xcode:**
   - Click on the **Govee Mac** project (blue icon) in the left sidebar
   - Select the **Govee Mac** target (not the project)
   - Click **Signing & Capabilities** tab
   
2. **Disable Signing:**
   - **UNCHECK** ☐ "Automatically manage signing"
   - Under **Signing Certificate**, select **"Sign to Run Locally"**
   - Or set **Signing Certificate** to **"None"**

3. **Build:**
   - Press **⌘B** (or Product → Build)
   - **All 15 errors should disappear!** ✅

4. **Run:**
   - Press **⌘R** (or Product → Run)
   - App will launch! 🎉

## Why This Works

The 15 errors are all about code signing:
- "No provisioning profile"
- "No signing certificate"  
- "Team not configured"

**You don't need any of this for development!**

By disabling signing:
- App runs on YOUR Mac only (perfect for personal use)
- No Apple ID password needed
- No provisioning profiles needed
- Works immediately

## If You See "App is damaged" When Running

This is a macOS security message. Fix it:

```bash
xattr -cr "/Path/To/Govee Mac.app"
```

Or in Terminal (easier):
1. Go to Build Products folder
2. Right-click on **Govee Mac.app**
3. Choose **"Open"** (not double-click)
4. Click **"Open"** in the dialog
5. App will run!

## Alternative: Command Line Build (No Xcode Changes Needed)

If you prefer, you can build from Terminal without touching Xcode settings:

```bash
cd "/Users/jorisconrad/Documents/Govee Mac Swift/Govee Mac"

xcodebuild -project "Govee Mac.xcodeproj" \
  -scheme "Govee Mac" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

This builds the app without any signing.

**To run the built app:**
```bash
open "build/Debug/Govee Mac.app"
```

## Troubleshooting

### "Build succeeded but app won't launch"

**Solution:** Right-click the .app → **Open** (bypass Gatekeeper)

### "Still getting signing errors"

**Solution:** Make sure you UNCHECKED "Automatically manage signing"

### "15 errors still there"

**Solution:** 
1. Product → Clean Build Folder (⌘⇧K)
2. Close and reopen Xcode
3. Try building again

## What About Distributing to Others?

**Without signing, the app only runs on your Mac.**

For distribution:
- Add your Apple ID later (when you have password)
- Or contributors can build with their own Apple IDs
- Or someone with paid account can notarize for distribution

**For now: Just disable signing and use it!** ✅

## Quick Checklist

- [ ] Xcode is open
- [ ] Project selected in left sidebar  
- [ ] Target "Govee Mac" selected
- [ ] Signing & Capabilities tab open
- [ ] "Automatically manage signing" is UNCHECKED ☐
- [ ] Press ⌘B to build
- [ ] Press ⌘R to run

**That's it! The app will work without any Apple ID.** 🎉

---

**TL;DR:** Uncheck "Automatically manage signing" in Xcode → Build → Run → Done! ✅
