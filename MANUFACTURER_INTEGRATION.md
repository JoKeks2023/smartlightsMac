# Smart Light Manufacturer Integration Guide

## 🌟 Overview

This document explains how different smart light manufacturers can be integrated with Govee Mac, including **Philips Hue**, LIFX, Nanoleaf, TP-Link Kasa, WLED, and others.

## ✅ Currently Supported Integration Methods

### 1. **Native Protocol Support** (⭐ NEW!)
The app now includes native protocol support for several manufacturers with direct local network control:

#### Supported via Native Protocols:
- ✅ **Philips Hue** - Native Hue Bridge API discovery and control
- ✅ **WLED** - Direct REST API control for WLED controllers  
- ⚠️ **LIFX** - LAN protocol support (partial implementation)

#### How it Works:
- **Automatic Discovery**: Discovers Hue Bridges, WLED controllers, and LIFX lights via mDNS/Bonjour
- **Direct Control**: No additional hubs or servers required
- **Fast Response**: Local network communication for instant control

#### Setup:
1. Ensure devices are on the same network as your Mac
2. Open Govee Mac and click Refresh
3. Discovered devices appear with respective badges (Hue, WLED, LIFX)

**Note:** Philips Hue Bridge requires API key registration (press link button during first use)

---

### 2. **HomeKit/Matter Integration** (Recommended for maximum compatibility)
The app already includes native HomeKit support, which works with **any** HomeKit-compatible smart light:

#### Supported Manufacturers via HomeKit:
- ✅ **Philips Hue** (if connected to HomeKit)
- ✅ LIFX
- ✅ Nanoleaf
- ✅ Eve Light
- ✅ Meross
- ✅ Govee (Matter-compatible models)
- ✅ Any other HomeKit-compatible smart lights

#### How to Enable:
1. **Add your lights to Apple Home** first:
   - Open Home app on macOS/iOS
   - Add your Philips Hue Bridge (or other lights)
   - Follow manufacturer setup instructions

2. **Enable HomeKit in Govee Mac**:
   - Open Govee Mac app
   - Go to Settings (⌘,)
   - Toggle "Enable HomeKit (Matter)"
   - Grant permission when prompted
   - Your HomeKit lights will appear with "HomeKit" badge

#### Advantages:
- ✅ Native Apple integration
- ✅ Secure and reliable
- ✅ No additional API keys needed
- ✅ Works with all HomeKit accessories
- ✅ Local network control (fast response)

#### Limitations:
- ⚠️ Requires devices to be HomeKit-compatible
- ⚠️ Must be set up in Home app first

---

### 3. **Home Assistant Integration** (Universal Solution)
For the most flexibility, use Home Assistant as a universal bridge:

#### Supported Manufacturers via Home Assistant:
- ✅ **Philips Hue** (via Hue integration)
- ✅ LIFX
- ✅ TP-Link Kasa/Tapo
- ✅ Nanoleaf
- ✅ Yeelight
- ✅ WLED
- ✅ Tuya/Smart Life
- ✅ Govee
- ✅ Zigbee lights (via Zigbee2MQTT, ZHA)
- ✅ Z-Wave lights
- ✅ **100+ other integrations**

#### How to Enable:
1. **Set up Home Assistant**:
   - Install Home Assistant ([hassio.io](https://www.home-assistant.io))
   - Add your lights through HA integrations
   - For Philips Hue: Use the built-in Hue integration

2. **Connect Govee Mac to Home Assistant**:
   - Open Govee Mac Settings
   - Enter your HA Base URL (e.g., `http://homeassistant.local:8123`)
   - Generate a Long-Lived Access Token in HA:
     - Profile → Security → Long-Lived Access Tokens
     - Create token → Copy it
   - Paste token in Govee Mac Settings
   - Devices containing "govee", "hue", "lifx", etc. in friendly name will appear

#### Advantages:
- ✅ Supports virtually **any** smart light brand
- ✅ Advanced automation and control
- ✅ Single interface for all smart devices
- ✅ Local network control
- ✅ Powerful scene and script support

#### Limitations:
- ⚠️ Requires Home Assistant setup and maintenance
- ⚠️ Additional hardware recommended (Raspberry Pi, NUC, etc.)

---

### 4. **LAN Discovery** (Automatic for Native Protocols)
The app automatically discovers devices on your local network via mDNS/Bonjour:

#### Currently Scanned Service Types:
- `_govee._tcp.` - Govee devices
- `_wled._tcp.` - WLED controllers  
- `_hap._tcp.` - HomeKit devices (including Hue Bridge)
- `_lifx._tcp.` - LIFX lights
- `_http._tcp.` - Generic HTTP-based lights

#### Manufacturers with Native LAN Support:
- ✅ Govee (full native support)
- ✅ WLED (REST API implemented)
- ✅ Philips Hue Bridge (native API implemented)
- ⚠️ LIFX (partial LAN protocol - work in progress)

#### How to Enable:
1. Open Govee Mac Settings
2. Enable "Prefer LAN when available"
3. Click Refresh to discover devices
4. Discovered devices show their transport badge (WLED, Hue, LIFX, LAN)

#### Limitations:
- ⚠️ LIFX LAN protocol requires UDP binary protocol (HTTP API preferred)
- ⚠️ Not all devices broadcast mDNS
- ⚠️ Hue Bridge requires link button press for initial API key generation

---

## 🔧 Native Philips Hue Bridge API Support (✅ IMPLEMENTED)

### Features
Native Hue Bridge API support provides:
- ✅ Direct control without HomeKit or HA
- ✅ Automatic bridge discovery via Hue cloud and mDNS
- ✅ Full light control (power, brightness, color, color temperature)
- ⚠️ Scenes and entertainment mode (future enhancement)

### How It Works

#### 1. Hue Bridge Discovery
```swift
struct HueDiscovery: DeviceDiscoveryProtocol {
    func refreshDevices() async throws -> [GoveeDevice] {
        // Discover Hue Bridges via SSDP or mDNS (_hue._tcp.)
        // Register application with bridge (button press required first time)
        // Get list of lights from bridge API
        // Convert to GoveeDevice format
    }
}
```

#### 2. Hue Control Protocol
```swift
struct HueControl: DeviceControlProtocol {
    let bridgeIP: String
    let apiKey: String
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        // PUT /api/{apiKey}/lights/{id}/state
        // {"on": true/false}
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        // PUT /api/{apiKey}/lights/{id}/state
        // {"bri": 0-254}
    }
    
    // ... other methods
}
```

#### 3. Add to TransportKind
```swift
enum TransportKind: String, Codable, Hashable {
    case cloud, lan, homeKit, homeAssistant, dmx, hue
}
```

#### 4. Integration Steps
1. User presses physical button on Hue Bridge
2. App discovers bridge and creates API key
3. Bridge IP and API key stored in Keychain
4. Lights discovered and added to device list
5. Control commands sent via Hue API v2

### Hue API Resources
- [Philips Hue API Documentation](https://developers.meethue.com/)
- [Hue API v2](https://developers.meethue.com/develop/hue-api-v2/)
- Discovery: `https://discovery.meethue.com/`
- mDNS: `_hue._tcp.local.`

---

## 🎯 Recommended Approach for Each Manufacturer

### Philips Hue
**✅ Best Option: HomeKit Integration**
- Add Hue Bridge to Home app
- Enable HomeKit in Govee Mac
- All lights appear automatically

**Alternative: Home Assistant**
- Install Hue integration in HA
- Connect Govee Mac to HA
- More advanced control options

**Future: Native Hue API**
- Direct bridge communication
- Access to Hue-specific features

### LIFX
**✅ Best Option: HomeKit** (if LIFX lights are HomeKit-compatible)
**Alternative: Home Assistant** with LIFX integration

### TP-Link Kasa/Tapo
**✅ Best Option: Home Assistant**
- Use TP-Link Kasa/Tapo integration
- Connect Govee Mac to HA

### Nanoleaf
**✅ Best Option: HomeKit**
- Native HomeKit support
- Excellent integration

### Yeelight
**✅ Best Option: Home Assistant**
- Use Yeelight integration in HA

### WLED
**✅ Option: Home Assistant** or future native LAN protocol implementation

### Tuya/Smart Life Devices
**✅ Best Option: Home Assistant**
- Use Tuya/LocalTuya integration

---

## 📊 Feature Comparison

| Method | Philips Hue | LIFX | Others | Setup Complexity | Features |
|--------|-------------|------|--------|------------------|----------|
| **HomeKit** | ✅ Excellent | ✅ Good | ✅ Many | ⭐⭐ Easy | Standard HomeKit features |
| **Home Assistant** | ✅ Excellent | ✅ Excellent | ✅ All | ⭐⭐⭐⭐ Advanced | Full manufacturer features |
| **LAN Discovery** | ⚠️ Partial | ⚠️ Partial | ⚠️ Limited | ⭐⭐⭐ Medium | Limited (needs protocol impl) |
| **Native API** | 🔄 Future | 🔄 Future | ❌ No | ⭐⭐⭐ Medium | Manufacturer-specific |

---

## 🚀 Quick Start Guide

### For Philips Hue Users

#### Option 1: Native Hue Bridge API (⭐ NEW - Direct Control)
1. Ensure your **Philips Hue Bridge** is on the same network
2. Open **Govee Mac** and click Refresh
3. Bridge will be discovered automatically
4. **First time only**: Press the link button on your Hue Bridge when prompted
5. ✅ Your Hue lights appear instantly with "Hue" badge!

#### Option 2: HomeKit (Easy & Reliable)
1. Open **Home** app on macOS
2. Add your **Philips Hue Bridge**:
   - Tap + → Add Accessory
   - Follow on-screen instructions
   - Enter code on bottom of bridge
3. Open **Govee Mac**:
   - Settings → Enable "HomeKit (Matter)"
   - Grant permission
4. ✅ Your Hue lights now appear in Govee Mac!

#### Option 3: Home Assistant (Most Powerful)
1. Install **Home Assistant** ([installation guide](https://www.home-assistant.io/installation/))
2. Add **Hue integration** in HA:
   - Configuration → Integrations → Add Hue
   - Press button on bridge → Discover lights
3. Connect **Govee Mac** to HA:
   - Settings → Enter HA URL and token
4. ✅ Your Hue lights now appear in Govee Mac!

---

## 💡 Tips

### Naming Conventions
When using Home Assistant, ensure your light entities have recognizable names:
- Good: `light.hue_living_room`, `light.philips_bedroom`
- Avoid: `light.light_1`, `light.device_abc123`

The app searches for common manufacturer names in entity IDs and friendly names.

### Multiple Integration Methods
You can use multiple methods simultaneously:
- HomeKit for some devices
- Home Assistant for others
- Govee Cloud API for Govee devices
- All devices appear in one unified interface!

### Network Requirements
- All methods work on **local network** (no internet required for control)
- Cloud APIs (Govee) require internet for discovery
- LAN and HomeKit are fully local

---

## 🔮 Future Enhancements

### Completed ✅
- [x] Native Philips Hue Bridge API support
- [x] WLED API integration  
- [x] LAN discovery for multiple manufacturers

### In Progress ⚠️
- [ ] LIFX LAN protocol (UDP binary protocol implementation)
- [ ] Hue Entertainment mode support
- [ ] Hue Scenes integration

### Planned 📋
- [ ] Nanoleaf OpenAPI support
- [ ] TP-Link Kasa local protocol
- [ ] Yeelight LAN protocol
- [ ] Full LIFX binary protocol over UDP

### Community Contributions Welcome!
Want to add support for your favorite manufacturer? Check [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines!

---

## 📚 Additional Resources

- [HomeKit Setup Guide](https://support.apple.com/guide/home/welcome/mac)
- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [Philips Hue Developer Portal](https://developers.meethue.com/)
- [Govee Mac README](README.md)

---

## ❓ FAQ

### Q: Can I use Philips Hue with Govee Mac today?
**A:** Yes! Use either HomeKit or Home Assistant integration. Both work excellently.

### Q: Do I need a paid subscription?
**A:** No! All integration methods are free. HomeKit is built into macOS, and Home Assistant is open source.

### Q: Will my Hue scenes work?
**A:** Via Home Assistant, yes. HomeKit has limited scene support. Native Hue API would provide full scene access (future enhancement).

### Q: Can I control Govee and Hue lights together?
**A:** Absolutely! The app's group feature lets you control multiple manufacturers simultaneously.

### Q: Do I need the internet?
**A:** For control: No (all methods work locally). For initial setup: Yes (to discover and register devices).

---

Made with ❤️ for the smart lighting community
