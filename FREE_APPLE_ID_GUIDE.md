# Running Without Paid Apple Developer Account

Good news! You **don't need a paid Apple Developer account** ($99/year) to build and run Govee Mac. A free Apple ID is all you need!

## ✅ What Works with Free Apple ID

- ✅ Build and run on your own Mac
- ✅ Full debugging in Xcode
- ✅ All app features work perfectly
- ✅ HomeKit integration (on your Mac only)
- ✅ Keychain storage
- ✅ Menu bar icon
- ✅ State polling and all protocols

## ⚠️ Limitations of Free Apple ID

- ❌ Can't distribute to others (App Store or direct download)
- ❌ Can't notarize for Gatekeeper
- ❌ Limited to 3 active apps at a time per device
- ❌ Certificates expire every 7 days (auto-renewed when you run)
- ⏱️ Widget extension requires manual re-signing every 7 days

**For personal use, these limitations don't matter!**

## 🚀 Setup Instructions

### 1. Add Your Apple ID to Xcode (One-Time)

1. Open Xcode
2. Go to **Xcode → Preferences** (or **Settings** on newer macOS)
3. Click the **Accounts** tab
4. Click the **+** button in bottom-left
5. Choose **Apple ID**
6. Sign in with your Apple ID
7. Close preferences

That's it! Xcode will now manage signing automatically.

### 2. Configure Project Signing

1. Open `Govee Mac.xcodeproj` in Xcode
2. Select the project in Navigator (left sidebar)
3. Select **Govee Mac** target
4. Go to **Signing & Capabilities** tab
5. Check ✅ **Automatically manage signing**
6. Under **Team**, select your Apple ID (shown as "Your Name (Personal Team)")
7. The **Signing Certificate** should show "Apple Development"

**Bundle Identifier Note:**
If you see an error about bundle identifier, Xcode will suggest a unique one. Accept it - this won't affect functionality.

### 3. Build and Run

Press **⌘R** or click the Play button. The app will:
1. Compile
2. Sign with your free certificate
3. Launch on your Mac

**First time:** macOS may ask for permission to run an app from an unidentified developer. Click "Open" to allow.

## 🔄 Certificate Renewal

Free certificates expire after 7 days. To renew:

**Automatic (Recommended):**
Just build and run again in Xcode (⌘R). Xcode automatically renews the certificate.

**Manual (if needed):**
1. Xcode → Preferences → Accounts
2. Select your Apple ID
3. Click "Manage Certificates"
4. Click "+" → "Apple Development"
5. Close and rebuild

## 🎯 Open Source Development

### Contributing Without Paid Account

You can contribute to the project even with a free Apple ID:

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Build with your Apple ID** (as above)
4. **Make changes** and test
5. **Commit and push** to your fork
6. **Open a Pull Request**

Your code contributions don't require signing at all - only your local build does!

### CI/CD Without Signing

For automated builds (GitHub Actions, etc.), the project can build without signing:

```bash
xcodebuild -project "Govee Mac.xcodeproj" \
  -scheme "Govee Mac" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

This builds the app for testing only (can't run, but verifies code compiles).

## 🐛 Troubleshooting

### "No signing certificate found"

**Solution:** Add your Apple ID in Xcode Preferences → Accounts

### "Failed to register bundle identifier"

**Solution:** Change bundle ID in project settings:
1. Select project → Signing & Capabilities
2. Change `joconpany.Govee-Mac` to `com.yourname.GoveeMac`
3. Xcode will suggest a unique ID - accept it

### "Revoke certificate" error

**Solution:** 
1. Xcode → Preferences → Accounts
2. Right-click your Apple ID → View Details
3. Click "Reset" or "Revoke Certificate"
4. Rebuild project

### App stops working after 7 days

**Normal behavior** - Free certificates expire weekly.

**Solution:** Open in Xcode and run again (⌘R). Takes 10 seconds to re-sign.

### Multiple apps won't sign

**Free Apple ID limit:** Only 3 apps can be signed at once.

**Solution:** Revoke unused app certificates:
1. Xcode → Preferences → Accounts → Manage Certificates
2. Delete old certificates
3. Rebuild this app

## 📱 Widget Limitations

The notification center widget requires a widget extension target. With a free Apple ID:

- ✅ Widget works fine on your Mac
- ⚠️ Needs re-signing every 7 days (along with main app)
- ⚠️ More setup complexity

**Recommendation:** Skip the widget if you don't need it. All other features work perfectly!

## 🎓 When to Upgrade to Paid Account

Consider paying for Apple Developer Program ($99/year) if you want to:

- Distribute the app to others
- Publish on Mac App Store
- Notarize for wider distribution
- Use longer certificate validity
- Beta test with TestFlight

**For personal use and open source development, FREE is perfect!**

## 🌟 Alternative: Community Builds

If someone with a paid account builds and notarizes the app, others can download and use it without any Apple ID. This is common for open source macOS apps.

**Contributing is still open to everyone** - you don't need a paid account to write code!

## ✅ Summary

| Feature | Free Apple ID | Paid Developer |
|---------|---------------|----------------|
| Build & Run Locally | ✅ Yes | ✅ Yes |
| Full Functionality | ✅ Yes | ✅ Yes |
| Debugging | ✅ Yes | ✅ Yes |
| Distribute to Others | ❌ No | ✅ Yes |
| Certificate Validity | 7 days | 1 year |
| Cost | **FREE** | $99/year |

## 🚀 You're Ready!

With a free Apple ID, you can:
- Build and use Govee Mac on your Mac
- Develop new features
- Contribute to the project
- Share code on GitHub

The app works identically whether you use a free or paid account. The only difference is distribution to others.

**Start coding!** 🎉
