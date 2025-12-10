# Govee Mac

<div align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013.7+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.0-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
  <br>
  <a href="https://github.com/JoKeks2023/smartlightsMac-ios-companion">
    <img src="https://img.shields.io/badge/📱_iOS_Companion_App-Available-brightgreen.svg" alt="iOS Companion">
  </a>
</div>

A powerful, native macOS app to control your smart lights with support for **multiple manufacturers** including Govee, Philips Hue, LIFX, and more. Supports multiple protocols: Cloud API, LAN (local network), HomeKit/Matter, and Home Assistant.

> **📱 iOS Companion App**: Control your lights from your iPhone! Check out the [iOS Companion App](https://github.com/JoKeks2023/smartlightsMac-ios-companion) that syncs with this Mac app via CloudKit and App Groups.

## ✨ Features

### 🌈 Multi-Manufacturer Support
- **Govee** - Native Cloud API and LAN control
- **Philips Hue** - ⭐ Native Hue Bridge API, HomeKit, or Home Assistant
- **WLED** - ⭐ Native REST API control
- **LIFX** - LAN protocol (partial), HomeKit, or Home Assistant  
- **Nanoleaf** - Via HomeKit
- **100+ Other Brands** - Via Home Assistant integration
- See [MANUFACTURER_INTEGRATION.md](MANUFACTURER_INTEGRATION.md) for complete guide

### 🎮 Multi-Protocol Support
- **☁️ Govee Cloud API** - Official API with full device support
- **🏠 LAN Control** - Automatic mDNS/Bonjour discovery for local network control (faster response)
- **💡 Philips Hue API** - ⭐ NEW: Native Hue Bridge discovery and control
- **🌈 WLED API** - ⭐ NEW: Direct control for WLED controllers
- **🔷 LIFX LAN** - ⭐ NEW: LIFX protocol support (work in progress)
- **🍎 HomeKit/Matter** - Native integration with Apple Home devices (Hue, LIFX, Nanoleaf, etc.)
- **🏡 Home Assistant** - REST API integration for advanced automation (supports all manufacturers)
- **🎭 DMX Control** - ArtNet and sACN receiver for professional lighting control

### 🎨 User Interface
- **Modern macOS Design** - Native SwiftUI interface with gradients and materials
- **Menu Bar Integration** - Quick access from the menu bar
- **Device Grouping** - Control multiple lights simultaneously
- **Live State Polling** - Automatic updates every 30 seconds

### 🔒 Security & Privacy
- **Keychain Storage** - API keys stored securely in macOS Keychain
- **No Analytics** - Your data stays on your device
- **Local Control** - LAN mode works without internet

### 📱 Widget Support (Optional)
- Notification Center widget with 3 sizes (Small, Medium, Large)
- At-a-glance device status
- Updates every 5 minutes

## 🚀 Getting Started

### Prerequisites
- macOS 13.7 (Ventura) or later
- Xcode 15.2 or later (or Xcode 15.0 minimum)
- Free Apple ID (no paid developer account needed!)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/govee-mac.git
   cd govee-mac
   ```

2. **Open in Xcode**
   ```bash
   cd "Govee Mac"
   open "Govee Mac.xcodeproj"
   ```

3. **Add your Apple ID** (one-time setup)
   - Xcode → Preferences → Accounts
   - Click "+" and sign in with your Apple ID
   - Close preferences

4. **Configure Signing**
   - Select the project in Xcode navigator
   - Go to "Signing & Capabilities" tab
   - Check "Automatically manage signing"
   - Select your Team (your Apple ID)

5. **Build & Run**
   - Press `⌘R` or click the Play button
   - App will launch with welcome screen

### First Run Setup

#### For Govee Users

1. **Govee Cloud API** (Recommended)
   - Get your API key from [Govee Developer Portal](https://developer.govee.com)
   - Enter it in the welcome screen or Settings

2. **LAN Discovery** (Optional, faster)
   - Enable "Prefer LAN when available" in Settings
   - Click Refresh to discover local devices

#### For Philips Hue Users

**Option 1: HomeKit Integration** (Easiest)
1. Add your Philips Hue Bridge to the **Home** app
2. In Govee Mac: Settings → Enable "HomeKit (Matter)"
3. Grant permission when prompted
4. Your Hue lights will appear automatically!

**Option 2: Home Assistant** (Most Powerful)
1. Install Home Assistant and add Hue integration
2. In Govee Mac: Settings → Enter HA URL and Long-Lived Access Token
3. Your Hue lights (and all other HA lights) will appear!

See [MANUFACTURER_INTEGRATION.md](MANUFACTURER_INTEGRATION.md) for detailed Philips Hue setup.

#### For Other Manufacturers (LIFX, Nanoleaf, etc.)

3. **HomeKit** (For HomeKit-compatible devices)
   - Add devices to **Home** app first
   - Enable "HomeKit (Matter)" in Settings
   - Grant permission when prompted
   - Your HomeKit devices will appear

4. **Home Assistant** (Universal solution for all manufacturers)
   - Enter your HA base URL (e.g., `https://homeassistant.local:8123`)
   - Generate a Long-Lived Access Token in HA
   - Paste token in Settings
   - Supports 100+ integrations: Hue, LIFX, TP-Link, Yeelight, Tuya, etc.

5. **DMX Control** (Optional, for professional lighting)
   - Enable "DMX Receiver" in Settings
   - Select protocol: ArtNet or sACN
   - Configure channel mappings for each device
   - See [DMX_SETUP.md](DMX_SETUP.md) for detailed setup guide

## 📖 Usage

### Controlling Devices
- Select a device from the sidebar
- Use controls: Power, Brightness, Color, Color Temperature
- Changes apply immediately

### Creating Groups
1. Click "Add Group" in toolbar
2. Enter group name
3. Select devices to include
4. Control all devices in group simultaneously

### Menu Bar Quick Controls
- Click the lightbulb icon in menu bar
- Toggle devices on/off
- Use group controls
- Open main window with ⌘O

### Keyboard Shortcuts
- `⌘R` - Refresh devices
- `⌘O` - Open main window
- `⌘,` - Open Settings
- `⌘Q` - Quit

### DMX Control
- Right-click any device → **Configure DMX**
- Set universe, start channel, and channel mode
- Use lighting software (QLC+, LightKey, etc.) to send DMX
- See [DMX_SETUP.md](DMX_SETUP.md) for complete guide

## 🏗️ Architecture

### Transport Priority
The app intelligently routes commands based on availability:
1. **LAN** - Preferred (fastest, local network)
2. **HomeKit** - Native iOS/macOS integration
3. **Home Assistant** - Flexible automation platform
4. **Cloud** - Govee official API (reliable fallback)

### Project Structure
```
Govee Mac/
├── GoveeModels.swift          # Models, stores, protocols, implementations
├── Govee_MacApp.swift         # App entry point
├── ContentView.swift          # Main UI
├── MenuBarController.swift    # Menu bar integration
├── Services/
│   └── APIKeyKeychain.swift   # Secure storage
├── GoveeWidget/               # Widget extension (optional)
└── Assets.xcassets/           # App icons and assets
```

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Commit your changes**
   ```bash
   git commit -m 'Add some amazing feature'
   ```
4. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```
5. **Open a Pull Request**

### Development Guidelines
- Follow Swift style guidelines
- Use SwiftUI for all UI components
- Add comments for complex logic
- Test with multiple device types
- Ensure backward compatibility

### Building Without Code Signing (for CI/CD)
```bash
xcodebuild -project "Govee Mac.xcodeproj" \
  -scheme "Govee Mac" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 💭 Developer Note

I'm sorry for not using the latest Xcode and Swift versions in this project. I can't afford a new Mac right now, so I'm working with what I have. The app is built with Xcode 15.2 and Swift 5.0, which are slightly older than the latest releases, but everything still works great! If you have a newer setup, feel free to upgrade the project settings—it should be compatible.

## 🐛 Known Limitations

- **LAN Discovery**: Not all Govee devices support LAN control
- **HomeKit**: Requires Matter-compatible Govee devices
- **Free Apple ID**: App can only run on your own Mac (not distributable)
- **Widget**: Requires manual Xcode target setup (see `WIDGET_SETUP.md`)

## 🔧 Troubleshooting

### LAN Discovery Not Finding Devices
- Ensure devices are on the same network
- Check firewall settings
- Use manual "Add Device" with IP address

### HomeKit Permission Denied
- Check System Settings → Privacy → HomeKit
- Re-enable in app Settings

### Widget Not Updating
- Verify App Groups entitlement: `group.com.govee.mac`
- Check Notification Center permissions

### API Rate Limits
- Govee Cloud API: 60 requests/minute
- Use LAN control for frequent updates

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Govee](https://www.govee.com) for their smart lighting products
- [Govee Developer API](https://developer.govee.com) documentation
- SwiftUI and HomeKit communities

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/govee-mac/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/govee-mac/discussions)
- **Govee API Docs**: [developer.govee.com](https://developer.govee.com)

## 🗺️ Roadmap

### Completed Features
- [x] DMX control (ArtNet/sACN)
- [x] HomeKit integration (supports Philips Hue, LIFX, Nanoleaf, etc.)
- [x] Home Assistant integration (supports all manufacturers)
- [x] Multi-manufacturer support
- [x] iOS companion app bridge (CloudKit + Local Network + Bluetooth sync)
- [x] iOS full remote control (devices, groups, settings)

### Planned Enhancements
- [ ] Native Philips Hue Bridge API (direct control without HomeKit/HA)
- [ ] LIFX LAN protocol implementation
- [ ] iOS companion app UI (bridge infrastructure and control API complete)
- [ ] Scenes and automation support
- [ ] Custom color presets
- [ ] Schedule/timer functionality
- [ ] Music sync integration
- [ ] Multi-window support
- [ ] Shortcuts app integration

## 📱 iOS Companion App - Complete Infrastructure

### 🎉 iOS App Available Now!

**[📱 SmartLights iOS Companion App →](https://github.com/JoKeks2023/smartlightsMac-ios-companion)**

The iOS companion app is ready to use! It provides a beautiful mobile interface to control your smart lights managed by this Mac app.

**Key Features:**
- 📱 **Remote Control**: Full device control from your iPhone
- ☁️ **iCloud Sync**: Automatic sync across all your devices
- 🔄 **Local Sync**: Instant sync via App Groups on the same device
- 🎨 **Full Controls**: Power, brightness, RGB color, color temperature
- 👥 **Device Groups**: Organize and control multiple devices together

**Get Started:**
1. Visit the [iOS Companion Repository](https://github.com/JoKeks2023/smartlightsMac-ios-companion)
2. Clone and build the iOS app in Xcode
3. Launch both apps - they'll automatically sync!

---

### For iOS Developers

The macOS app includes **complete infrastructure** for iOS companion app development with **full control capabilities**:

#### Three Sync Methods
- ☁️ **CloudKit** - Internet-based sync (works anywhere)
- 📡 **Local Network** - Fast sync over WiFi (< 100ms latency)
- 📶 **Bluetooth** - Close proximity sync (works offline)
- 📦 **App Groups** - Instant same-device sharing

#### Full Control API
iOS app can control **everything**:
- ✅ Device power, brightness, color, color temperature
- ✅ Group creation, management, and control
- ✅ Settings synchronization (all preferences)
- ✅ Trigger device discovery from macOS app
- ✅ Real-time bidirectional sync

#### Developer Resources

**📘 [IOS_BRIDGE_DEVELOPER_GUIDE.md](IOS_BRIDGE_DEVELOPER_GUIDE.md)** - Complete guide (1000+ lines)
- Step-by-step setup instructions
- Production-ready code examples
- Device control views with sliders and color pickers
- Group management UI
- Settings sync implementation
- Best practices and troubleshooting

**📄 [IOS_COMPANION_GUIDE.md](IOS_COMPANION_GUIDE.md)** - Integration reference
- Architecture overview
- Sync method details
- Connection management

#### Quick Start for iOS Developers

```swift
// 1. Copy 4 files to iOS project
// 2. Configure capabilities (App Groups, iCloud, Bluetooth)
// 3. Initialize in your app

@main
struct SmartLightsApp: App {
    @StateObject private var syncManager = UnifiedSyncManager.shared
    @StateObject private var controlClient: RemoteControlClient
    
    init() {
        let sync = UnifiedSyncManager.shared
        _controlClient = StateObject(wrappedValue: RemoteControlClient(syncManager: sync))
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(syncManager)
                .environmentObject(controlClient)
        }
    }
}

// 4. Control devices
try await controlClient.setDevicePower(deviceID: "123", on: true)
try await controlClient.setDeviceBrightness(deviceID: "123", value: 75)
try await controlClient.createGroup(name: "Living Room", memberIDs: ["123", "456"])
```

**Ready to build in under a day** with the complete guide and code examples!

## 🔗 Related Projects

### Official Companion Apps

- **[📱 SmartLights iOS Companion](https://github.com/JoKeks2023/smartlightsMac-ios-companion)** - Remote control your lights from iPhone
  - Full device control interface
  - Syncs via iCloud (CloudKit) and App Groups
  - Native SwiftUI design
  - Works seamlessly with this macOS app

### Integration Partners

- **[Govee Developer API](https://developer.govee.com)** - Official Govee API documentation
- **[Home Assistant](https://home-assistant.io)** - Universal smart home platform
- **[Philips Hue](https://developers.meethue.com)** - Hue Bridge API documentation
- **[WLED](https://kno.wled.ge)** - LED controller firmware

## ⭐ Star History

If you find this project useful, please give it a star!

---

Made with ❤️ for the smart lighting community
