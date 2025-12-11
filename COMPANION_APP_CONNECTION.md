# Companion App Connection Guide

## Overview

This macOS app works seamlessly with an official iOS companion app. The two repositories are designed to work together as a unified smart lighting control system.

## Repository Links

### macOS App (This Repository)
- **Repository**: https://github.com/JoKeks2023/smartlightsMac
- **Purpose**: Main application for controlling smart lights on macOS
- **Features**: Direct device control, multiple protocol support, LAN discovery, HomeKit integration

### iOS Companion App
- **Repository**: https://github.com/JoKeks2023/smartlightsMac-ios-companion
- **Purpose**: Remote control interface for iPhone/iPad
- **Features**: View and control devices managed by the Mac app, sync via CloudKit and App Groups

## How They Connect

### Sync Methods

Both apps share data through multiple transport methods:

1. **App Groups** (Same Device)
   - Container ID: `group.com.govee.mac`
   - Instant sync between iOS and macOS apps on the same device
   - Perfect for iPad/Mac combos

2. **CloudKit** (Cross-Device)
   - Container: `iCloud.com.govee.smartlights`
   - Syncs device states, groups, and settings across all devices
   - Works anywhere with internet connection

3. **Local Network** (Future)
   - Fast local WiFi sync via Bonjour/mDNS
   - Sub-100ms latency for real-time control

4. **Bluetooth** (Future)
   - Close-proximity sync when offline
   - No internet or WiFi required

### Architecture

```
┌─────────────────────────────────────────────┐
│           iOS Companion App                 │
│  (UI + Remote Control Interface)            │
└──────────────┬──────────────────────────────┘
               │
               │ Sync via:
               │ • App Groups (local)
               │ • CloudKit (remote)
               │ • Local Network (WiFi)
               │ • Bluetooth (offline)
               │
┌──────────────┴──────────────────────────────┐
│         macOS SmartLights App               │
│  (Device Discovery + Command Execution)     │
├─────────────────────────────────────────────┤
│  • Govee Cloud API                          │
│  • LAN (Local Network)                      │
│  • HomeKit/Matter                           │
│  • Home Assistant                           │
│  • DMX Control                              │
└─────────────────────────────────────────────┘
```

## Getting Started

### For End Users

1. **Install the macOS app** (this repository)
   - Clone and build in Xcode
   - Configure your smart light integrations (Govee API, HomeKit, etc.)
   - Discover and control your devices

2. **Install the iOS companion app**
   - Visit https://github.com/JoKeks2023/smartlightsMac-ios-companion
   - Clone and build in Xcode
   - Launch both apps - they'll automatically sync!

### For Developers

See the comprehensive developer guides:

- **[IOS_BRIDGE_DEVELOPER_GUIDE.md](IOS_BRIDGE_DEVELOPER_GUIDE.md)** - Complete implementation guide (1000+ lines)
- **[IOS_COMPANION_GUIDE.md](IOS_COMPANION_GUIDE.md)** - Integration architecture overview

## Key Features of the Connection

### What iOS App Can Do
- ✅ View all devices discovered by the Mac app
- ✅ Control device power, brightness, color, color temperature
- ✅ Create and manage device groups
- ✅ View and edit settings
- ✅ Sync changes across all your devices
- ✅ Work offline with cached data

### What macOS App Does
- ✅ Discovers devices via all protocols (Cloud, LAN, HomeKit, HA)
- ✅ Executes commands to actual smart lights
- ✅ Monitors iOS app changes and applies them
- ✅ Updates device states back to shared storage
- ✅ Handles all API credentials and authentication

## Data Flow Example

Here's how controlling a light from iPhone works:

1. **User Action**: User taps power button on iPhone
2. **iOS App**: Writes desired state to App Groups/CloudKit
3. **macOS App**: Detects change via sync manager
4. **macOS App**: Sends command to device (via Govee API, LAN, HomeKit, etc.)
5. **macOS App**: Updates device state in shared storage
6. **iOS App**: Reads updated state and refreshes UI

Total latency: 
- Same device (App Groups): < 100ms
- Different devices (CloudKit): 1-3 seconds
- Local Network (future): < 50ms

## Security & Privacy

Both apps follow the same security principles:

- **No Analytics**: No telemetry or tracking in either app
- **Keychain Storage**: API credentials stored securely on Mac only
- **Encrypted Sync**: CloudKit uses end-to-end encryption
- **Local Control**: Works offline with App Groups
- **Privacy First**: All data stays within your Apple devices

## Troubleshooting

### Apps Not Syncing

**Same Device (App Groups)**:
1. Verify both apps have App Groups capability enabled
2. Check both use the same group ID: `group.com.govee.mac`
3. Restart both apps

**Different Devices (CloudKit)**:
1. Ensure iCloud is enabled in System Settings
2. Sign in to the same Apple ID on both devices
3. Enable iCloud for both apps
4. Check internet connection

### iOS App Shows No Devices

1. Make sure macOS app has discovered devices first
2. Check that macOS app is running
3. Try manual refresh in iOS app
4. Verify sync is enabled in settings

## Roadmap

### Current Status
- ✅ App Groups sync (implemented)
- ✅ CloudKit sync (implemented)
- ✅ Full device control API (implemented)
- ✅ Group management (implemented)
- ✅ Settings sync (implemented)

### Coming Soon
- ⏳ Real-time push notifications
- ⏳ iOS widgets
- ⏳ Shortcuts integration
- ⏳ Siri support
- ⏳ Local Network sync (Bonjour)
- ⏳ Bluetooth sync

## Contributing

Contributions to both repositories are welcome! When contributing:

1. Test changes with both apps running
2. Verify sync works correctly
3. Update documentation in both repositories
4. Follow Swift/SwiftUI best practices
5. Maintain backward compatibility

## Support

- **Issues**: Report issues in the relevant repository
  - macOS app issues: https://github.com/JoKeks2023/smartlightsMac/issues
  - iOS app issues: https://github.com/JoKeks2023/smartlightsMac-ios-companion/issues
- **Discussions**: Use GitHub Discussions for questions and ideas
- **Documentation**: Read the comprehensive guides in both repositories

---

**Two apps, one ecosystem. Control your smart lights from anywhere!** 🌈💡
