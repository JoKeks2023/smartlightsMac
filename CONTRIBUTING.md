# Contributing to Govee Mac

Thank you for your interest in contributing to Govee Mac! This document provides guidelines and instructions for contributing.

## 🚀 Getting Started

### Prerequisites
- macOS 13.7 (Ventura) or later
- Xcode 15.0 or later
- Git
- Free Apple ID (no paid developer account needed!)

### Setting Up Development Environment

1. **Fork and Clone**
   ```bash
   git clone https://github.com/YOUR_USERNAME/govee-mac.git
   cd govee-mac/Govee\ Mac
   ```

2. **Open in Xcode**
   ```bash
   open "Govee Mac.xcodeproj"
   ```

3. **Configure Signing** (one-time)
   - Xcode → Preferences → Accounts
   - Add your Apple ID
   - In project settings → Signing & Capabilities
   - Enable "Automatically manage signing"
   - Select your Team

4. **Build and Run**
   - Press `⌘R`
   - App should build and launch

## 🤝 How to Contribute

### Reporting Bugs

Before creating a bug report:
- Check if the bug has already been reported
- Collect information: macOS version, Xcode version, device types
- Include steps to reproduce

Create an issue with:
- Clear, descriptive title
- Detailed description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable
- Logs from Console.app if relevant

### Suggesting Features

Feature requests are welcome! Please:
- Check if the feature has already been suggested
- Explain the use case
- Describe the desired behavior
- Consider implementation complexity

### Pull Requests

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the coding style (see below)
   - Add comments for complex logic
   - Update documentation if needed

3. **Test your changes**
   - Test with multiple device types
   - Test all transport protocols (Cloud, LAN, HomeKit, HA)
   - Verify menu bar and UI still work

4. **Commit with descriptive messages**
   ```bash
   git commit -m "feat: add support for scene control"
   ```

5. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   - Open PR on GitHub
   - Describe what changed and why
   - Link related issues

## 📝 Coding Style

### Swift Guidelines

- **SwiftUI for all UI** - No AppKit views in new code
- **Use modern Swift** - async/await, actors, structured concurrency
- **Follow Apple conventions** - CamelCase, descriptive names
- **Add comments** - Especially for network protocols and complex algorithms

### File Organization

```
Govee Mac/
├── GoveeModels.swift          # Core models and logic
├── Govee_MacApp.swift         # App entry point
├── ContentView.swift          # Main UI
├── MenuBarController.swift    # Menu bar
├── Services/                  # Business logic
│   └── APIKeyKeychain.swift
└── GoveeWidget/              # Widget extension
```

### Code Examples

**Good:**
```swift
// MARK: - Device Discovery

func refreshDevices() async {
    var merged: [String: GoveeDevice] = [:]
    
    // Discover from all sources
    if !settings.goveeApiKey.isEmpty {
        let devices = try? await CloudDiscovery(apiKey: settings.goveeApiKey)
            .refreshDevices()
        // ...
    }
}
```

**Bad:**
```swift
func refresh() async {
    var d: [String: GoveeDevice] = [:]
    if settings.goveeApiKey != "" {
        let x = try? await CloudDiscovery(apiKey: settings.goveeApiKey).refreshDevices()
        // ...
    }
}
```

### Commit Message Format

Use conventional commits:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting)
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance tasks

Examples:
```
feat: add scene support with custom colors
fix: LAN discovery timeout on slow networks
docs: update HomeKit setup instructions
refactor: extract transport logic into protocols
```

## 🧪 Testing

### Manual Testing Checklist

Before submitting a PR, test:

- [ ] Cloud API - Devices appear and control works
- [ ] LAN Discovery - Auto-discovery finds devices
- [ ] HomeKit - Matter devices integrate correctly
- [ ] Home Assistant - REST API calls succeed
- [ ] Menu Bar - Quick controls function
- [ ] Groups - Multi-device control works
- [ ] Settings - Changes persist correctly
- [ ] State Polling - Devices update automatically
- [ ] Dark Mode - UI looks correct
- [ ] Accessibility - VoiceOver works (if changed UI)

### Device Types to Test

If possible, test with:
- RGB lights
- White-only lights
- Color temperature adjustable lights
- Strips, bulbs, and other form factors

## 🏗️ Architecture Guidelines

### Transport Implementation

When adding new transport types:

1. **Create discovery protocol conformance**
   ```swift
   struct MyDiscovery: DeviceDiscoveryProtocol {
       func refreshDevices() async throws -> [GoveeDevice] {
           // Implementation
       }
   }
   ```

2. **Create control protocol conformance**
   ```swift
   struct MyControl: DeviceControlProtocol {
       func setPower(device: GoveeDevice, on: Bool) async throws
       func setBrightness(device: GoveeDevice, value: Int) async throws
       // ...
   }
   ```

3. **Add to TransportKind enum**
   ```swift
   enum TransportKind: String, Codable, Hashable {
       case cloud, lan, homeKit, homeAssistant, myNewTransport
   }
   ```

4. **Integrate in GoveeController.refresh()**

### State Management

- Use `@Published` for observable state
- Use `@State` for view-local state
- Use `@EnvironmentObject` for shared state
- Prefer immutable structs for models

### Error Handling

- Use proper Swift error handling with `throws`
- Log errors to console for debugging
- Show user-friendly error messages in UI
- Never crash - catch and handle gracefully

## 📚 Resources

### Official Documentation
- [Govee Developer API](https://developer.govee.com)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [HomeKit Documentation](https://developer.apple.com/documentation/homekit)

### Project Documentation
- [FEATURES.md](FEATURES.md) - Complete feature list
- [WIDGET_SETUP.md](WIDGET_SETUP.md) - Widget configuration
- [BUILD_FIXED_SUMMARY.md](BUILD_FIXED_SUMMARY.md) - Build troubleshooting

## ❓ Questions?

- Open a [Discussion](https://github.com/yourusername/govee-mac/discussions)
- Check existing [Issues](https://github.com/yourusername/govee-mac/issues)
- Read the [README](README.md)

## 🎉 Recognition

Contributors will be:
- Listed in the README
- Credited in release notes
- Mentioned in the About dialog (if significant contribution)

Thank you for contributing to Govee Mac! 🙌
