# iOS Companion App Integration Guide

## 🌉 Multi-Transport Bridge Architecture

The macOS app now includes a comprehensive multi-transport bridge infrastructure that enables seamless data synchronization with an iOS companion app using **THREE** synchronization methods:

1. **☁️ CloudKit** - Internet-based sync across all devices (anywhere in the world)
2. **📡 Local Network (Bonjour)** - Fast sync over WiFi (same network, no internet needed)
3. **📶 Bluetooth** - Direct device-to-device sync (close proximity, works offline)
4. **📦 App Groups** - Instant sync on same device (between app and widgets)

### Transport Selection Strategy

The app intelligently uses multiple transports simultaneously:
- **Primary**: CloudKit for reliable cross-device sync
- **Fast Path**: Local Network for instant updates when on same WiFi
- **Offline**: Bluetooth for sync without internet or WiFi
- **Widget**: App Groups for same-device data sharing

## 📋 Prerequisites for iOS App

### 1. Xcode Project Setup
```swift
// Required capabilities in your iOS app:
1. App Groups: group.com.govee.mac
2. iCloud: CloudKit container "iCloud.com.govee.smartlights"
3. Background Modes: Remote notifications (for CloudKit sync)
4. Local Network: For Bonjour discovery
5. Bluetooth: For Bluetooth sync
```

### 2. Required Files to Copy
Copy these files from the macOS project to your iOS project:

- `Govee Mac/GoveeModels.swift` - Core data models (GoveeDevice, DeviceGroup, etc.)
- `Govee Mac/Services/CloudSyncManager.swift` - CloudKit + App Groups sync
- `Govee Mac/Services/MultiTransportSyncManager.swift` - ⭐ NEW: Multi-transport coordinator
- `Govee Mac/Services/APIKeyKeychain.swift` - Secure credential storage

## 🔧 Integration Steps

### Step 1: Configure Entitlements

**iOS App Entitlements** (YourApp.entitlements):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- CloudKit -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.govee.smartlights</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    
    <!-- App Groups -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.govee.mac</string>
    </array>
    
    <!-- Bluetooth -->
    <key>com.apple.developer.networking.multipath</key>
    <true/>
</dict>
</plist>
```

**Info.plist Additions:**
```xml
<!-- Local Network -->
<key>NSLocalNetworkUsageDescription</key>
<string>Connect to your Mac for instant sync over local network</string>
<key>NSBonjourServices</key>
<array>
    <string>_smartlights._tcp</string>
</array>

<!-- Bluetooth -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Connect to your Mac via Bluetooth for offline sync</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Connect to your Mac via Bluetooth for offline sync</string>
```

### Step 2: Initialize Multi-Transport Sync Manager

**In your iOS App's main file:**
```swift
import SwiftUI

@main
struct GoveeIOSApp: App {
    @StateObject private var syncManager = UnifiedSyncManager.shared
    @StateObject private var deviceStore = DeviceStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncManager)
                .environmentObject(deviceStore)
                .task {
                    await setupSync()
                }
        }
    }
    
    private func setupSync() async {
        // Enable all transport methods
        do {
            // CloudKit (internet-based)
            try syncManager.enableTransport(.cloud)
            
            // Local Network (WiFi)
            try syncManager.enableTransport(.localNetwork, isServer: false)
            
            // Bluetooth (close proximity)
            try syncManager.enableTransport(.bluetooth, isServer: false)
            
            // App Groups (same device)
            try syncManager.enableTransport(.appGroups)
            
            print("All sync transports enabled")
        } catch {
            print("Sync setup error: \(error)")
        }
        
        // Load initial data
        if let devices = syncManager.cloudSync.loadDevicesFromAppGroups() {
            deviceStore.replaceAll(devices)
        }
        
        // Listen for sync updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DevicesUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            if let devices = notification.object as? [GoveeDevice] {
                deviceStore.replaceAll(devices)
            }
        }
    }
}
```

### Step 3: Create iOS UI with Sync Status

**Device List with Connection Indicator:**
```swift
import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject var deviceStore: DeviceStore
    @EnvironmentObject var syncManager: UnifiedSyncManager
    
    var body: some View {
        NavigationView {
            List {
                ForEach(deviceStore.devices) { device in
                    DeviceRow(device: device)
                }
            }
            .navigationTitle("Smart Lights")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshDevices) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await refreshDevices()
            }
        }
    }
    
    private func refreshDevices() async {
        // Reload from App Groups (instant)
        if let devices = syncManager.loadDevicesFromAppGroups() {
            deviceStore.replaceAll(devices)
        }
        
        // Optionally pull from CloudKit
        do {
            let cloudDevices = try await syncManager.fetchDevicesFromCloud()
            deviceStore.replaceAll(cloudDevices)
        } catch {
            print("Sync failed: \(error)")
        }
    }
}

struct DeviceRow: View {
    let device: GoveeDevice
    
    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(device.isOn == true ? .yellow : .gray)
            
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                
                if let model = device.model {
                    Text(model)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(device.isOn == true ? "On" : "Off")
                    .font(.caption)
                
                if let brightness = device.brightness {
                    Text("\(brightness)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

### Step 4: Implement Device Control

**Note**: The iOS app can read device states but should use the macOS app or HomeKit for control. If you want direct control from iOS, you'll need to implement the control protocols:

```swift
// Option 1: Read-only mode (recommended for first version)
// iOS app displays device status only
// Users control via macOS app, HomeKit, or Home Assistant

// Option 2: Full control mode (requires additional implementation)
// Copy control protocol implementations from macOS app
// Implement HomeKit control (requires HomeKit framework on iOS)
// Or implement REST API endpoints on macOS app for iOS to call
```

## 📱 Data Flow

### Local Sync (App Groups)
```
macOS App → App Groups Container → iOS App
          ↓
      Widget (both platforms)
```

**Instant sync** - Data is available immediately on the same device

### Cloud Sync (CloudKit)
```
macOS App → CloudKit → iOS App
                     ↓
              Other Devices
```

**Cross-device sync** - Data syncs across all user's devices

## 🔄 Sync Strategies

### Strategy 1: App Groups Only (Simplest)
**Best for**: Single device, instant sync with widget
```swift
// iOS app only reads from App Groups
let devices = syncManager.loadDevicesFromAppGroups()
```

### Strategy 2: CloudKit Backup (Recommended)
**Best for**: Multiple devices, backup/restore
```swift
// Load local, then refresh from cloud
if let local = syncManager.loadDevicesFromAppGroups() {
    deviceStore.replaceAll(local)
}

Task {
    if let cloud = try? await syncManager.fetchDevicesFromCloud() {
        deviceStore.replaceAll(cloud)
    }
}
```

### Strategy 3: Real-time Sync (Advanced)
**Best for**: Live updates across devices
```swift
// Subscribe to CloudKit changes
try await syncManager.subscribeToCloudChanges()

// Handle remote notifications
func application(_ application: UIApplication, 
                didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
    Task {
        let devices = try await syncManager.fetchDevicesFromCloud()
        await MainActor.run {
            deviceStore.replaceAll(devices)
        }
    }
}
```

## 🔐 Security Considerations

### API Keys and Credentials
**DO NOT** sync API keys via CloudKit or App Groups:
- Govee API keys
- Home Assistant tokens
- Hue Bridge credentials

These should remain on the macOS app only. The iOS app should:
1. Display device states (synced via App Groups/CloudKit)
2. Control devices via HomeKit (if available)
3. Or send control commands to macOS app via network API

### Recommended Architecture
```
iOS App (Display) ←→ App Groups/CloudKit ←→ macOS App (Control)
                                                    ↓
                                    Govee/Hue/WLED APIs
```

## 📊 Data Models

### GoveeDevice
```swift
struct GoveeDevice: Identifiable, Codable {
    let id: String
    var name: String
    var model: String?
    var online: Bool
    var isOn: Bool?
    var brightness: Int?
    // ... other properties
}
```

### DeviceGroup
```swift
struct DeviceGroup: Identifiable, Codable {
    let id: String
    var name: String
    var memberIDs: [String]
}
```

### SyncedSettings
```swift
struct SyncedSettings: Codable {
    var prefersLan: Bool
    var homeKitEnabled: Bool
    var dmxEnabled: Bool
}
```

## 🧪 Testing

### Test App Groups Sync
```swift
// In macOS app
syncManager.saveDevicesToAppGroups(devices)

// In iOS app (same device)
let devices = syncManager.loadDevicesFromAppGroups()
// Should immediately show devices
```

### Test CloudKit Sync
```swift
// In macOS app
try await syncManager.syncDevicesToCloud(devices)

// In iOS app (any device, same iCloud account)
let devices = try await syncManager.fetchDevicesFromCloud()
// Should show devices after cloud sync
```

## 🚀 Quick Start iOS App

Minimal iOS app to display synced devices:

```swift
import SwiftUI

@main
struct SmartLightsIOSApp: App {
    @StateObject private var syncManager = CloudSyncManager.shared
    @StateObject private var deviceStore = DeviceStore()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                List(deviceStore.devices) { device in
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(device.isOn == true ? .yellow : .gray)
                        Text(device.name)
                        Spacer()
                        if let brightness = device.brightness {
                            Text("\(brightness)%")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .navigationTitle("Govee Lights")
                .task {
                    if let devices = syncManager.loadDevicesFromAppGroups() {
                        deviceStore.replaceAll(devices)
                    }
                }
            }
        }
    }
}
```

## 📚 Additional Resources

- [Apple CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [App Groups Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
- [macOS/iOS Code Sharing Guide](https://developer.apple.com/documentation/xcode/sharing-code-between-macos-and-ios)

## 💡 Tips

1. **Start Simple**: Begin with App Groups read-only sync
2. **Add CloudKit**: Enable cloud sync for multi-device support
3. **Implement Control**: Add HomeKit control or REST API
4. **Real-time Sync**: Use CloudKit subscriptions for live updates
5. **Test Thoroughly**: Test on both simulator and real devices

## 🐛 Troubleshooting

### Devices Not Showing in iOS App
- Check App Groups identifier matches: `group.com.govee.mac`
- Verify entitlements are enabled in Xcode
- Ensure macOS app has saved devices at least once

### CloudKit Sync Not Working
- Verify user is signed into iCloud
- Check CloudKit container identifier: `iCloud.com.govee.smartlights`
- Enable CloudKit capability in Xcode
- Check CloudKit Dashboard for container setup

### Build Errors
- Ensure all required files are copied to iOS project
- Update import statements for iOS (remove `HomeKit` if not using)
- Check target membership for all files

---

**Ready to build your iOS companion app!** 🎉

Start with the simple App Groups sync, then progressively add CloudKit and control features.
