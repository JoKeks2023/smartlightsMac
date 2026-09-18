# Widget Setup

Updated 2026-09-18 (T-0001 overhaul): the `GoveeWidgetExtension` target now
exists in `Govee Mac.xcodeproj` and is embedded in the app automatically —
the manual target-creation steps that used to live in this file are no
longer needed. Everything below is what's actually true now.

## What's there

- `GoveeWidgetExtension` is a WidgetKit app extension target, embedded in
  `Govee Mac.app/Contents/PlugIns` on every build.
- `GoveeWidget/GoveeWidget.swift` — the widget UI (Small/Medium/Large).
- `GoveeWidget/GoveeWidgetExtension.entitlements` — grants the
  `group.com.govee.mac` App Group, matching the main app's entitlement.
- `Govee Mac/Core/Models.swift` (which defines `GoveeDevice`/`DeviceColor`)
  is a member of **both** targets, so the widget decodes the exact same
  type the main app writes — no duplicated model definitions.
- `DeviceStore.saveDevices()` (`Govee Mac/Core/Stores.swift`) mirrors the
  device cache into the `group.com.govee.mac` UserDefaults suite on every
  save, which is what the widget reads.

## Using it

1. Build and run the main app at least once (so it has cached devices to
   share).
2. Open Notification Center → Edit Widgets (or the widget gallery), search
   "Govee Lights", and add it in your preferred size.
3. The widget refreshes on a 5-minute timeline. If it shows "No devices",
   run the main app again to refresh its device list.

## Known gap / not yet verified

This was built and build-verified (the `.appex` is produced and embedded,
`xcodebuild` succeeds) but **not yet confirmed in a live widget gallery** —
Debug builds run from DerivedData don't always register with
`pluginkit`/Notification Center the way a normally-signed, Xcode-run build
does. If the widget doesn't appear:
- Run the app directly from Xcode (⌘R) rather than via `xcodebuild`, once,
  so macOS registers the extension normally.
- Check Signing & Capabilities on both targets — `DEVELOPMENT_TEAM` should
  be set (it inherited your existing team automatically when the target was
  created).
- Confirm both targets show the App Groups capability with
  `group.com.govee.mac` checked.
