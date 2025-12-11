# iOS Bridge Developer Guide

> **📱 iOS Companion App Now Available!**  
> The official iOS companion app is ready to use: [SmartLights iOS Companion](https://github.com/JoKeks2023/smartlightsMac-ios-companion)  
> For ready-to-use code and complete implementation, visit the iOS companion repository above.

---

## 🎯 Complete Guide to Building the iOS Companion App

This guide provides everything you need to build a fully-functional iOS companion app that can **control everything** in the macOS app, including devices, groups, and settings.

---

## 📚 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Quick Start](#quick-start)
3. [Sync Methods](#sync-methods)
4. [Device Control](#device-control)
5. [Group Management](#group-management)
6. [Settings Control](#settings-control)
7. [Connection Management](#connection-management)
8. [Complete Code Examples](#complete-code-examples)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### The Three-Layer System

```
┌─────────────────────────────────────────┐
│         iOS App (Full Control)          │
├─────────────────────────────────────────┤
│    RemoteControlClient (Control API)    │
├─────────────────────────────────────────┤
│  UnifiedSyncManager (Multi-Transport)   │
├──────────┬──────────┬──────────┬────────┤
│ CloudKit │ Bonjour  │Bluetooth │AppGroup│
└──────────┴──────────┴──────────┴────────┘
           │          │          │
┌──────────┴──────────┴──────────┴────────┐
│  UnifiedSyncManager (Multi-Transport)   │
├─────────────────────────────────────────┤
│   RemoteControlHandler (Command Router) │
├─────────────────────────────────────────┤
│      macOS App (Command Executor)       │
└─────────────────────────────────────────┘
```

### What You Get

**Full Control Capabilities:**
- ✅ Turn devices on/off
- ✅ Adjust brightness (0-100%)
- ✅ Change colors (RGB)
- ✅ Set color temperature
- ✅ Control groups
- ✅ Create/edit/delete groups
- ✅ Update all settings
- ✅ Trigger device discovery
- ✅ Real-time sync

**Three Sync Methods:**
- ☁️ **CloudKit** - Internet-based, works anywhere
- 📡 **Local Network** - Fast, same WiFi
- 📶 **Bluetooth** - Close proximity, offline

---

## Quick Start

### Step 1: Copy Required Files

Copy these 4 files to your iOS project:

```
From macOS Project → To iOS Project
├── GoveeModels.swift → Shared/Models/
├── CloudSyncManager.swift → Shared/Services/
├── MultiTransportSyncManager.swift → Shared/Services/
└── RemoteControlProtocol.swift → Shared/Services/
```

### Step 2: Configure Capabilities

**In Xcode → Target → Signing & Capabilities:**

1. **App Groups**
   - Click "+" → App Groups
   - Add `group.com.govee.mac`

2. **iCloud**
   - Click "+" → iCloud
   - Enable CloudKit
   - Add container: `iCloud.com.govee.smartlights`

3. **Background Modes**
   - Enable "Remote notifications"

### Step 3: Update Info.plist

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Connect to your Mac for instant sync</string>

<key>NSBonjourServices</key>
<array>
    <string>_smartlights._tcp</string>
</array>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>Connect to your Mac via Bluetooth</string>
```

### Step 4: Create App Entry Point

```swift
import SwiftUI

@main
struct SmartLightsApp: App {
    @StateObject private var syncManager = UnifiedSyncManager.shared
    @StateObject private var controlClient: RemoteControlClient
    @StateObject private var deviceStore = DeviceStore()
    
    init() {
        let sync = UnifiedSyncManager.shared
        _controlClient = StateObject(wrappedValue: RemoteControlClient(syncManager: sync))
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(syncManager)
                .environmentObject(controlClient)
                .environmentObject(deviceStore)
                .task {
                    await setupApp()
                }
        }
    }
    
    private func setupApp() async {
        // Enable all sync transports
        try? syncManager.enableTransport(.cloud)
        try? syncManager.enableTransport(.localNetwork, isServer: false)
        try? syncManager.enableTransport(.bluetooth, isServer: false)
        try? syncManager.enableTransport(.appGroups)
        
        // Load initial data
        if let devices = syncManager.cloudSync.loadDevicesFromAppGroups() {
            deviceStore.replaceAll(devices)
        }
        
        // Listen for updates
        setupSyncListeners()
    }
    
    private func setupSyncListeners() {
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

---

## Sync Methods

### Understanding the Three Sync Transports

#### 1. CloudKit (Internet-Based)

**When to use:** Always enabled, works anywhere
**Latency:** 1-5 seconds
**Range:** Worldwide

```swift
// Automatically enabled
// Data syncs when internet available
```

#### 2. Local Network (Bonjour)

**When to use:** Same WiFi network
**Latency:** <100ms (instant)
**Range:** Same network

```swift
// Enable browsing (iOS)
try syncManager.enableTransport(.localNetwork, isServer: false)

// Check connection status
if syncManager.isConnectedViaLocalNetwork {
    print("Connected to Mac via WiFi")
}
```

#### 3. Bluetooth

**When to use:** Close proximity, no WiFi
**Latency:** <500ms (very fast)
**Range:** ~10 meters

```swift
// Enable Bluetooth sync
try syncManager.enableTransport(.bluetooth, isServer: false)

// Check connection status
if syncManager.isConnectedViaBluetooth {
    print("Connected to Mac via Bluetooth")
}
```

---

## Device Control

### Turn Device On/Off

```swift
import SwiftUI

struct DeviceToggleButton: View {
    let device: GoveeDevice
    @EnvironmentObject var controlClient: RemoteControlClient
    @State private var isOn: Bool
    
    init(device: GoveeDevice) {
        self.device = device
        _isOn = State(initialValue: device.isOn ?? false)
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(device.name)
        }
        .onChange(of: isOn) { newValue in
            Task {
                do {
                    try await controlClient.setDevicePower(
                        deviceID: device.id,
                        on: newValue
                    )
                } catch {
                    print("Failed to set power: \(error)")
                    isOn.toggle() // Revert on error
                }
            }
        }
    }
}
```

### Brightness Control

```swift
struct BrightnessSlider: View {
    let device: GoveeDevice
    @EnvironmentObject var controlClient: RemoteControlClient
    @State private var brightness: Double
    
    init(device: GoveeDevice) {
        self.device = device
        _brightness = State(initialValue: Double(device.brightness ?? 100))
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Brightness: \(Int(brightness))%")
                .font(.caption)
            
            Slider(value: $brightness, in: 0...100, step: 1)
                .onChange(of: brightness) { newValue in
                    Task {
                        try? await controlClient.setDeviceBrightness(
                            deviceID: device.id,
                            value: Int(newValue)
                        )
                    }
                }
        }
    }
}
```

### Color Picker

```swift
struct ColorPickerView: View {
    let device: GoveeDevice
    @EnvironmentObject var controlClient: RemoteControlClient
    @State private var selectedColor: Color = .white
    
    var body: some View {
        ColorPicker("Select Color", selection: $selectedColor)
            .onChange(of: selectedColor) { newColor in
                Task {
                    let deviceColor = DeviceColor(from: newColor)
                    try? await controlClient.setDeviceColor(
                        deviceID: device.id,
                        color: deviceColor
                    )
                }
            }
    }
}

// Extension to convert SwiftUI Color to DeviceColor
extension DeviceColor {
    init(from color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        self.init(
            r: Int(red * 255),
            g: Int(green * 255),
            b: Int(blue * 255)
        )
    }
}
```

### Color Temperature Control

```swift
struct ColorTemperatureSlider: View {
    let device: GoveeDevice
    @EnvironmentObject var controlClient: RemoteControlClient
    @State private var temperature: Double = 4000 // Default warm white
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Warm")
                    .font(.caption)
                Spacer()
                Text("\(Int(temperature))K")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("Cool")
                    .font(.caption)
            }
            
            Slider(value: $temperature, in: 2000...9000, step: 100)
                .onChange(of: temperature) { newValue in
                    Task {
                        try? await controlClient.setDeviceColorTemperature(
                            deviceID: device.id,
                            temp: Int(newValue)
                        )
                    }
                }
        }
    }
}
```

### Complete Device Control View

```swift
struct DeviceControlView: View {
    let device: GoveeDevice
    @EnvironmentObject var controlClient: RemoteControlClient
    @State private var isOn: Bool
    @State private var brightness: Double
    @State private var selectedColor: Color = .white
    @State private var colorTemp: Double = 4000
    
    init(device: GoveeDevice) {
        self.device = device
        _isOn = State(initialValue: device.isOn ?? false)
        _brightness = State(initialValue: Double(device.brightness ?? 100))
    }
    
    var body: some View {
        Form {
            Section("Power") {
                Toggle("Device Power", isOn: $isOn)
                    .onChange(of: isOn) { newValue in
                        Task {
                            try? await controlClient.setDevicePower(
                                deviceID: device.id,
                                on: newValue
                            )
                        }
                    }
            }
            
            Section("Brightness") {
                VStack {
                    Text("\(Int(brightness))%")
                    Slider(value: $brightness, in: 0...100)
                        .onChange(of: brightness) { newValue in
                            Task {
                                try? await controlClient.setDeviceBrightness(
                                    deviceID: device.id,
                                    value: Int(newValue)
                                )
                            }
                        }
                }
            }
            
            if device.supportsColor {
                Section("Color") {
                    ColorPicker("Select Color", selection: $selectedColor)
                        .onChange(of: selectedColor) { newColor in
                            Task {
                                let deviceColor = DeviceColor(from: newColor)
                                try? await controlClient.setDeviceColor(
                                    deviceID: device.id,
                                    color: deviceColor
                                )
                            }
                        }
                }
            }
            
            if device.supportsColorTemperature {
                Section("Color Temperature") {
                    VStack {
                        Text("\(Int(colorTemp))K")
                        Slider(value: $colorTemp, in: 2000...9000)
                            .onChange(of: colorTemp) { newValue in
                                Task {
                                    try? await controlClient.setDeviceColorTemperature(
                                        deviceID: device.id,
                                        temp: Int(newValue)
                                    )
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle(device.name)
    }
}
```

---

## Group Management

### List Groups

```swift
struct GroupListView: View {
    @EnvironmentObject var deviceStore: DeviceStore
    
    var body: some View {
        List(deviceStore.groups) { group in
            NavigationLink(destination: GroupControlView(group: group)) {
                HStack {
                    Image(systemName: "rectangle.3.group")
                    Text(group.name)
                    Spacer()
                    Text("\(group.memberIDs.count) devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Groups")
    }
}
```

### Create Group

```swift
struct CreateGroupView: View {
    @EnvironmentObject var controlClient: RemoteControlClient
    @EnvironmentObject var deviceStore: DeviceStore
    @Environment(\.dismiss) var dismiss
    
    @State private var groupName = ""
    @State private var selectedDeviceIDs: Set<String> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Group Name") {
                    TextField("Living Room Lights", text: $groupName)
                }
                
                Section("Select Devices") {
                    ForEach(deviceStore.devices) { device in
                        Toggle(device.name, isOn: Binding(
                            get: { selectedDeviceIDs.contains(device.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDeviceIDs.insert(device.id)
                                } else {
                                    selectedDeviceIDs.remove(device.id)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            try? await controlClient.createGroup(
                                name: groupName,
                                memberIDs: Array(selectedDeviceIDs)
                            )
                            dismiss()
                        }
                    }
                    .disabled(groupName.isEmpty || selectedDeviceIDs.isEmpty)
                }
            }
        }
    }
}
```

### Control Group

```swift
struct GroupControlView: View {
    let group: DeviceGroup
    @EnvironmentObject var controlClient: RemoteControlClient
    @State private var isOn = false
    @State private var brightness: Double = 100
    @State private var selectedColor: Color = .white
    
    var body: some View {
        Form {
            Section("Group Control") {
                Toggle("All Devices", isOn: $isOn)
                    .onChange(of: isOn) { newValue in
                        Task {
                            try? await controlClient.setGroupPower(
                                groupID: group.id,
                                on: newValue
                            )
                        }
                    }
            }
            
            Section("Brightness") {
                VStack {
                    Text("\(Int(brightness))%")
                    Slider(value: $brightness, in: 0...100)
                        .onChange(of: brightness) { newValue in
                            Task {
                                try? await controlClient.setGroupBrightness(
                                    groupID: group.id,
                                    value: Int(newValue)
                                )
                            }
                        }
                }
            }
            
            Section("Color") {
                ColorPicker("Select Color", selection: $selectedColor)
                    .onChange(of: selectedColor) { newColor in
                        Task {
                            let deviceColor = DeviceColor(from: newColor)
                            try? await controlClient.setGroupColor(
                                groupID: group.id,
                                color: deviceColor
                            )
                        }
                    }
            }
            
            Section("Devices") {
                ForEach(group.memberIDs, id: \.self) { deviceID in
                    if let device = deviceStore.devices.first(where: { $0.id == deviceID }) {
                        Text(device.name)
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    // Show edit sheet
                }
            }
        }
    }
}
```

### Delete Group

```swift
Button(role: .destructive) {
    Task {
        try? await controlClient.deleteGroup(groupID: group.id)
    }
} label: {
    Label("Delete Group", systemImage: "trash")
}
```

---

## Settings Control

### Settings View

```swift
struct SettingsView: View {
    @EnvironmentObject var controlClient: RemoteControlClient
    @State private var settings: SyncedSettings?
    @State private var prefersLAN = true
    @State private var homeKitEnabled = false
    @State private var dmxEnabled = false
    @State private var haBaseURL = ""
    @State private var haToken = ""
    
    var body: some View {
        Form {
            Section("Sync Preferences") {
                Toggle("Prefer LAN Control", isOn: $prefersLAN)
                Toggle("Enable HomeKit", isOn: $homeKitEnabled)
                Toggle("Enable DMX", isOn: $dmxEnabled)
            }
            
            Section("Home Assistant") {
                TextField("Base URL", text: $haBaseURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                
                SecureField("Access Token", text: $haToken)
            }
            
            Section {
                Button("Save Settings") {
                    Task {
                        let update = SettingsUpdateCommand(
                            prefersLan: prefersLAN,
                            homeKitEnabled: homeKitEnabled,
                            dmxEnabled: dmxEnabled,
                            haBaseURL: haBaseURL.isEmpty ? nil : haBaseURL,
                            haToken: haToken.isEmpty ? nil : haToken
                        )
                        try? await controlClient.updateSettings(update)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            await loadSettings()
        }
    }
    
    private func loadSettings() async {
        do {
            let loaded = try await controlClient.getSettings()
            settings = loaded
            prefersLAN = loaded.prefersLan
            homeKitEnabled = loaded.homeKitEnabled
            dmxEnabled = loaded.dmxEnabled
        } catch {
            print("Failed to load settings: \(error)")
        }
    }
}
```

---

## Connection Management

### Connection Status View

```swift
struct ConnectionStatusView: View {
    @EnvironmentObject var syncManager: UnifiedSyncManager
    
    var body: some View {
        HStack {
            Image(systemName: connectionIcon)
                .foregroundColor(connectionColor)
            
            Text(syncManager.connectionStatus)
                .font(.caption)
            
            if syncManager.cloudSync.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
    
    private var connectionIcon: String {
        if syncManager.isConnectedViaLocalNetwork {
            return "wifi"
        } else if syncManager.isConnectedViaBluetooth {
            return "antenna.radiowaves.left.and.right"
        } else if syncManager.isConnectedViaCloud {
            return "icloud"
        } else {
            return "wifi.slash"
        }
    }
    
    private var connectionColor: Color {
        if syncManager.isConnectedViaLocalNetwork || syncManager.isConnectedViaBluetooth {
            return .green
        } else if syncManager.isConnectedViaCloud {
            return .blue
        } else {
            return .gray
        }
    }
}
```

### Manual Connection View

```swift
struct ConnectionManagementView: View {
    @EnvironmentObject var syncManager: UnifiedSyncManager
    
    var body: some View {
        Form {
            Section("Active Connections") {
                HStack {
                    Image(systemName: "icloud")
                    Text("CloudKit")
                    Spacer()
                    if syncManager.isConnectedViaCloud {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                HStack {
                    Image(systemName: "wifi")
                    Text("Local Network")
                    Spacer()
                    if syncManager.isConnectedViaLocalNetwork {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(syncManager.localNetworkSync.connectedPeers.count)")
                            .font(.caption)
                    }
                }
                
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Bluetooth")
                    Spacer()
                    if syncManager.isConnectedViaBluetooth {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(syncManager.bluetoothSync.connectedPeers.count)")
                            .font(.caption)
                    }
                }
            }
            
            Section("Discovered Devices") {
                if !syncManager.localNetworkSync.discoveredPeers.isEmpty {
                    ForEach(Array(syncManager.localNetworkSync.discoveredPeers.enumerated()), id: \.offset) { _, peer in
                        Button("Connect via WiFi") {
                            syncManager.localNetworkSync.connect(to: peer)
                        }
                    }
                }
                
                if !syncManager.bluetoothSync.discoveredPeers.isEmpty {
                    ForEach(syncManager.bluetoothSync.discoveredPeers, id: \.self) { peer in
                        Text(peer.displayName)
                    }
                }
            }
            
            Section {
                Button("Refresh Devices") {
                    Task {
                        try? await controlClient.refreshDevices()
                    }
                }
            }
        }
        .navigationTitle("Connections")
    }
}
```

---

## Complete Code Examples

### Main App Structure

```swift
// File: SmartLightsApp.swift
import SwiftUI

@main
struct SmartLightsApp: App {
    @StateObject private var syncManager = UnifiedSyncManager.shared
    @StateObject private var controlClient: RemoteControlClient
    @StateObject private var deviceStore = DeviceStore()
    
    init() {
        let sync = UnifiedSyncManager.shared
        _controlClient = StateObject(wrappedValue: RemoteControlClient(syncManager: sync))
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(syncManager)
                .environmentObject(controlClient)
                .environmentObject(deviceStore)
                .task {
                    await setupApp()
                }
        }
    }
    
    private func setupApp() async {
        // Enable all transports
        try? syncManager.enableTransport(.cloud)
        try? syncManager.enableTransport(.localNetwork, isServer: false)
        try? syncManager.enableTransport(.bluetooth, isServer: false)
        try? syncManager.enableTransport(.appGroups)
        
        // Load data
        if let devices = syncManager.cloudSync.loadDevicesFromAppGroups() {
            deviceStore.replaceAll(devices)
        }
        
        if let groups = syncManager.cloudSync.loadGroupsFromAppGroups() {
            deviceStore.groups = groups
        }
        
        // Setup listeners
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DevicesUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            if let devices = notification.object as? [GoveeDevice] {
                deviceStore.replaceAll(devices)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GroupsUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            if let groups = notification.object as? [DeviceGroup] {
                deviceStore.groups = groups
            }
        }
    }
}

// File: MainTabView.swift
struct MainTabView: View {
    var body: some View {
        TabView {
            DeviceListView()
                .tabItem {
                    Label("Devices", systemImage: "lightbulb")
                }
            
            GroupListView()
                .tabItem {
                    Label("Groups", systemImage: "rectangle.3.group")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// File: DeviceListView.swift
struct DeviceListView: View {
    @EnvironmentObject var deviceStore: DeviceStore
    @EnvironmentObject var controlClient: RemoteControlClient
    @EnvironmentObject var syncManager: UnifiedSyncManager
    
    var body: some View {
        NavigationView {
            List {
                ForEach(deviceStore.devices) { device in
                    NavigationLink(destination: DeviceControlView(device: device)) {
                        DeviceRowView(device: device)
                    }
                }
            }
            .navigationTitle("Smart Lights")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ConnectionStatusView()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await refresh()
            }
        }
    }
    
    private func refresh() async {
        // Refresh from Mac
        try? await controlClient.refreshDevices()
        
        // Wait a moment for sync
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Reload from App Groups
        if let devices = syncManager.cloudSync.loadDevicesFromAppGroups() {
            deviceStore.replaceAll(devices)
        }
    }
}

// File: DeviceRowView.swift
struct DeviceRowView: View {
    let device: GoveeDevice
    @EnvironmentObject var controlClient: RemoteControlClient
    @State private var isOn: Bool
    
    init(device: GoveeDevice) {
        self.device = device
        _isOn = State(initialValue: device.isOn ?? false)
    }
    
    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(isOn ? .yellow : .gray)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    if let model = device.model {
                        Text(model)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !device.transports.isEmpty {
                        ForEach(Array(device.transports), id: \.self) { transport in
                            Text(transport.rawValue.uppercased())
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let brightness = device.brightness {
                    Text("\(brightness)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .onChange(of: isOn) { newValue in
                        Task {
                            try? await controlClient.setDevicePower(
                                deviceID: device.id,
                                on: newValue
                            )
                        }
                    }
            }
        }
        .padding(.vertical, 4)
    }
}
```

---

## Best Practices

### 1. Error Handling

```swift
func setDevicePower(device: GoveeDevice, on: Bool) async {
    do {
        try await controlClient.setDevicePower(deviceID: device.id, on: on)
    } catch {
        // Show user-friendly error
        await showError("Failed to control device: \(error.localizedDescription)")
        // Optionally revert UI state
    }
}
```

### 2. Optimistic UI Updates

```swift
// Update UI immediately for better UX
@State private var brightness: Double = 50

Slider(value: $brightness, in: 0...100)
    .onChange(of: brightness) { newValue in
        // Debounce updates
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            Task {
                try? await controlClient.setDeviceBrightness(
                    deviceID: device.id,
                    value: Int(newValue)
                )
            }
        }
    }
```

### 3. Connection Fallback

```swift
func sendCommand() async throws {
    // Try fastest connection first
    if syncManager.isConnectedViaLocalNetwork {
        // Use local network
    } else if syncManager.isConnectedViaBluetooth {
        // Use Bluetooth
    } else if syncManager.isConnectedViaCloud {
        // Use CloudKit
    } else {
        throw ConnectionError.notConnected
    }
}
```

### 4. Battery Optimization

```swift
// Disable Bluetooth when app goes to background
.onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
    syncManager.disableTransport(.bluetooth)
}

// Re-enable when coming to foreground
.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
    try? syncManager.enableTransport(.bluetooth, isServer: false)
}
```

---

## Troubleshooting

### Issue: No Connection to Mac

**Solution:**
```swift
// Check each transport
print("Cloud: \(syncManager.isConnectedViaCloud)")
print("Local Network: \(syncManager.isConnectedViaLocalNetwork)")
print("Bluetooth: \(syncManager.isConnectedViaBluetooth)")

// Try re-enabling transports
try? syncManager.enableTransport(.localNetwork, isServer: false)
try? syncManager.enableTransport(.bluetooth, isServer: false)
```

### Issue: Commands Not Working

**Solution:**
```swift
// Verify RemoteControlClient is initialized
@EnvironmentObject var controlClient: RemoteControlClient

// Check for responses
print("Last response: \(controlClient.lastResponse?.success ?? false)")

// Check pending commands
print("Pending: \(controlClient.pendingCommands.count)")
```

### Issue: Devices Not Syncing

**Solution:**
```swift
// Force refresh
if let devices = syncManager.cloudSync.loadDevicesFromAppGroups() {
    deviceStore.replaceAll(devices)
}

// Request fresh data from Mac
try? await controlClient.refreshDevices()
```

---

## 🎉 You're Ready!

You now have everything you need to build a fully-functional iOS companion app with complete control over the macOS app.

### Quick Checklist

- [ ] Copy 4 required files
- [ ] Configure capabilities (App Groups, iCloud, Bluetooth)
- [ ] Update Info.plist
- [ ] Create app entry point with UnifiedSyncManager
- [ ] Build device list view
- [ ] Add device control views
- [ ] Implement group management
- [ ] Add settings view
- [ ] Test all three sync methods
- [ ] Deploy!

**Happy Coding!** 🚀

---

**Need Help?** Check the main README or open an issue on GitHub.
