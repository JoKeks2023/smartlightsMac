# Suggestion for iOS Companion Repository

This document contains suggestions for updates to the iOS companion repository to create reciprocal links back to this macOS repository.

## Recommended Changes to iOS Companion README

The iOS companion repository at https://github.com/JoKeks2023/smartlightsMac-ios-companion should add the following:

### 1. Add Badge at the Top

Add this badge after the existing badges (if any):

```markdown
<div align="center">
  <a href="https://github.com/JoKeks2023/smartlightsMac">
    <img src="https://img.shields.io/badge/🖥️_macOS_App-Available-blue.svg" alt="macOS App">
  </a>
</div>
```

### 2. Update Overview Section

Change the overview section to include a direct link:

**Current:**
```markdown
iOS remote control app for the SmartLights macOS application.
```

**Suggested:**
```markdown
iOS remote control app for the [SmartLights macOS application](https://github.com/JoKeks2023/smartlightsMac).

> **🖥️ macOS App Required**: This iOS app works with the macOS SmartLights app. Visit the [macOS App Repository](https://github.com/JoKeks2023/smartlightsMac) to get started with device discovery and control.
```

### 3. Add Related Projects Section

Add a section before the License/Contact section:

```markdown
## 🔗 Related Projects

### macOS App (Required)

- **[🖥️ SmartLights macOS App](https://github.com/JoKeks2023/smartlightsMac)** - Main application that controls devices
  - Device discovery and management
  - Multiple protocol support (Govee, Philips Hue, LIFX, etc.)
  - LAN, Cloud, HomeKit, Home Assistant integrations
  - DMX control support
  - **Required** for this iOS app to function

### Connection Guide

See [COMPANION_APP_CONNECTION.md](https://github.com/JoKeks2023/smartlightsMac/blob/main/COMPANION_APP_CONNECTION.md) in the macOS repository for detailed information on how the apps connect and sync.
```

### 4. Update "Integration with macOS App" Section

Enhance the existing section with a direct link:

**Add at the beginning:**
```markdown
## Integration with macOS App

> **Get the macOS App**: [SmartLights macOS Repository](https://github.com/JoKeks2023/smartlightsMac)

The macOS SmartLights app should:
[rest of existing content]
```

### 5. Add Installation Prerequisites

In the Requirements section, add:

```markdown
## Requirements

- iOS 15.0 or later
- Xcode 14.0 or later
- Swift 5.5+
- **macOS SmartLights App** - [Get it here](https://github.com/JoKeks2023/smartlightsMac) (required for device control)
- Optional: iCloud account for CloudKit sync
- Optional: macOS app for App Groups sharing
```

## Visual Enhancement Ideas

### Repository Topics

Add these topics to the iOS companion repository:
- `smartlights`
- `ios-app`
- `companion-app`
- `macos-companion`
- `smart-home`
- `govee`
- `philips-hue`
- `homekit`
- `swiftui`

### Repository Description

Update the repository description to:
```
iOS companion app for SmartLights macOS app - Remote control for Govee, Philips Hue, LIFX and more smart lights via CloudKit and App Groups sync
```

### Add Link to Repository Settings

In the repository settings on GitHub, add:
- **Website**: https://github.com/JoKeks2023/smartlightsMac
- This will show a prominent link in the repository sidebar

## Benefits

These changes will:
1. Make it immediately clear that this iOS app requires the macOS app
2. Provide easy navigation between repositories
3. Help users understand the relationship between the apps
4. Improve discoverability of both projects
5. Create a cohesive documentation ecosystem

## Implementation

To implement these changes in the iOS companion repository:

1. Fork or clone the iOS companion repository
2. Create a new branch: `git checkout -b add-macos-app-links`
3. Make the recommended changes to README.md
4. Commit and push: `git commit -m "Add links to macOS app repository"`
5. Create a pull request

## Note

This document is informational only. The changes should be made in the iOS companion repository by someone with write access to that repository.
