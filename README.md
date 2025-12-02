# Govee Mac

<div align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013.7+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.0-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
</div>

A powerful, native macOS app to control your Govee smart lights with support for multiple protocols: Cloud API, LAN (local network), HomeKit/Matter, and Home Assistant.

## ✨ Features

### 🎮 Multi-Protocol Support
- **☁️ Govee Cloud API** - Official API with full device support
- **🏠 LAN Control** - Automatic mDNS/Bonjour discovery for local network control (faster response)
- **🍎 HomeKit/Matter** - Native integration with Apple Home devices
- **🏡 Home Assistant** - REST API integration for advanced automation

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

1. **Govee Cloud API** (Recommended)
   - Get your API key from [Govee Developer Portal](https://developer.govee.com)
   - Enter it in the welcome screen or Settings

2. **LAN Discovery** (Optional, faster)
   - Enable "Prefer LAN when available" in Settings
   - Click Refresh to discover local devices

3. **HomeKit** (Optional)
   - Enable "HomeKit (Matter)" in Settings
   - Grant permission when prompted
   - Your HomeKit Govee devices will appear

4. **Home Assistant** (Optional)
   - Enter your HA base URL (e.g., `https://homeassistant.local:8123`)
   - Generate a Long-Lived Access Token in HA
   - Paste token in Settings

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

- [ ] Scenes and automation support
- [ ] Custom color presets
- [ ] Schedule/timer functionality
- [ ] Music sync integration
- [ ] Multi-window support
- [ ] Shortcuts app integration
- [ ] iCloud sync for groups

## ⭐ Star History

If you find this project useful, please give it a star!

---

Made with ❤️ for the Govee community
