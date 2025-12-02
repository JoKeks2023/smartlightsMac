import SwiftUI
import Foundation

// ContentView only relies on shared models (GoveeDevice, DeviceGroup, SettingsStore, DeviceStore, GoveeController) defined elsewhere.
// UI only; uses shared GoveeDevice, DeviceGroup (from DeviceStore), SettingsStore, GoveeController
struct ContentView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var deviceStore: DeviceStore
    @EnvironmentObject private var controller: GoveeController

    @State private var showSettings = false
    @State private var isOn: Bool = true
    @State private var brightness: Double = 50
    @State private var showAddDevice = false
    @State private var newDeviceIP = ""
    @State private var newDeviceName = ""
    @State private var newDeviceModel = ""
    @State private var showAddGroup = false
    @State private var newGroupName = ""
    @State private var selectedMembers = Set<String>()
    @State private var color: Color = .white
    @State private var colorTemperature: Double = 4000
    @State private var showColorPicker = false

    var body: some View {
        NavigationSplitView {
            List(selection: $deviceStore.selectedDeviceID) {
                Section("Groups") { groupSection }
                Section("Devices") { devicesSection }
            }
            .listStyle(.sidebar)
            .toolbar {
                Button(action: { Task { await controller.refresh() } }) { Label("Refresh", systemImage: "arrow.clockwise") }
                Button(action: { showSettings = true }) { Label("Settings", systemImage: "gearshape") }
                Button(action: { showAddDevice = true }) { Label("Add Device", systemImage: "plus") }
                Button(action: { showAddGroup = true }) { Label("Add Group", systemImage: "folder.badge.plus") }
                if canShowColorControls { Button(action: { showColorPicker.toggle() }) { Label("Color", systemImage: "paintpalette") } }
            }
        } detail: { detailPane }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(settings) }
        .sheet(isPresented: $showAddDevice) { addDeviceSheet }
        .sheet(isPresented: $showAddGroup) { addGroupSheet }
        .sheet(isPresented: $showColorPicker) { colorPickerSheet }
        .task { await controller.refresh() }
    }

    // MARK: Sections
    private var groupSection: some View {
        ForEach(deviceStore.groups) { group in
            let isSelected = deviceStore.selectedGroupID == group.id
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading) {
                    Text(group.name).font(.headline)
                    Text("\(group.memberIDs.count) devices").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(6)
            .background(isSelected ? Color.purple.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture { deviceStore.selectedGroupID = group.id; deviceStore.selectedDeviceID = nil }
            .contextMenu {
                Button("Edit Group") { editGroup(group) }
                Divider()
                Button("Delete Group", role: .destructive) { deleteGroup(group.id) }
            }
        }
    }

    private var devicesSection: some View {
        ForEach(deviceStore.devices) { device in
            HStack {
                Circle().fill(device.online ? Color.green : Color.gray).frame(width: 8, height: 8)
                VStack(alignment: .leading) {
                    Text(device.name).font(.headline)
                    Text(device.model ?? "").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(transportBadge(device)).font(.caption2)
                    .padding(6)
                    .background(LinearGradient(colors: [Color.blue.opacity(0.15), Color.cyan.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(6)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .tag(device.id as String?)
            .contextMenu { addToGroupContext(for: device) }
        }
    }

    private func transportBadge(_ d: GoveeDevice) -> String {
        if d.transports.contains(.lan) { return "LAN" }
        if d.transports.contains(.homeKit) { return "Home" }
        if d.transports.contains(.cloud) { return "Cloud" }
        return "" }

    // MARK: Detail Pane
    private var detailPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            if isDeviceSelected { deviceControls } else if let gid = deviceStore.selectedGroupID { groupControls(groupID: gid) } else { emptySelection }
        }
        .padding(20)
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(detailTitle).font(.title).bold()
                if let subtitle = detailSubtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            if !detailBadge.isEmpty { Text(detailBadge).font(.caption).padding(8).background(LinearGradient(colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 10)) }
        }
    }

    private var deviceControls: some View {
        VStack(spacing: 12) {
            Toggle("Power", isOn: $isOn).onChange(of: isOn) { v in Task { await controller.setPower(on: v) } }
            HStack {
                Text("Brightness").frame(width: 90, alignment: .leading)
                Slider(value: $brightness, in: 0...100, step: 1).tint(.orange).onChange(of: brightness) { val in Task { await controller.setBrightness(Int(val)) } }
                Text("\(Int(brightness))%")
                    .frame(width: 50, alignment: .trailing)
            }
            if currentDevice?.supportsColorTemperature == true {
                HStack {
                    Text("Color Temp").frame(width: 90, alignment: .leading)
                    Slider(value: $colorTemperature, in: 2000...9000, step: 100).tint(.yellow).onChange(of: colorTemperature) { val in Task { await controller.setColorTemperature(Int(val)) } }
                    Text("\(Int(colorTemperature))K").frame(width: 80, alignment: .trailing)
                }
            }
            if currentDevice?.supportsColor == true {
                Button(action: { showColorPicker = true }) { Label("Pick Color", systemImage: "paintbrush.pointed") }
            }
            Spacer()
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func groupControls(groupID: String) -> some View {
        VStack(spacing: 12) {
            Toggle("Power (Group)", isOn: $isOn).onChange(of: isOn) { v in Task { await controller.setGroupPower(groupID: groupID, on: v) } }
            HStack {
                Text("Brightness (Group)").frame(width: 140, alignment: .leading)
                Slider(value: $brightness, in: 0...100, step: 1).tint(.orange).onChange(of: brightness) { val in Task { await controller.setGroupBrightness(groupID: groupID, value: Int(val)) } }
                Text("\(Int(brightness))%")
                    .frame(width: 50, alignment: .trailing)
            }
            if groupSupportsColor(groupID) { Button(action: { showColorPicker = true }) { Label("Pick Group Color", systemImage: "paintpalette") } }
            Spacer()
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var emptySelection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lightbulb.slash.fill").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("No selection").font(.headline).foregroundStyle(.secondary)
            Text("Select a device or group from the list.").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color.gray.opacity(0.06), Color.gray.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var colorPickerSheet: some View {
        VStack(spacing: 16) {
            Text("Color Picker").font(.title2).bold()
            ColorPicker("Color", selection: $color, supportsOpacity: false)
                .onChange(of: color) { newColor in
                    let rgb = rgbComponents(newColor)
                    Task {
                        if let gid = deviceStore.selectedGroupID { await controller.setGroupColor(groupID: gid, color: rgb) }
                        else { await controller.setColor(rgb) }
                    }
                }
            Button("Done") { showColorPicker = false }
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(minWidth: 360)
    }

    private func rgbComponents(_ c: Color) -> DeviceColor {
        #if canImport(AppKit)
        let ns = NSColor(c)
        return DeviceColor(r: Int(round(ns.redComponent * 255)), g: Int(round(ns.greenComponent * 255)), b: Int(round(ns.blueComponent * 255)))
        #else
        return DeviceColor(r: 255, g: 255, b: 255)
        #endif
    }

    // MARK: Helpers
    private var isDeviceSelected: Bool { deviceStore.selectedDeviceID != nil }
    private var currentDevice: GoveeDevice? { deviceStore.devices.first { $0.id == deviceStore.selectedDeviceID } }
    private var detailTitle: String { currentDevice?.name ?? (deviceStore.selectedGroupID.flatMap { gid in deviceStore.groups.first { $0.id == gid }?.name } ?? "No selection") }
    private var detailSubtitle: String? {
        if let dev = currentDevice { return dev.model }
        if let gid = deviceStore.selectedGroupID, let grp = deviceStore.groups.first(where: { $0.id == gid }) { return "\(grp.memberIDs.count) devices" }
        return nil
    }
    private var detailBadge: String {
        if let dev = currentDevice { return transportBadge(dev) }
        if deviceStore.selectedGroupID != nil { return "Group" }
        return "" }
    
    private func isValidIPAddress(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            // Reject leading zeros except for "0" itself
            if part.count > 1 && part.first == "0" { return false }
            guard let num = Int(part), num >= 0, num <= 255 else { return false }
            return true
        }
    }

    private func addDevice(_ deviceID: String, toGroup groupID: String) {
        guard let idx = deviceStore.groups.firstIndex(where: { $0.id == groupID }) else { return }
        if !deviceStore.groups[idx].memberIDs.contains(deviceID) { deviceStore.groups[idx].memberIDs.append(deviceID) }
    }
    private func groupSupportsColor(_ gid: String) -> Bool { groupMembers(gid).contains { $0.supportsColor } }
    private func groupMembers(_ gid: String) -> [GoveeDevice] { deviceStore.devices.filter { deviceStore.groups.first(where: { $0.id == gid })?.memberIDs.contains($0.id) == true } }
    private var canShowColorControls: Bool { (currentDevice?.supportsColor ?? false) || (deviceStore.selectedGroupID.map { groupSupportsColor($0) } ?? false) }

    // MARK: Sheets
    private var addDeviceSheet: some View {
        VStack(spacing: 14) {
            Text("Add LAN Device").font(.title2).bold()
            TextField("Device Name", text: $newDeviceName)
            TextField("Device IP (e.g. 192.168.1.50)", text: $newDeviceIP)
            TextField("Model (e.g. H6001)", text: $newDeviceModel)
            HStack {
                Button("Cancel") { showAddDevice = false }
                Spacer()
                Button("Add") {
                    let id = "lan-\(newDeviceIP)"
                    let dev = GoveeDevice(id: id, name: newDeviceName.isEmpty ? "Govee @ \(newDeviceIP)" : newDeviceName, model: newDeviceModel.isEmpty ? nil : newDeviceModel, ipAddress: newDeviceIP, online: true, supportsBrightness: true, supportsColor: true, supportsColorTemperature: false, transports: [.lan], isOn: nil, brightness: nil, color: nil, colorTemperature: nil)
                    deviceStore.upsert(dev)
                    deviceStore.selectedDeviceID = id
                    deviceStore.selectedGroupID = nil
                    showAddDevice = false
                    newDeviceIP = ""; newDeviceName = ""; newDeviceModel = ""
                }.disabled(newDeviceIP.isEmpty || !isValidIPAddress(newDeviceIP))
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }

    private var addGroupSheet: some View {
        VStack(spacing: 14) {
            Text("Create Group").font(.title2).bold()
            TextField("Group Name", text: $newGroupName)
            Text("Select devices to include").font(.caption).foregroundStyle(.secondary)
            List(deviceStore.devices, id: \.id) { dev in
                Toggle(isOn: Binding(get: { selectedMembers.contains(dev.id) }, set: { sel in if sel { selectedMembers.insert(dev.id) } else { selectedMembers.remove(dev.id) } })) { Text(dev.name) }
            }
            .frame(height: 240)
            HStack {
                Button("Cancel") { showAddGroup = false; selectedMembers.removeAll() }
                Spacer()
                Button("Create") {
                    deviceStore.addGroup(name: newGroupName.isEmpty ? "Group" : newGroupName, memberIDs: Array(selectedMembers))
                    deviceStore.selectedGroupID = deviceStore.groups.last?.id
                    deviceStore.selectedDeviceID = nil
                    showAddGroup = false
                    newGroupName = ""; selectedMembers.removeAll()
                }.disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty || selectedMembers.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 480)
    }

    private func editGroup(_ group: DeviceGroup) { newGroupName = group.name; selectedMembers = Set(group.memberIDs); showAddGroup = true }
    private func deleteGroup(_ id: String) { deviceStore.deleteGroup(id) }
    private func addToGroupContext(for device: GoveeDevice) -> some View { Menu("Add to group") { ForEach(deviceStore.groups) { group in Button(group.name) { addDevice(device.id, toGroup: group.id) } } } }
}

// MARK: - Device Discovery Sheet

struct DeviceDiscoverySheet: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var deviceStore: DeviceStore
    @EnvironmentObject private var controller: GoveeController
    @Environment(\.dismiss) private var dismiss
    @Binding var showManualAdd: Bool
    
    @State private var discoveredDevices: [GoveeDevice] = []
    @State private var selectedDevices = Set<String>()
    @State private var isDiscovering = false
    @State private var discoveryStatus = "Bereit zum Suchen"
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Geräte hinzufügen").font(.title).bold()
            Text("Suche nach Netzwerk- und HomeKit-Geräten").foregroundStyle(.secondary)
            
            Divider()
            
            HStack(spacing: 12) {
                Button(action: { Task { await discoverAllDevices() } }) {
                    HStack {
                        if isDiscovering {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(isDiscovering ? "Suche läuft..." : "Geräte suchen")
                    }
                }
                .disabled(isDiscovering)
                
                Spacer()
                
                Text(discoveryStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button(action: { 
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showManualAdd = true
                    }
                }) {
                    Label("Manuelle IP", systemImage: "network")
                }
            }
            
            ScrollView {
                if discoveredDevices.isEmpty && !isDiscovering {
                    VStack(spacing: 16) {
                        Image(systemName: "lightbulb.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Keine neuen Geräte gefunden")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Klicke auf 'Geräte suchen' um LAN-, HomeKit- und Cloud-Geräte zu finden.\nOder nutze 'Manuelle IP' für direkte Eingabe.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                } else {
                    VStack(spacing: 8) {
                        ForEach(discoveredDevices) { device in
                            DeviceDiscoveryRow(
                                device: device,
                                isSelected: selectedDevices.contains(device.id),
                                onToggle: { isSelected in
                                    if isSelected {
                                        selectedDevices.insert(device.id)
                                    } else {
                                        selectedDevices.remove(device.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(height: 300)
            
            Divider()
            
            HStack {
                if !discoveredDevices.isEmpty {
                    Button("Alle auswählen") {
                        selectedDevices = Set(discoveredDevices.map { $0.id })
                    }
                    .disabled(selectedDevices.count == discoveredDevices.count)
                    
                    Button("Keine") {
                        selectedDevices.removeAll()
                    }
                    .disabled(selectedDevices.isEmpty)
                }
                
                Spacer()
                
                Text("\(selectedDevices.count) ausgewählt")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                
                Button("Abbrechen") { dismiss() }
                
                Button("Hinzufügen (\(selectedDevices.count))") {
                    addSelectedDevices()
                    dismiss()
                }
                .disabled(selectedDevices.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 650, height: 520)
    }
    
    private func discoverAllDevices() async {
        isDiscovering = true
        discoveredDevices = []
        selectedDevices = []
        discoveryStatus = "Suche läuft..."
        
        var allDevices: [GoveeDevice] = []
        
        // Cloud discovery
        if !settings.goveeApiKey.isEmpty {
            discoveryStatus = "Suche Cloud-Geräte..."
            if let cloudDevices = await discoverCloud() {
                allDevices.append(contentsOf: cloudDevices)
            }
        }
        
        // HomeKit discovery
        if settings.homeKitEnabled {
            discoveryStatus = "Suche HomeKit-Geräte..."
            let homeKitDevices = await discoverHomeKit()
            allDevices.append(contentsOf: homeKitDevices)
        }
        
        // LAN discovery
        discoveryStatus = "Suche LAN-Geräte..."
        if let lanDevices = await discoverLAN() {
            allDevices.append(contentsOf: lanDevices)
        }
        
        // Filter out devices already in the store
        let existingIDs = Set(deviceStore.devices.map { $0.id })
        discoveredDevices = allDevices.filter { !existingIDs.contains($0.id) }
        
        isDiscovering = false
        discoveryStatus = discoveredDevices.isEmpty ? "Keine neuen Geräte" : "\(discoveredDevices.count) Geräte gefunden"
    }
    
    private func discoverCloud() async -> [GoveeDevice]? {
        do {
            let discovery = CloudDiscovery(apiKey: settings.goveeApiKey)
            return try await discovery.refreshDevices()
        } catch {
            print("Cloud discovery error: \(error)")
            return nil
        }
    }
    
    private func discoverLAN() async -> [GoveeDevice]? {
        do {
            let discovery = LANDiscovery()
            return try await discovery.refreshDevices()
        } catch {
            print("LAN discovery error: \(error)")
            return nil
        }
    }
    
    private func discoverHomeKit() async -> [GoveeDevice] {
        #if canImport(HomeKit)
        let manager = HomeKitManager()
        return await manager.discoverDevices()
        #else
        return []
        #endif
    }
    
    private func addSelectedDevices() {
        for deviceID in selectedDevices {
            if let device = discoveredDevices.first(where: { $0.id == deviceID }) {
                deviceStore.upsert(device)
            }
        }
        if let firstID = selectedDevices.first {
            deviceStore.selectedDeviceID = firstID
            deviceStore.selectedGroupID = nil
        }
    }
}

struct DeviceDiscoveryRow: View {
    let device: GoveeDevice
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    if let model = device.model {
                        Text(model)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    transportBadge
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(12)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var transportBadge: some View {
        let (text, colors): (String, [Color]) = {
            if device.transports.contains(.lan) { return ("LAN", [.green, .mint]) }
            if device.transports.contains(.homeKit) { return ("HomeKit", [.orange, .yellow]) }
            if device.transports.contains(.cloud) { return ("Cloud", [.blue, .cyan]) }
            if device.transports.contains(.homeAssistant) { return ("Home Assistant", [.purple, .pink]) }
            return ("Unbekannt", [.gray, .gray])
        }()
        
        return Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: colors.map { $0.opacity(0.2) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    var body: some View {
        Form {
            Section(header: Text("Govee Cloud")) { TextField("API Key", text: $settings.goveeApiKey).textFieldStyle(.roundedBorder) }
            Section(header: Text("Preferences")) {
                Toggle("Prefer LAN when available", isOn: $settings.prefersLan)
                Toggle("Enable HomeKit (Matter)", isOn: $settings.homeKitEnabled)
            }
            Section(header: Text("Home Assistant (optional)")) {
                TextField("Base URL (https://homeassistant.local:8123)", text: $settings.haBaseURL)
                SecureField("Long-Lived Token", text: $settings.haToken)
            }
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 340)
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var deviceStore: DeviceStore
    @EnvironmentObject private var controller: GoveeController
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var showLanInfo: Bool = false
    @State private var isDiscovering: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Willkommen bei Govee Mac").font(.largeTitle).bold()
            Text("Richte die App ein: Verwende die Govee Cloud API, HomeKit oder starte die LAN-Suche.")
                .foregroundStyle(.secondary)
            Form {
                Section(header: Text("Govee Cloud API")) {
                    TextField("API Key", text: $apiKey).textFieldStyle(.roundedBorder)
                    Button("Mit Cloud verbinden") { settings.goveeApiKey = apiKey; Task { await controller.refresh() } }.disabled(apiKey.isEmpty)
                }
                Section(header: Text("LAN Discovery")) {
                    Toggle("LAN bevorzugen", isOn: $settings.prefersLan)
                    HStack {
                        Button(isDiscovering ? "Suche läuft…" : "LAN-Suche starten") { isDiscovering = true; Task { await controller.refresh(); isDiscovering = false } }
                        Button("Mehr Info") { showLanInfo.toggle() }
                    }
                    if showLanInfo { Text("Die LAN-API ermöglicht direkte Steuerung im lokalen Netzwerk. Nicht alle Geräte werden unterstützt.").font(.footnote).foregroundStyle(.secondary) }
                }
                Section(header: Text("HomeKit / Matter")) {
                    Toggle("HomeKit aktivieren", isOn: $settings.homeKitEnabled)
                    Text("Aktiviere, um vorhandene Govee HomeKit Geräte zu laden.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(width: 540)
            HStack { Spacer(); Button("Weiter") { UserDefaults.standard.set(true, forKey: "hasCompletedWelcome"); dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(30)
        .onAppear { apiKey = settings.goveeApiKey }
    }
}

#Preview {
    let settings = SettingsStore()
    let store = DeviceStore()
    return WelcomeView()
        .environmentObject(settings)
        .environmentObject(store)
        .environmentObject(GoveeController(deviceStore: store, settings: settings))
}
@available(macOS 14.0, *
