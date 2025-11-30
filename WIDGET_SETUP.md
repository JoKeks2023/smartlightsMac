# Widget Setup Instructions

The widget files have been created, but you need to manually add the Widget Extension target in Xcode.

## Adding the Widget Extension

### Option 1: Manual Target Creation (Recommended)

1. **Open Xcode**
   - Open `Govee Mac.xcodeproj`

2. **Add Widget Extension Target**
   - File → New → Target
   - Choose "Widget Extension" under macOS
   - Click Next
   - Product Name: `GoveeWidget`
   - Organization Identifier: (your identifier)
   - Uncheck "Include Configuration Intent"
   - Click Finish
   - Choose "Activate" when asked about the scheme

3. **Replace Generated Code**
   - Delete the generated `GoveeWidget.swift` file
   - Add the existing `GoveeWidget/GoveeWidget.swift` to the target
   - Or copy the content from the created file to the generated one

4. **Configure App Groups**
   - Select the GoveeWidget target
   - Go to Signing & Capabilities
   - Click "+ Capability"
   - Add "App Groups"
   - Enable `group.com.govee.mac`
   - Do the same for the main Govee Mac target

5. **Share GoveeDevice Model**
   - Select `GoveeModels.swift` in Project Navigator
   - In File Inspector (right panel), check both targets:
     - ✅ Govee Mac
     - ✅ GoveeWidget
   - This allows the widget to use the GoveeDevice struct

6. **Build and Run**
   - Select the GoveeWidget scheme
   - Build and run
   - The widget will appear in the Notification Center editor

### Option 2: Use Widget Without Extension (Simplified)

If you don't need the widget right away, the app works perfectly without it!
All other features (LAN, HomeKit, HA, menu bar, etc.) are fully functional.

To add the widget later:
- Follow the steps above when you're ready
- The widget code is already written and ready to use

## Widget Features

Once configured, the widget provides:

- **Small Widget**: One device with status
- **Medium Widget**: Three devices overview
- **Large Widget**: Six devices with full details
- Updates every 5 minutes automatically
- Shared data with main app via App Groups

## Troubleshooting

### Widget Not Showing Data
- Ensure App Groups is enabled in both targets
- Check group ID is exactly: `group.com.govee.mac`
- Run the main app first to populate device data

### Build Errors in Widget
- Verify GoveeModels.swift is added to both targets
- Check that DeviceColor and GoveeDevice are accessible
- Ensure import statements are correct

### Widget Not Updating
- Widgets update based on Timeline policy (5 minutes)
- Force refresh by removing and re-adding widget
- Check Console.app for widget extension logs

## Alternative: Skip Widget

The widget is optional! All core functionality works without it:
- ✅ LAN auto-discovery
- ✅ HomeKit integration
- ✅ Home Assistant support
- ✅ State polling
- ✅ Keychain security
- ✅ Menu bar controls
- ✅ Full device control UI

You can always add the widget extension later when you have time.

---

**Current Status:**
- Widget code: ✅ Written and ready
- Widget target: ⏳ Needs manual Xcode configuration
- Main app: ✅ Fully functional without widget

**Recommendation:** Test the main app first, add widget when you want it!
