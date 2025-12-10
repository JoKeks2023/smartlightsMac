# AI Context File for Govee Mac / SmartlightsMac

**Complete Reference for AI Assistants Working on This Codebase**

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture & Design](#architecture--design)
3. [Key Features](#key-features)
4. [Technology Stack](#technology-stack)
5. [Project Structure](#project-structure)
6. [Core Components](#core-components)
7. [Integration Methods](#integration-methods)
8. [Setup & Configuration](#setup--configuration)
9. [Build & Deployment](#build--deployment)
10. [Development Guidelines](#development-guidelines)
11. [API References](#api-references)
12. [Troubleshooting](#troubleshooting)
13. [Security Considerations](#security-considerations)
14. [Testing Strategy](#testing-strategy)
15. [Future Roadmap](#future-roadmap)

---

## 📋 Project Overview

### What is Govee Mac?

Govee Mac (also known as SmartlightsMac) is a **native macOS application** for controlling smart lights from multiple manufacturers. It provides a unified interface for managing devices from Govee, Philips Hue, LIFX, Nanoleaf, WLED, and 100+ other brands through various integration protocols.

### Key Characteristics

- **Platform**: macOS 13.7 (Ventura) or later
- **Language**: Swift 5.0
- **Framework**: SwiftUI (native macOS UI)
- **Architecture**: Multi-protocol, multi-transport smart home control
- **Development Tool**: Xcode 15.2+
- **License**: MIT
- **Repository**: https://github.com/JoKeks2023/smartlightsMac

### Primary Goals

1. **Universal Control**: Support multiple smart light manufacturers in one app
2. **Multiple Protocols**: Cloud API, LAN, HomeKit, Home Assistant, DMX
3. **Native Experience**: Full macOS integration with menu bar and widgets
4. **Privacy First**: No analytics, local control preferred, secure keychain storage
5. **Free to Use**: Works with free Apple ID, no paid account required

---

## 🏗 Architecture & Design

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    macOS App (SwiftUI)                   │
├─────────────────────────────────────────────────────────┤
│  ContentView │ MenuBar │ Settings │ DeviceControl       │
├─────────────────────────────────────────────────────────┤
│              GoveeController (Orchestrator)              │
├──────────┬──────────┬──────────┬──────────┬────────────┤
│  Cloud   │   LAN    │ HomeKit  │   Home   │    DMX     │
│Discovery │Discovery │ Manager  │Assistant │  Receiver  │
├──────────┴──────────┴──────────┴──────────┴────────────┤
│          Transport Priority System (LAN > HA > Cloud)   │
├─────────────────────────────────────────────────────────┤
│   Govee API │ mDNS │ HomeKit │ HA REST │ ArtNet/sACN   │
└─────────────────────────────────────────────────────────┘
```

### Transport Priority

When controlling a device, the app uses this priority order:

1. **LAN** - Fastest, local network (when available and enabled)
2. **HomeKit** - Native Apple integration (for HomeKit devices)
3. **Home Assistant** - Flexible automation platform
4. **Cloud** - Govee official API (reliable fallback)
5. **DMX** - Professional lighting control (receive-only)

### Key Design Patterns

- **Protocol-Oriented**: `DeviceDiscoveryProtocol`, `DeviceControlProtocol`
- **Observable State**: `@Published` properties for reactive UI
- **Async/Await**: Modern Swift concurrency throughout
- **Secure by Default**: Keychain for credentials, sandboxed app
- **Modular Transports**: Each protocol is independently implemented

---

## ✨ Key Features

### 1. Multi-Manufacturer Support

#### Natively Supported
- **Govee** - Cloud API + LAN protocol (full support)
- **Philips Hue** - Native Bridge API + HomeKit + Home Assistant
- **WLED** - Direct REST API control
- **LIFX** - LAN protocol (partial) + HomeKit + Home Assistant

#### Via Integration Platforms
- **HomeKit/Matter** - Any HomeKit-compatible device (Hue, LIFX, Nanoleaf, Eve, Meross)
- **Home Assistant** - 100+ integrations (TP-Link, Yeelight, Tuya, Zigbee, Z-Wave)

### 2. Protocol Support

#### Cloud APIs
- **Govee Cloud API** - Official REST API with full device support
- **Rate Limits**: 60 requests/minute
- **Authentication**: API key from developer.govee.com

#### LAN (Local Network)
- **Auto-Discovery**: mDNS/Bonjour service discovery
- **Service Types**: `_govee._tcp`, `_wled._tcp`, `_hap._tcp`, `_lifx._tcp`, `_hue._tcp`
- **Benefits**: Faster response, works offline, no rate limits
- **Fallback**: Manual IP address entry available

#### HomeKit Integration
- **Native Framework**: Uses macOS HomeKit framework
- **Full Control**: Power, brightness, color, color temperature
- **Requirements**: Devices must be added to Home app first
- **Permissions**: Prompts for HomeKit access on first use

#### Home Assistant
- **REST API**: HTTP-based integration
- **Long-Lived Token**: Secure authentication
- **Discovery**: Finds light entities with manufacturer names
- **Services**: `light.turn_on`, `light.turn_off`, state queries

#### DMX Control (Professional)
- **Protocols**: ArtNet (port 6454), sACN/E1.31 (port 5568)
- **Mode**: Receive-only (incoming DMX → device commands)
- **Channel Modes**: Single Dimmer, RGB, RGBW, RGBA, RGB+Dimmer, Extended (6ch)
- **Custom Profiles**: User-defined DMX channel mappings
- **Universe Support**: 0-32767 universes, 512 channels each

### 3. User Interface

#### Main Window
- **Device List**: Sidebar with devices and groups
- **Detail View**: Control panel for selected device
- **Controls**: Power, brightness slider, color picker, color temperature
- **Status Indicators**: Online/offline, transport badges (LAN/Cloud/HomeKit/HA)
- **Group Control**: Simultaneous control of multiple devices

#### Menu Bar
- **Status Icon**: Lightbulb in macOS menu bar
- **Quick Controls**: Toggle devices, view brightness
- **Group Actions**: All On / All Off
- **Shortcuts**: ⌘R (refresh), ⌘O (open), ⌘Q (quit)

#### Settings
- **API Configuration**: Govee API key, HA URL/token
- **Preferences**: Prefer LAN, HomeKit enable/disable
- **DMX Settings**: Protocol selection, enable/disable receiver
- **Security**: Keychain-backed credential storage

#### Widget (Optional)
- **Sizes**: Small (1 device), Medium (3 devices), Large (6 devices)
- **Location**: macOS Notification Center
- **Update Frequency**: Every 5 minutes
- **Data Sharing**: App Groups (`group.com.govee.mac`)

### 4. Advanced Features

#### Device Groups
- Create groups of multiple devices
- Control all group members simultaneously
- Supports mixed manufacturers
- Group-level brightness, color, power

#### State Polling
- Automatic updates every 30 seconds
- Queries all transports for current state
- Optimistic updates for instant UI feedback
- Merges state from multiple sources

#### Smart Device Merging
- Same device discovered via multiple transports
- Combines capabilities from all sources
- Transport list shows all available methods
- Prefers best transport for each command

#### iOS Companion Support
- **CloudKit Sync**: Cross-device synchronization
- **Local Network**: Fast WiFi-based sync
- **Bluetooth**: Close proximity offline sync
- **App Groups**: Same-device instant sharing
- **Full Control API**: Device, group, and settings management
- **See**: `IOS_BRIDGE_DEVELOPER_GUIDE.md` for complete implementation

---

## 🛠 Technology Stack

### Languages & Frameworks
- **Swift 5.0**: Primary language
- **SwiftUI**: UI framework (native macOS)
- **HomeKit**: Apple's smart home framework
- **Combine**: Reactive programming
- **Async/Await**: Concurrency

### Apple Frameworks
- **Security**: Keychain access
- **Network**: TCP/UDP networking
- **NetService**: Bonjour/mDNS discovery
- **CloudKit**: Cross-device sync (for iOS companion)
- **WidgetKit**: Notification Center widgets

### Networking
- **URLSession**: HTTP/HTTPS requests
- **WebSocket**: Real-time communication (future)
- **UDP Sockets**: DMX receiver (ArtNet/sACN)
- **Bonjour/mDNS**: Service discovery

### Security
- **Keychain Services**: Encrypted credential storage
- **App Sandbox**: macOS security container
- **TLS/SSL**: Encrypted API communication
- **No Analytics**: Privacy-focused, no tracking

---

## 📁 Project Structure

### Repository Layout

```
smartlightsMac/
├── Govee Mac/                          # Main application
│   ├── GoveeModels.swift              # Core models, protocols, implementations (4700+ lines)
│   ├── Govee_MacApp.swift             # App entry point
│   ├── ContentView.swift              # Main UI view
│   ├── MenuBarController.swift        # Menu bar integration
│   ├── Services/                      # Business logic layer
│   │   ├── APIKeyKeychain.swift       # Keychain wrapper
│   │   ├── GoveeController.swift      # Main orchestrator
│   │   ├── CloudSyncManager.swift     # CloudKit + App Groups
│   │   ├── MultiTransportSyncManager.swift  # Multi-transport coordinator
│   │   ├── RemoteControlProtocol.swift      # iOS control API
│   │   └── StubServices.swift         # Development stubs
│   ├── Views/                         # UI components
│   │   └── APIKeyEntryView.swift      # API key input
│   ├── Assets.xcassets/               # Images, icons
│   └── Govee_Mac.entitlements         # App capabilities
├── Govee Mac.xcodeproj/               # Xcode project
├── GoveeWidget/                        # Widget extension (optional)
│   └── GoveeWidget.swift              # Widget implementation
├── GoveeWidgetTests/                   # Widget tests (if created)
├── Govee MacUITests/                   # UI tests (if created)
├── SmartlightsMac Exports/            # Build artifacts
├── Documentation Files:
│   ├── README.md                      # Main documentation
│   ├── FEATURES.md                    # Complete feature list
│   ├── CONTRIBUTING.md                # Contribution guide
│   ├── DMX_SETUP.md                   # DMX control guide
│   ├── MANUFACTURER_INTEGRATION.md    # Multi-brand setup
│   ├── WIDGET_SETUP.md                # Widget configuration
│   ├── FREE_APPLE_ID_GUIDE.md         # Free account setup
│   ├── RUN_WITHOUT_APPLE_ID.md        # No-signing build
│   ├── IOS_BRIDGE_DEVELOPER_GUIDE.md  # iOS app development (1000+ lines)
│   ├── IOS_COMPANION_GUIDE.md         # iOS integration overview
│   └── AI_CONTEXT.md                  # This file
├── Build Scripts:
│   ├── check-readiness.sh             # Pre-build validation
│   ├── verify-build.sh                # Build verification
│   ├── disable-signing.py             # Disable code signing
│   ├── add_file.py                    # Add files to Xcode
│   └── add_info_plist.py              # Info.plist helper
├── .gitignore                         # Git ignore rules
├── LICENSE                            # MIT license
└── Logo.png                           # App logo

Total Code: ~4700 lines of Swift across all files
```

### Key Files Explained

#### GoveeModels.swift (Core)
This is the **most important file** (~4700+ lines):

**Models**:
- `GoveeDevice`: Device representation
- `DeviceGroup`: Group of devices
- `DeviceColor`: RGB color struct
- `DMXProfile`, `DMXCustomChannel`: DMX configuration
- `TransportKind`: Enum of transport types

**Protocols**:
- `DeviceDiscoveryProtocol`: For discovering devices
- `DeviceControlProtocol`: For controlling devices

**Discovery Implementations**:
- `CloudDiscovery`: Govee Cloud API discovery
- `LANDiscovery`: mDNS/Bonjour service discovery
- `HomeKitManager`: HomeKit device discovery
- `HomeAssistantDiscovery`: Home Assistant API discovery
- `HueDiscovery`: Philips Hue Bridge API discovery
- `WLEDDiscovery`: WLED REST API discovery
- `LIFXDiscovery`: LIFX LAN protocol discovery (partial)

**Control Implementations**:
- `CloudControl`: Govee Cloud API control
- `LANControl`: Local network control
- `HomeKitControl`: HomeKit accessory control
- `HomeAssistantControl`: Home Assistant service calls
- `HueControl`: Philips Hue Bridge API control
- `WLEDControl`: WLED REST API control
- `LIFXControl`: LIFX protocol control (partial)

**State Management**:
- `DeviceStore`: Observable device collection
- `SettingsStore`: User preferences
- `DMXProfileStore`: DMX profile management

**DMX Receiver**:
- `DMXReceiver`: UDP listener for ArtNet/sACN
- Parses DMX packets, translates to device commands

#### Govee_MacApp.swift
- App entry point with `@main`
- Initializes all `@StateObject` managers
- Sets up menu bar controller
- Configures environment objects for views
- Shows welcome screen on first launch

#### ContentView.swift
- Main application window
- Device list sidebar
- Device control detail view
- Group management UI
- Toolbar with refresh and add buttons

#### MenuBarController.swift
- Creates NSStatusItem for menu bar
- Builds menu with device list
- Handles menu actions (toggle power, refresh)
- Updates dynamically when devices change

#### Services/GoveeController.swift
- Main orchestrator coordinating all transports
- `refresh()`: Discovers devices from all sources
- Merges devices from multiple transports
- Handles state polling every 30 seconds
- Routes control commands to appropriate transport

#### Services/CloudSyncManager.swift
- CloudKit integration for iOS companion
- App Groups for same-device sharing
- Saves/loads devices, groups, settings
- Supports background sync

#### Services/MultiTransportSyncManager.swift
- Coordinates CloudKit, Local Network, Bluetooth, App Groups
- Unified sync interface for iOS companion
- Connection state management
- Transport fallback logic

#### Services/RemoteControlProtocol.swift
- Remote control API for iOS companion
- Commands: device control, group management, settings sync
- Request/response structures
- Error handling

---

## 🎯 Core Components

### 1. Device Discovery

**Purpose**: Find smart lights on network or via APIs

**Flow**:
```swift
GoveeController.refresh()
  → CloudDiscovery.refreshDevices()
  → LANDiscovery.refreshDevices()
  → HomeKitManager.refreshDevices()
  → HomeAssistantDiscovery.refreshDevices()
  → HueDiscovery.refreshDevices()
  → WLEDDiscovery.refreshDevices()
  → LIFXDiscovery.refreshDevices()
  → Merge all devices
  → Update DeviceStore
```

**Key Functions**:
- `refreshDevices() async throws -> [GoveeDevice]`: Discovers devices
- Device merging: Combines same device from multiple sources
- Transport tagging: Each device tracks available transports

### 2. Device Control

**Purpose**: Send commands to smart lights

**Protocol**:
```swift
protocol DeviceControlProtocol {
    func setPower(device: GoveeDevice, on: Bool) async throws
    func setBrightness(device: GoveeDevice, value: Int) async throws
    func setColor(device: GoveeDevice, color: DeviceColor) async throws
    func setColorTemperature(device: GoveeDevice, kelvin: Int) async throws
}
```

**Transport Selection**:
1. Check device's available transports
2. Use preferred transport (LAN > HomeKit > HA > Cloud)
3. Fallback to next transport if primary fails
4. Update UI optimistically, then confirm

### 3. State Management

**Observable Objects**:
- `DeviceStore`: `@Published var devices: [GoveeDevice]`
- `SettingsStore`: `@Published var goveeApiKey: String`, etc.
- `GoveeController`: `@Published var isRefreshing: Bool`

**State Flow**:
```
User Action → Controller → Protocol → API/Network
                ↓
    Optimistic UI Update
                ↓
         Confirm Response
                ↓
    Final State Update → UI Refresh
```

### 4. Group Management

**Functionality**:
- Create groups with multiple devices
- Control all group members simultaneously
- Mixed transports within group
- Group-level state aggregation

**Implementation**:
```swift
struct DeviceGroup: Identifiable, Codable {
    let id: String
    var name: String
    var memberIDs: [String]
    
    func members(from devices: [GoveeDevice]) -> [GoveeDevice] {
        devices.filter { memberIDs.contains($0.id) }
    }
}
```

### 5. DMX Receiver

**Architecture**:
```
DMX Software (QLC+, LightKey) 
  → ArtNet/sACN Packet (UDP)
  → DMXReceiver.handlePacket()
  → Parse DMX channels
  → Lookup device by universe/channel
  → Apply DMX profile
  → Translate to device command
  → GoveeController.control()
```

**DMX Profile System**:
- Built-in profiles: Single Dimmer, RGB, RGBW, etc.
- Custom profiles: User-defined channel mappings
- Per-device configuration: Universe, start channel, profile

---

## 🔌 Integration Methods

### Govee Cloud API

**Setup**:
1. Get API key from https://developer.govee.com
2. Enter in app Settings
3. Stored securely in Keychain

**Endpoints**:
- `GET /v1/devices`: List devices
- `PUT /v1/devices/control`: Control device
- `GET /v1/devices/state`: Query state

**Rate Limit**: 60 requests/minute

**Implementation**: `CloudDiscovery`, `CloudControl` in `GoveeModels.swift`

### LAN (Local Network)

**Discovery**:
- Uses `NetService` (Bonjour/mDNS)
- Scans for multiple service types
- 5-second timeout
- Resolves IP addresses automatically

**Control**:
- Direct HTTP/UDP to device IP
- Faster than cloud (< 100ms)
- Works without internet
- No rate limits

**Protocols**:
- Govee LAN: Custom protocol
- WLED: REST API (`/json/state`)
- LIFX: Binary UDP protocol (partial)

**Implementation**: `LANDiscovery`, `LANControl`, `WLEDControl`, `LIFXControl`

### HomeKit

**Requirements**:
- Devices added to Home app
- HomeKit entitlement enabled
- User permission granted

**API**:
- `HMHomeManager`: Access homes
- `HMAccessory`: Device representation
- `HMCharacteristic`: Control points (power, brightness, hue, saturation)

**Characteristics**:
- Power: `HMCharacteristicTypePowerState`
- Brightness: `HMCharacteristicTypeBrightness` (0-100)
- Color: `HMCharacteristicTypeHue` (0-360), `HMCharacteristicTypeSaturation` (0-100)
- Temperature: `HMCharacteristicTypeColorTemperature` (mireds)

**Implementation**: `HomeKitManager`, `HomeKitControl`

### Home Assistant

**Setup**:
1. Install Home Assistant (https://home-assistant.io)
2. Add light integrations (Hue, LIFX, etc.)
3. Generate Long-Lived Access Token
4. Enter HA URL and token in app Settings

**API**:
- Base URL: `http://homeassistant.local:8123`
- Auth: `Authorization: Bearer <token>`
- Endpoints:
  - `GET /api/states`: List all entities
  - `POST /api/services/light/turn_on`: Turn on light
  - `POST /api/services/light/turn_off`: Turn off light

**Entity Filtering**:
- Searches for light entities
- Checks friendly_name and entity_id for manufacturer keywords
- Keywords: "govee", "hue", "lifx", "wled", "tp-link", "yeelight"

**Implementation**: `HomeAssistantDiscovery`, `HomeAssistantControl`

### DMX Control

**Protocols**:

**ArtNet**:
- Port: 6454 UDP
- Header: "Art-Net\0"
- OpCode: 0x5000 (ArtDMX)
- 512 channels per universe

**sACN (E1.31)**:
- Port: 5568 UDP
- Multicast: 239.255.0.x (x = universe)
- 512 channels per universe
- Priority and sequence tracking

**Channel Modes**:
1. **Single Dimmer (1ch)**: Brightness only
2. **RGB (3ch)**: Red, Green, Blue
3. **RGBW (4ch)**: RGB + White
4. **RGBA (4ch)**: RGB + Amber
5. **RGB + Dimmer (4ch)**: Dimmer, RGB
6. **Extended (6ch)**: Dimmer, RGB, White, Amber

**Configuration**:
- Right-click device → Configure DMX
- Set universe (0-32767)
- Set start channel (1-512)
- Select channel mode
- Or create custom profile

**Implementation**: `DMXReceiver`, `DMXProfile` system

---

## ⚙️ Setup & Configuration

### Prerequisites

**Required**:
- macOS 13.7 (Ventura) or later
- Xcode 15.2 or later
- Free Apple ID (no paid developer account needed)

**Optional**:
- Govee API key for Govee devices
- Home Assistant for multi-brand support
- Philips Hue Bridge for Hue lights
- DMX software for professional lighting control

### First-Time Setup

**1. Clone Repository**
```bash
git clone https://github.com/JoKeks2023/smartlightsMac.git
cd smartlightsMac
```

**2. Open in Xcode**
```bash
open "Govee Mac.xcodeproj"
```

**3. Configure Signing** (for running on your Mac)

**Option A: With Apple ID** (Recommended)
1. Xcode → Preferences → Accounts
2. Add your Apple ID
3. Select project → Govee Mac target
4. Signing & Capabilities → Enable "Automatically manage signing"
5. Select your Team

**Option B: Without Apple ID** (CI/Development)
1. Select project → Govee Mac target
2. Signing & Capabilities → Disable "Automatically manage signing"
3. Set Signing Certificate to "Sign to Run Locally" or "None"
4. Build succeeds but app only runs on your Mac

**4. Build and Run**
```bash
# In Xcode: ⌘R (or Product → Run)

# Or command line:
xcodebuild -project "Govee Mac.xcodeproj" \
  -scheme "Govee Mac" \
  -configuration Debug \
  build
```

**5. First Launch**
- Welcome screen appears
- Choose integration method:
  - Govee Cloud: Enter API key
  - LAN: Enable auto-discovery
  - HomeKit: Grant permission
  - Home Assistant: Enter URL and token
- Click "Weiter" to complete setup

### Configuration Options

**Settings Panel (⌘,)**:

**API Keys**:
- `goveeApiKey`: Govee Cloud API key (stored in Keychain)
- `homeAssistantUrl`: Home Assistant base URL
- `homeAssistantToken`: Long-lived access token (stored in Keychain)

**Preferences**:
- `prefersLan`: Prefer local network over cloud
- `homeKitEnabled`: Enable HomeKit integration
- `dmxEnabled`: Enable DMX receiver
- `dmxProtocol`: ArtNet or sACN
- `autoRefresh`: Enable automatic state polling (default: true)

**Entitlements** (`Govee_Mac.entitlements`):
- `com.apple.security.app-sandbox`: App sandboxing
- `com.apple.security.network.client`: Outbound connections
- `com.apple.security.network.server`: Inbound connections (DMX)
- `com.apple.developer.homekit`: HomeKit access
- `com.apple.security.application-groups`: App Groups (`group.com.govee.mac`)
- `keychain-access-groups`: Keychain access

### Environment Variables

**None required** - All configuration via UI settings

**Build Variables** (for CI):
```bash
CODE_SIGN_IDENTITY=""
CODE_SIGNING_REQUIRED=NO
CODE_SIGNING_ALLOWED=NO
```

---

## 🚀 Build & Deployment

### Development Build

**Xcode**:
```bash
# Press ⌘R to build and run
# Or: Product → Run
```

**Command Line**:
```bash
xcodebuild -project "Govee Mac.xcodeproj" \
  -scheme "Govee Mac" \
  -configuration Debug \
  build
```

### Release Build

**With Code Signing** (for distribution):
```bash
xcodebuild -project "Govee Mac.xcodeproj" \
  -scheme "Govee Mac" \
  -configuration Release \
  build
```

**Without Code Signing** (for CI/testing):
```bash
xcodebuild -project "Govee Mac.xcodeproj" \
  -scheme "Govee Mac" \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### Build Scripts

**check-readiness.sh**: Pre-build validation
```bash
./check-readiness.sh
# Verifies Xcode, Swift version, dependencies
```

**verify-build.sh**: Post-build verification
```bash
./verify-build.sh
# Confirms build succeeded, app is runnable
```

**disable-signing.py**: Programmatically disable signing
```python
python3 disable-signing.py
# Modifies project.pbxproj to disable code signing
```

### Distribution

**Personal Use** (Free Apple ID):
- Build on your Mac
- Run locally only
- 7-day certificate validity
- Rebuild weekly to renew

**Public Distribution** (Paid Developer Account):
1. Notarize with Apple
2. Create DMG or ZIP
3. Distribute via GitHub Releases or website
4. Users can download and run

**App Store** (Paid Developer Account):
1. Configure for Mac App Store
2. Submit for review
3. Publish through App Store Connect

---

## 👨‍💻 Development Guidelines

### Code Style

**Swift Conventions**:
- CamelCase for types, properties, functions
- Descriptive names (e.g., `refreshDevices`, not `refresh`)
- Use `async/await` for asynchronous operations
- Prefer `struct` over `class` when possible
- Use `@Published` for observable properties

**SwiftUI**:
- All UI in SwiftUI (no AppKit views)
- Use `@State`, `@StateObject`, `@EnvironmentObject` appropriately
- Prefer composition over inheritance
- Extract reusable views to separate files

**Comments**:
```swift
// MARK: - Section Name

/// Brief description
/// - Parameter param: Description
/// - Returns: Description
/// - Throws: Error description
func functionName(param: Type) async throws -> ReturnType {
    // Implementation
}
```

### Project Organization

**File Naming**:
- `GoveeModels.swift`: Core models and protocols
- `Govee_MacApp.swift`: App entry point
- `ContentView.swift`: Main UI
- `MenuBarController.swift`: Menu bar logic
- `Services/`: Business logic and integrations

**Adding New Features**:
1. Define protocols if needed
2. Implement in `GoveeModels.swift` or separate file
3. Add to `GoveeController` orchestration
4. Update UI in `ContentView.swift`
5. Test with multiple device types
6. Update documentation

### Testing

**Manual Testing**:
- Test with real devices when possible
- Test all transports (Cloud, LAN, HomeKit, HA)
- Test error cases (no internet, device offline)
- Test UI on light and dark modes
- Test menu bar functionality

**Unit Tests** (not currently implemented):
- Add tests in `Govee MacTests/`
- Test device merging logic
- Test DMX parsing
- Test color conversions
- Mock network calls

### Git Workflow

**Branches**:
- `main`: Stable release
- `develop`: Development branch
- `feature/feature-name`: Feature branches
- `fix/bug-name`: Bug fix branches

**Commit Messages**:
```
feat: add WLED native support
fix: LAN discovery timeout on slow networks
docs: update HomeKit integration guide
refactor: extract DMX receiver to separate file
test: add unit tests for device merging
```

**Pull Requests**:
- One feature per PR
- Update documentation
- Test thoroughly
- Link related issues

---

## 📚 API References

### Govee Cloud API

**Base URL**: `https://developer-api.govee.com`

**Authentication**: 
```
Header: Govee-API-Key: <your_api_key>
```

**Endpoints**:

**List Devices**:
```http
GET /v1/devices
Response: {
  "code": 200,
  "message": "Success",
  "data": {
    "devices": [
      {
        "device": "AA:BB:CC:DD:EE:FF:GG:HH",
        "model": "H6159",
        "deviceName": "Living Room Light",
        "controllable": true,
        "retrievable": true,
        "supportCmds": ["turn", "brightness", "color", "colorTem"],
        "properties": {...}
      }
    ]
  }
}
```

**Control Device**:
```http
PUT /v1/devices/control
Body: {
  "device": "AA:BB:CC:DD:EE:FF:GG:HH",
  "model": "H6159",
  "cmd": {
    "name": "turn",
    "value": "on"
  }
}
```

**Commands**:
- `turn`: `on` or `off`
- `brightness`: 0-100
- `color`: `{"r": 255, "g": 0, "b": 0}`
- `colorTem`: 2000-9000 (kelvin)

### Home Assistant REST API

**Base URL**: `http://homeassistant.local:8123/api`

**Authentication**:
```
Header: Authorization: Bearer <long_lived_access_token>
```

**Endpoints**:

**Get States**:
```http
GET /api/states
Response: [
  {
    "entity_id": "light.hue_living_room",
    "state": "on",
    "attributes": {
      "brightness": 200,
      "color_temp": 300,
      "rgb_color": [255, 200, 150],
      "friendly_name": "Hue Living Room"
    }
  }
]
```

**Turn On Light**:
```http
POST /api/services/light/turn_on
Body: {
  "entity_id": "light.hue_living_room",
  "brightness_pct": 75,
  "rgb_color": [255, 0, 0]
}
```

**Turn Off Light**:
```http
POST /api/services/light/turn_off
Body: {
  "entity_id": "light.hue_living_room"
}
```

### Philips Hue Bridge API

**Discovery**:
- SSDP: `M-SEARCH * HTTP/1.1` on `239.255.255.250:1900`
- mDNS: `_hue._tcp.local.`
- Cloud: `https://discovery.meethue.com/`

**Base URL**: `http://<bridge_ip>/api`

**Authentication**:
1. Press link button on bridge
2. POST `/api` with `{"devicetype": "govee_mac#device"}`
3. Receive username (API key)

**Endpoints**:

**Get Lights**:
```http
GET /api/<username>/lights
Response: {
  "1": {
    "name": "Living Room",
    "state": {
      "on": true,
      "bri": 254,
      "hue": 10000,
      "sat": 254,
      "ct": 200
    }
  }
}
```

**Set Light State**:
```http
PUT /api/<username>/lights/<id>/state
Body: {
  "on": true,
  "bri": 200,
  "hue": 25500,
  "sat": 200
}
```

### WLED REST API

**Base URL**: `http://<device_ip>`

**Get State**:
```http
GET /json/state
Response: {
  "on": true,
  "bri": 128,
  "seg": [{
    "col": [[255, 0, 0], ...]
  }]
}
```

**Set State**:
```http
POST /json/state
Body: {
  "on": true,
  "bri": 200,
  "seg": [{
    "col": [[255, 100, 50]]
  }]
}
```

### HomeKit API

**Framework**: Import `HomeKit`

**Access**:
```swift
import HomeKit

let homeManager = HMHomeManager()
// Wait for homeManagerDidUpdateHomes

let home = homeManager.primaryHome
let accessories = home.accessories.filter { $0.category == .lighting }

for accessory in accessories {
    let service = accessory.services.first { $0.serviceType == HMServiceTypeLightbulb }
    let powerChar = service?.characteristics.first { 
        $0.characteristicType == HMCharacteristicTypePowerState 
    }
    
    // Read
    try await powerChar?.readValue()
    let isOn = powerChar?.value as? Bool
    
    // Write
    try await powerChar?.writeValue(true)
}
```

---

## 🔍 Troubleshooting

### Common Issues

#### "No devices found"

**Causes**:
- No API key entered (Cloud)
- Devices not on network (LAN)
- HomeKit not enabled
- Home Assistant not configured

**Solutions**:
1. Check Settings for API key/URL/token
2. Verify devices are powered on and connected
3. Click Refresh button
4. Check Console.app for error logs
5. Enable verbose logging in code

#### "LAN discovery not finding devices"

**Causes**:
- Devices don't support LAN protocol
- Firewall blocking mDNS
- Different network/VLAN
- Router blocks multicast

**Solutions**:
1. Verify device supports LAN in manual
2. System Settings → Network → Firewall → Allow Govee Mac
3. Ensure Mac and devices on same network
4. Try manual "Add Device" with IP address
5. Fallback to Cloud API

#### "HomeKit permission denied"

**Causes**:
- User denied HomeKit access
- Entitlement not configured
- Device not added to Home app

**Solutions**:
1. System Settings → Privacy → HomeKit → Enable for Govee Mac
2. Re-enable in app Settings
3. Add devices to Home app first
4. Restart app

#### "DMX not controlling devices"

**Causes**:
- DMX receiver not enabled
- Wrong protocol (ArtNet vs sACN)
- Universe/channel mismatch
- Firewall blocking UDP

**Solutions**:
1. Settings → Enable DMX Receiver
2. Match protocol in DMX software
3. Verify universe and channel numbers
4. Check DMX software is sending to correct IP/broadcast
5. Allow incoming connections in Firewall

#### "Build errors in Xcode"

**Causes**:
- Missing signing configuration
- Xcode version too old
- Entitlements misconfigured

**Solutions**:
1. Add Apple ID in Xcode Preferences
2. Enable automatic signing
3. Or disable signing for local-only builds
4. Clean build folder (⌘⇧K)
5. Update Xcode to 15.2+

#### "App crashes on launch"

**Causes**:
- Corrupted preferences
- Keychain access denied
- macOS version too old

**Solutions**:
1. Reset preferences: `defaults delete com.govee.mac`
2. Check Console.app crash logs
3. Verify macOS 13.7+
4. Reinstall app

### Debug Logging

**Enable Verbose Logging**:
```swift
// In GoveeModels.swift or relevant file
let DEBUG = true  // Change to true

if DEBUG {
    print("[DEBUG] Discovery found \(devices.count) devices")
}
```

**Console.app Filtering**:
1. Open Console.app
2. Filter: "Govee Mac" or "govee"
3. Look for errors, warnings

**Network Debugging**:
```bash
# Monitor network traffic
sudo tcpdump -i any port 6454 or port 5568
# ArtNet or sACN packets

# Check mDNS services
dns-sd -B _govee._tcp
dns-sd -B _hue._tcp
```

### Performance Issues

#### "High CPU usage"

**Causes**:
- Too frequent state polling
- DMX receiver processing high rate
- Memory leak in discovery

**Solutions**:
1. Increase polling interval in `GoveeController`
2. Reduce DMX update rate in lighting software
3. Disable unused transports
4. Profile with Instruments

#### "Slow UI response"

**Causes**:
- Network calls on main thread (shouldn't happen with async/await)
- Too many devices
- Inefficient SwiftUI updates

**Solutions**:
1. Verify async/await usage
2. Limit device count or use pagination
3. Optimize SwiftUI view hierarchies
4. Use Instruments to profile

---

## 🔒 Security Considerations

### Credential Storage

**Keychain Usage**:
- API keys stored in macOS Keychain
- Encrypted by macOS
- Persists across app uninstall/reinstall
- Requires authentication to access

**Implementation**:
```swift
// Save
try APIKeyKeychain.save(key: apiKey)

// Load
if let key = try APIKeyKeychain.load() {
    // Use key
}
```

**Never**:
- Store credentials in UserDefaults
- Log API keys or tokens
- Commit secrets to git
- Send credentials to third parties

### Network Security

**HTTPS**:
- Use HTTPS for all API calls when available
- Validate SSL certificates
- No HTTP fallback for sensitive data

**Local Network**:
- LAN control uses local IPs (consider using TLS if supported by devices)
- mDNS discovery is unauthenticated (verify devices)
- DMX is UDP unencrypted (use secure network)

### App Sandboxing

**Enabled Entitlements**:
- `com.apple.security.app-sandbox`: App runs in sandbox
- Minimal permissions requested
- Network client/server for API and LAN
- HomeKit for device control
- Keychain for credential storage

**Restrictions**:
- No file system access beyond user-selected files
- No access to other apps' data
- No system modification

### Privacy

**No Analytics**:
- No telemetry or tracking
- No data sent to third parties
- All data stays on device
- CloudKit sync (optional, for iOS companion) uses user's iCloud

**Permissions**:
- HomeKit: Requested on first use, can be revoked
- Network: Allowed by entitlements
- Keychain: Automatic with entitlement

---

## 🧪 Testing Strategy

### Manual Testing Checklist

**Device Discovery**:
- [ ] Govee Cloud API discovers devices
- [ ] LAN auto-discovery finds devices
- [ ] HomeKit discovers accessories
- [ ] Home Assistant discovers lights
- [ ] Device merging works correctly
- [ ] Manual device addition works

**Device Control**:
- [ ] Power on/off works for all transports
- [ ] Brightness control works (0-100%)
- [ ] Color control works (RGB)
- [ ] Color temperature works (2000-9000K)
- [ ] Group control works
- [ ] Commands respect transport priority

**UI**:
- [ ] Device list updates correctly
- [ ] Detail view shows device state
- [ ] Settings panel saves preferences
- [ ] Menu bar shows devices
- [ ] Menu bar quick controls work
- [ ] Dark mode displays correctly

**DMX**:
- [ ] DMX receiver starts correctly
- [ ] ArtNet packets received and parsed
- [ ] sACN packets received and parsed
- [ ] DMX values translate to device commands
- [ ] Multiple devices on same universe work
- [ ] Custom profiles work

**Edge Cases**:
- [ ] No internet connection (LAN fallback)
- [ ] Device goes offline mid-operation
- [ ] API rate limit handling
- [ ] Invalid API key error handling
- [ ] Empty device list

### Unit Testing (Recommended)

**Test Cases to Implement**:

```swift
import XCTest

class GoveeModelsTests: XCTestCase {
    func testDeviceMerging() {
        let cloudDevice = GoveeDevice(id: "1", name: "Light", transports: [.cloud])
        let lanDevice = GoveeDevice(id: "1", name: "Light", transports: [.lan])
        let merged = mergeDevices([cloudDevice, lanDevice])
        XCTAssertEqual(merged.count, 1)
        XCTAssertTrue(merged[0].transports.contains(.cloud))
        XCTAssertTrue(merged[0].transports.contains(.lan))
    }
    
    func testDMXParsing() {
        let dmx = DMXReceiver(protocol: .artnet)
        let packet = createArtNetPacket(universe: 0, channels: [255, 128, 64])
        let values = dmx.parsePacket(packet)
        XCTAssertEqual(values[0], 255)
        XCTAssertEqual(values[1], 128)
        XCTAssertEqual(values[2], 64)
    }
    
    func testColorConversion() {
        let rgb = DeviceColor(r: 255, g: 0, b: 0)
        let (h, s, v) = rgbToHSV(rgb)
        XCTAssertEqual(h, 0)
        XCTAssertEqual(s, 100)
        XCTAssertEqual(v, 100)
    }
}
```

### Integration Testing

**Test with Real Devices**:
1. Set up test environment with multiple manufacturers
2. Test all transports (Cloud, LAN, HomeKit, HA, DMX)
3. Measure latency for each transport
4. Test error recovery
5. Test concurrent operations

**CI/CD Testing**:
```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build
        run: |
          xcodebuild -project "Govee Mac.xcodeproj" \
            -scheme "Govee Mac" \
            -configuration Debug \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            build
      - name: Test
        run: |
          xcodebuild -project "Govee Mac.xcodeproj" \
            -scheme "Govee Mac" \
            -configuration Debug \
            test
```

---

## 🗺 Future Roadmap

### Completed Features ✅

- [x] Govee Cloud API integration
- [x] LAN auto-discovery (mDNS/Bonjour)
- [x] HomeKit integration (Matter-compatible)
- [x] Home Assistant integration (100+ brands)
- [x] DMX control (ArtNet/sACN)
- [x] Menu bar quick controls
- [x] Device groups
- [x] State polling
- [x] Keychain security
- [x] iOS companion app infrastructure
- [x] Multi-transport sync (CloudKit, Local Network, Bluetooth)
- [x] Native Philips Hue Bridge API
- [x] WLED REST API integration
- [x] LIFX LAN protocol (partial)

### In Progress ⚙️

- [ ] LIFX binary UDP protocol (complete implementation)
- [ ] Hue Entertainment mode support
- [ ] Improved error handling and recovery

### Planned Enhancements 📋

**Protocol Support**:
- [ ] Nanoleaf OpenAPI native support
- [ ] TP-Link Kasa local protocol
- [ ] Yeelight LAN protocol
- [ ] Matter/Thread protocol (native)
- [ ] Z-Wave integration (via HA)
- [ ] Zigbee integration (via HA)

**Features**:
- [ ] Scenes and presets
- [ ] Custom color palettes
- [ ] Schedules and timers
- [ ] Music sync / audio reactive
- [ ] Automation rules
- [ ] Shortcuts app integration
- [ ] Multi-window support
- [ ] Scene editor UI

**iOS Companion**:
- [ ] Full iOS app UI
- [ ] Widget for iOS
- [ ] watchOS complication
- [ ] Siri integration
- [ ] Control Center integration

**Quality of Life**:
- [ ] Dark mode improvements
- [ ] Accessibility enhancements
- [ ] Localization (i18n)
- [ ] Performance optimizations
- [ ] Unit test suite
- [ ] UI test suite

**Distribution**:
- [ ] Mac App Store submission
- [ ] Notarization for direct download
- [ ] Homebrew formula
- [ ] Auto-update mechanism

### Community Contributions Welcome

Areas where contributions are especially valuable:
- **Protocol implementations**: Add support for new manufacturers
- **UI improvements**: Enhance design and usability
- **Documentation**: Expand guides and examples
- **Testing**: Add unit and integration tests
- **Bug fixes**: Address issues and edge cases
- **Localization**: Translate to other languages

See `CONTRIBUTING.md` for guidelines.

---

## 📖 Additional Documentation

### Essential Reading

1. **README.md** - Project introduction and quick start
2. **FEATURES.md** - Complete feature list with implementation status
3. **MANUFACTURER_INTEGRATION.md** - Multi-brand setup guide
4. **CONTRIBUTING.md** - Development and contribution guidelines

### Setup Guides

5. **FREE_APPLE_ID_GUIDE.md** - Building with free Apple ID
6. **RUN_WITHOUT_APPLE_ID.md** - No-signing development build
7. **WIDGET_SETUP.md** - Notification Center widget configuration

### Advanced Topics

8. **DMX_SETUP.md** - Professional lighting control setup
9. **IOS_BRIDGE_DEVELOPER_GUIDE.md** - Complete iOS companion app guide (1000+ lines)
10. **IOS_COMPANION_GUIDE.md** - iOS integration architecture overview

### References

11. **AI_CONTEXT.md** - This file (complete AI reference)

---

## 🎓 Learning Resources

### Swift & SwiftUI
- [Swift.org](https://swift.org) - Official Swift documentation
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui) - Apple's official tutorials
- [WWDC Videos](https://developer.apple.com/videos/) - Apple developer conference sessions

### HomeKit
- [HomeKit Documentation](https://developer.apple.com/documentation/homekit) - Official HomeKit docs
- [HomeKit Accessory Protocol](https://developer.apple.com/homekit/) - HAP specification

### Smart Home Protocols
- [Govee API Docs](https://developer.govee.com) - Official Govee API documentation
- [Home Assistant Docs](https://www.home-assistant.io/docs/) - Complete HA documentation
- [Philips Hue API](https://developers.meethue.com/) - Official Hue developer portal
- [WLED Wiki](https://kno.wled.ge/) - WLED documentation
- [Art-Net Protocol](https://art-net.org.uk/) - ArtNet specification
- [sACN/E1.31 Standard](https://tsp.esta.org/tsp/documents/published_docs.php) - ANSI E1.31

---

## 🤝 Community & Support

### Getting Help

**Issues**: [GitHub Issues](https://github.com/JoKeks2023/smartlightsMac/issues)
- Bug reports
- Feature requests
- Questions

**Discussions**: [GitHub Discussions](https://github.com/JoKeks2023/smartlightsMac/discussions)
- General questions
- Ideas and suggestions
- Show and tell

**Documentation**: This repository
- All guides in markdown
- Code comments
- Examples in guides

### Contributing

**Ways to Contribute**:
1. **Code**: Implement features, fix bugs
2. **Documentation**: Improve guides, add examples
3. **Testing**: Report bugs, test edge cases
4. **Design**: UI/UX improvements
5. **Support**: Help others in discussions

**Contribution Process**:
1. Fork repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request
6. Address review feedback

See `CONTRIBUTING.md` for detailed guidelines.

---

## 📊 Project Statistics

**Code**:
- Primary Language: Swift
- Lines of Code: ~4700+ (main app)
- Files: ~10 Swift files, 10+ markdown docs
- Protocols: 2 (Discovery, Control)
- Implementations: 7 transport types

**Features**:
- Manufacturers Supported: 6+ natively, 100+ via HA
- Protocols: 7 (Cloud, LAN, HomeKit, HA, Hue, WLED, LIFX)
- Control Methods: 5 (API, LAN, HomeKit, HA, DMX)
- UI Components: 3 (Main window, Menu bar, Widget)

**Documentation**:
- Documentation Files: 11 markdown files
- Total Documentation: 5000+ lines
- Guides: Setup, Integration, Development, iOS
- Languages: English

---

## 📝 Version History

### Current Version
- **Status**: Active Development
- **macOS**: 13.7+ (Ventura)
- **Xcode**: 15.2+
- **Swift**: 5.0

### Major Milestones
- **2024**: Full multi-manufacturer support
- **2024**: iOS companion infrastructure complete
- **2024**: DMX control added
- **2024**: Native Hue Bridge API
- **2024**: WLED integration
- **Initial**: Govee-only support

---

## 🔑 Key Takeaways for AI

### When Working on This Project

**Understand**:
- This is a **multi-protocol smart home controller**
- Supports **multiple manufacturers** through various integrations
- Uses **SwiftUI** for all UI (no AppKit)
- Employs **protocol-oriented design** for extensibility
- Prioritizes **privacy and security** (Keychain, sandbox)

**Always**:
- Test with multiple device types
- Consider transport priority (LAN > HomeKit > HA > Cloud)
- Handle errors gracefully (devices offline, API limits)
- Update documentation when adding features
- Follow Swift coding conventions

**Never**:
- Store credentials in UserDefaults
- Block main thread with network calls
- Remove working functionality without reason
- Skip error handling
- Forget to update docs

**Key Files**:
- `GoveeModels.swift` - Core logic (4700+ lines)
- `GoveeController.swift` - Orchestrator
- `ContentView.swift` - Main UI
- `MenuBarController.swift` - Menu bar

**Common Tasks**:
- Add new protocol: Implement `DeviceDiscoveryProtocol` and `DeviceControlProtocol`
- Add UI feature: Update `ContentView.swift`, use `@EnvironmentObject`
- Fix bug: Check Console.app logs, add debug prints
- Update docs: Edit relevant .md file

---

## 📮 Contact & Links

**Repository**: https://github.com/JoKeks2023/smartlightsMac

**Author**: JoKeks2023

**License**: MIT License (see `LICENSE` file)

**Related Projects**:
- Govee: https://www.govee.com
- Govee Developer API: https://developer.govee.com
- Home Assistant: https://home-assistant.io
- Philips Hue: https://developers.meethue.com
- WLED: https://kno.wled.ge

---

**This AI context file is a living document. Update it as the project evolves.**

**Last Updated**: 2024-12-10

**For AI Assistants**: This file contains EVERYTHING you need to understand and work on this project. Read it thoroughly before making changes. When in doubt, refer back to this file or ask the user for clarification.

---

_Made with ❤️ for the smart lighting community_
