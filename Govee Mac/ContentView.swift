import SwiftUI
import Foundation

// ContentView only relies on shared models (GoveeDevice, DeviceGroup, SettingsStore, DeviceStore, GoveeController) defined elsewhere.
// UI only; uses shared GoveeDevice, DeviceGroup (from DeviceStore), SettingsStore, GoveeController
struct ContentView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var deviceStore: DeviceStore
    @EnvironmentObject private var profileStore: DMXProfileStore
    @EnvironmentObject private var controller: GoveeController

    @State private var showSettings = false
    @State private var isOn: Bool = true
    @State private var brightness: Double = 50
    @State private var showDeviceDiscovery = false
    @State private var showManualAddDevice = false
    @State private var newDeviceIP = ""
    @State private var newDeviceName = ""
    @State private var newDeviceModel = ""
    @State private var showAddGroup = false
    @State private var newGroupName = ""
    @State private var selectedMembers = Set<String>()
    @State private var color: Color = .white
    @State private var colorTemperature: Double = 4000
    @State private var showColorPicker = false
    @State private var showDMXConfig = false
    @State private var dmxConfigDevice: GoveeDevice?
    @State private var isSyncingControlState = false
    @State private var colorCommandTask: Task<Void, Never>?

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
                Button(action: { showDeviceDiscovery = true }) { Label("Add Device", systemImage: "plus") }
                Button(action: { showAddGroup = true }) { Label("Add Group", systemImage: "folder.badge.plus") }
                if canShowColorControls { Button(action: { showColorPicker.toggle() }) { Label("Color", systemImage: "paintpalette") } }
            }
        } detail: { detailPane }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(controller)
                .environmentObject(deviceStore)
        }
        .sheet(isPresented: $showDeviceDiscovery) {
            DeviceDiscoverySheet(showManualAdd: $showManualAddDevice)
                .environmentObject(settings)
                .environmentObject(deviceStore)
                .environmentObject(controller)
        }
        .sheet(isPresented: $showManualAddDevice) { addDeviceSheet }
        .sheet(isPresented: $showAddGroup) { addGroupSheet }
        .sheet(isPresented: $showColorPicker) { colorPickerSheet }
        .sheet(isPresented: $showDMXConfig) {
            if let device = dmxConfigDevice {
                DMXConfigSheet(device: device)
                    .environmentObject(deviceStore)
                    .environmentObject(profileStore)
                    .environmentObject(settings)
            }
        }
        .background(TouchBarBridge(deviceStore: deviceStore, controller: controller, settings: settings))
        .onAppear(perform: syncControlStateFromSelection)
        .onChange(of: controlSyncSignature) { _ in
            syncControlStateFromSelection()
        }
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
        if d.transports.contains(.dmx) { return "DMX" }
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
            Toggle("Power", isOn: $isOn).onChange(of: isOn) { v in
                guard !isSyncingControlState else { return }
                Task { await controller.setPower(on: v) }
            }
            HStack {
                Text("Brightness").frame(width: 90, alignment: .leading)
                Slider(value: $brightness, in: 0...100, step: 1).tint(.orange).onChange(of: brightness) { val in
                    guard !isSyncingControlState else { return }
                    Task { await controller.setBrightness(Int(val)) }
                }
                Text("\(Int(brightness))%")
                    .frame(width: 50, alignment: .trailing)
            }
            if currentDevice?.supportsColorTemperature == true {
                HStack {
                    Text("Color Temp").frame(width: 90, alignment: .leading)
                    Slider(value: $colorTemperature, in: 2000...9000, step: 100).tint(.yellow).onChange(of: colorTemperature) { val in
                        guard !isSyncingControlState else { return }
                        Task { await controller.setColorTemperature(Int(val)) }
                    }
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
        CustomColorPickerSheet(
            initialColor: currentPickerDeviceColor,
            savedPresets: settings.savedColorPresets,
            onColorChange: { rgb in
                color = Color(
                    red: Double(rgb.r) / 255.0,
                    green: Double(rgb.g) / 255.0,
                    blue: Double(rgb.b) / 255.0
                )
                queueColorCommand(rgb)
            },
            onSavePreset: { rgb in
                settings.saveColorPreset(rgb)
            },
            onDone: { showColorPicker = false }
        )
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
    private var controlSyncSignature: String {
        let selected = deviceStore.selectedDeviceID ?? "none"
        guard let device = currentDevice else { return selected }
        let color = device.color.map { "\($0.r),\($0.g),\($0.b)" } ?? "none"
        return [
            selected,
            device.isOn.map(String.init) ?? "nil",
            device.brightness.map(String.init) ?? "nil",
            device.colorTemperature.map(String.init) ?? "nil",
            color
        ].joined(separator: "|")
    }

    private func syncControlStateFromSelection() {
        guard let device = currentDevice else { return }
        isSyncingControlState = true
        if let deviceIsOn = device.isOn {
            isOn = deviceIsOn
        }
        if let deviceBrightness = device.brightness {
            brightness = Double(deviceBrightness)
        }
        if let deviceTemperature = device.colorTemperature {
            colorTemperature = Double(deviceTemperature)
        }
        if let deviceColor = device.color {
            color = Color(
                red: Double(deviceColor.r) / 255.0,
                green: Double(deviceColor.g) / 255.0,
                blue: Double(deviceColor.b) / 255.0
            )
        }
        DispatchQueue.main.async {
            isSyncingControlState = false
        }
    }

    private var currentPickerDeviceColor: DeviceColor {
        if let groupID = deviceStore.selectedGroupID,
           let firstColorDevice = groupMembers(groupID).first(where: { $0.color != nil }),
           let groupColor = firstColorDevice.color {
            return groupColor
        }
        return currentDevice?.color ?? DeviceColor(r: 255, g: 140, b: 82)
    }

    private func queueColorCommand(_ rgb: DeviceColor) {
        colorCommandTask?.cancel()
        colorCommandTask = Task {
            try? await Task.sleep(nanoseconds: 45_000_000)
            guard !Task.isCancelled else { return }
            if let gid = deviceStore.selectedGroupID {
                await controller.setGroupColor(groupID: gid, color: rgb)
            } else {
                await controller.setColor(rgb)
            }
        }
    }
    
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
                Button("Cancel") { showManualAddDevice = false }
                Spacer()
                Button("Add") {
                    let id = "lan-\(newDeviceIP)"
                    let dev = GoveeDevice(id: id, name: newDeviceName.isEmpty ? "Govee @ \(newDeviceIP)" : newDeviceName, model: newDeviceModel.isEmpty ? nil : newDeviceModel, ipAddress: newDeviceIP, online: true, supportsBrightness: true, supportsColor: true, supportsColorTemperature: false, transports: [.lan], isOn: nil, brightness: nil, color: nil, colorTemperature: nil)
                    deviceStore.upsert(dev)
                    deviceStore.selectedDeviceID = id
                    deviceStore.selectedGroupID = nil
                    showManualAddDevice = false
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
    private func addToGroupContext(for device: GoveeDevice) -> some View {
        Group {
            Menu("Add to group") {
                ForEach(deviceStore.groups) { group in
                    Button(group.name) { addDevice(device.id, toGroup: group.id) }
                }
            }
            if settings.dmxEnabled {
                Divider()
                Button("Configure DMX") {
                    dmxConfigDevice = device
                    showDMXConfig = true
                }
            }
        }
    }
}

struct CustomColorPickerSheet: View {
    let initialColor: DeviceColor
    let savedPresets: [SavedColorPreset]
    let onColorChange: (DeviceColor) -> Void
    let onSavePreset: (DeviceColor) -> Void
    let onDone: () -> Void

    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double

    init(
        initialColor: DeviceColor,
        savedPresets: [SavedColorPreset],
        onColorChange: @escaping (DeviceColor) -> Void,
        onSavePreset: @escaping (DeviceColor) -> Void,
        onDone: @escaping () -> Void
    ) {
        self.initialColor = initialColor
        self.savedPresets = savedPresets
        self.onColorChange = onColorChange
        self.onSavePreset = onSavePreset
        self.onDone = onDone
        let hsv = HSVColor.from(rgb: initialColor)
        _hue = State(initialValue: hsv.hue)
        _saturation = State(initialValue: hsv.saturation)
        _brightness = State(initialValue: hsv.brightness)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Color Studio")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 14) {
                    SaturationBrightnessField(
                        hue: hue,
                        saturation: $saturation,
                        brightness: $brightness
                    )
                    .frame(width: 280, height: 220)

                    HueSpectrumSlider(hue: $hue)
                        .frame(width: 280, height: 26)
                }

                VStack(alignment: .leading, spacing: 14) {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(previewColor)
                        .frame(width: 120, height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )

                    Text(hexString)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Button {
                        onSavePreset(currentRGB)
                    } label: {
                        Label("Save Color", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    ColorSwatchRow { swatch in
                        let hsv = HSVColor.from(rgb: swatch)
                        hue = hsv.hue
                        saturation = hsv.saturation
                        brightness = hsv.brightness
                    }
                }
            }

            if !savedPresets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Saved Colors")
                        .font(.headline)
                    SavedColorPresetRow(presets: savedPresets) { preset in
                        let hsv = HSVColor.from(rgb: preset.color)
                        hue = hsv.hue
                        saturation = hsv.saturation
                        brightness = hsv.brightness
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Saturation \(Int(saturation * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Brightness \(Int(brightness * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 470)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.78), Color(red: 0.12, green: 0.13, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear(perform: emitColor)
        .onChange(of: hue) { _ in emitColor() }
        .onChange(of: saturation) { _ in emitColor() }
        .onChange(of: brightness) { _ in emitColor() }
    }

    private var previewColor: Color {
        let rgb = currentRGB
        return Color(red: Double(rgb.r) / 255.0, green: Double(rgb.g) / 255.0, blue: Double(rgb.b) / 255.0)
    }

    private var currentRGB: DeviceColor {
        HSVColor(hue: hue, saturation: saturation, brightness: brightness).rgb
    }

    private var hexString: String {
        let rgb = currentRGB
        return String(format: "#%02X%02X%02X", rgb.r, rgb.g, rgb.b)
    }

    private func emitColor() {
        onColorChange(currentRGB)
    }
}

struct SaturationBrightnessField: View {
    let hue: Double
    @Binding var saturation: Double
    @Binding var brightness: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(baseHueColor)
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.white, .white.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.black.opacity(0), .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .background(Circle().fill(Color.clear))
                    .frame(width: 22, height: 22)
                    .position(
                        x: saturation * proxy.size.width,
                        y: (1 - brightness) * proxy.size.height
                    )
                    .shadow(radius: 3)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        saturation = min(max(0, value.location.x / proxy.size.width), 1)
                        brightness = 1 - min(max(0, value.location.y / proxy.size.height), 1)
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var baseHueColor: Color {
        let rgb = HSVColor(hue: hue, saturation: 1, brightness: 1).rgb
        return Color(red: Double(rgb.r) / 255.0, green: Double(rgb.g) / 255.0, blue: Double(rgb.b) / 255.0)
    }
}

struct HueSpectrumSlider: View {
    @Binding var hue: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(
                        LinearGradient(
                            stops: stride(from: 0.0, through: 1.0, by: 0.125).map { location in
                                let rgb = HSVColor(hue: location, saturation: 1, brightness: 1).rgb
                                return .init(
                                    color: Color(red: Double(rgb.r) / 255.0, green: Double(rgb.g) / 255.0, blue: Double(rgb.b) / 255.0),
                                    location: location
                                )
                            },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(.black.opacity(0.2), lineWidth: 1))
                    .offset(x: max(0, min(proxy.size.width - 18, hue * proxy.size.width - 9)))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        hue = min(max(0, value.location.x / proxy.size.width), 1)
                    }
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ColorSwatchRow: View {
    let onSelect: (DeviceColor) -> Void

    private let swatches: [DeviceColor] = [
        DeviceColor(r: 255, g: 95, b: 86),
        DeviceColor(r: 255, g: 178, b: 43),
        DeviceColor(r: 255, g: 230, b: 109),
        DeviceColor(r: 57, g: 214, b: 155),
        DeviceColor(r: 72, g: 164, b: 255),
        DeviceColor(r: 165, g: 95, b: 255),
        DeviceColor(r: 255, g: 89, b: 183),
        DeviceColor(r: 255, g: 255, b: 255)
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 8), count: 4), spacing: 8) {
            ForEach(Array(swatches.enumerated()), id: \.offset) { _, swatch in
                Button {
                    onSelect(swatch)
                } label: {
                    Circle()
                        .fill(Color(
                            red: Double(swatch.r) / 255.0,
                            green: Double(swatch.g) / 255.0,
                            blue: Double(swatch.b) / 255.0
                        ))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SavedColorPresetRow: View {
    let presets: [SavedColorPreset]
    let onSelect: (SavedColorPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets) { preset in
                    Button {
                        onSelect(preset)
                    } label: {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                Color(
                                    red: Double(preset.color.r) / 255.0,
                                    green: Double(preset.color.g) / 255.0,
                                    blue: Double(preset.color.b) / 255.0
                                )
                            )
                            .frame(width: 46, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct HSVColor {
    var hue: Double
    var saturation: Double
    var brightness: Double

    var rgb: DeviceColor {
        let h = max(0, min(1, hue))
        let s = max(0, min(1, saturation))
        let v = max(0, min(1, brightness))

        let i = Int(h * 6)
        let f = h * 6 - Double(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)

        let (r, g, b): (Double, Double, Double)
        switch i % 6 {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default: (r, g, b) = (v, p, q)
        }

        return DeviceColor(
            r: Int((r * 255).rounded()),
            g: Int((g * 255).rounded()),
            b: Int((b * 255).rounded())
        )
    }

    static func from(rgb: DeviceColor) -> HSVColor {
        let r = Double(rgb.r) / 255.0
        let g = Double(rgb.g) / 255.0
        let b = Double(rgb.b) / 255.0

        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        let delta = maxValue - minValue

        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maxValue == r {
            hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6) / 6
        } else if maxValue == g {
            hue = (((b - r) / delta) + 2) / 6
        } else {
            hue = (((r - g) / delta) + 4) / 6
        }

        return HSVColor(
            hue: hue < 0 ? hue + 1 : hue,
            saturation: maxValue == 0 ? 0 : delta / maxValue,
            brightness: maxValue
        )
    }
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
    @EnvironmentObject private var controller: GoveeController
    @EnvironmentObject private var deviceStore: DeviceStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var isScanningLAN = false
    @State private var lanStatus = "Use discovery to find nearby LAN-enabled lights."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsHero
                metricsRow
                connectivityCard
                discoveryCard
                automationCard
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.07, green: 0.08, blue: 0.11), Color(red: 0.08, green: 0.12, blue: 0.18)]
                    : [Color(red: 0.96, green: 0.97, blue: 0.99), Color(red: 0.91, green: 0.95, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(minWidth: 720, minHeight: 640)
    }

    private var settingsHero: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.08, green: 0.35, blue: 0.40), Color(red: 0.07, green: 0.52, blue: 0.60)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Control Center")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Configure cloud access, LAN discovery, HomeKit support, and DMX input without digging through a plain form.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    SettingsPill(text: settings.goveeApiKey.isEmpty ? "Cloud Not Connected" : "Cloud Ready", tint: settings.goveeApiKey.isEmpty ? .gray : .blue)
                    SettingsPill(text: settings.prefersLan ? "LAN Preferred" : "LAN Optional", tint: .green)
                    SettingsPill(text: settings.homeKitEnabled ? "HomeKit On" : "HomeKit Off", tint: .orange)
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.12), lineWidth: 1)
        )
    }

    private var metricsRow: some View {
        HStack(spacing: 14) {
            SettingsMetricCard(title: "Devices", value: "\(deviceStore.devices.count)", accent: .blue)
            SettingsMetricCard(title: "Groups", value: "\(deviceStore.groups.count)", accent: .pink)
            SettingsMetricCard(title: "LAN Targets", value: "\(deviceStore.devices.filter { $0.transports.contains(.lan) || $0.transports.contains(.wled) || $0.transports.contains(.lifx) }.count)", accent: .green)
        }
    }

    private var connectivityCard: some View {
        SettingsCard(title: "Connectivity", subtitle: "Credentials and remote integrations") {
            VStack(alignment: .leading, spacing: 14) {
                SettingsField(label: "Govee Cloud API Key") {
                    TextField("Paste your developer API key", text: $settings.goveeApiKey)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsField(label: "Home Assistant URL") {
                    TextField("https://homeassistant.local:8123", text: $settings.haBaseURL)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsField(label: "Home Assistant Token") {
                    SecureField("Long-lived access token", text: $settings.haToken)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var discoveryCard: some View {
        SettingsCard(title: "Discovery", subtitle: "Local network and HomeKit behavior") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Prefer LAN control when available", isOn: $settings.prefersLan)
                    .toggleStyle(.switch)

                HStack(alignment: .center, spacing: 12) {
                    Button {
                        isScanningLAN = true
                        lanStatus = "Scanning local services..."
                        Task {
                            await controller.refreshLANOnly()
                            let count = deviceStore.devices.filter { $0.transports.contains(.lan) || $0.transports.contains(.wled) || $0.transports.contains(.lifx) }.count
                            lanStatus = count == 0 ? "No LAN devices found. Manual IP entry is still available." : "Found \(count) LAN device\(count == 1 ? "" : "s")."
                            isScanningLAN = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isScanningLAN {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "dot.radiowaves.left.and.right")
                            }
                            Text(isScanningLAN ? "Scanning LAN..." : "Run LAN Discovery")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isScanningLAN)

                    Toggle("Load HomeKit lights", isOn: $settings.homeKitEnabled)
                        .toggleStyle(.switch)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(lanStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("HomeKit includes regular HomeKit lights as well as Matter accessories. If discovery misses a LAN device, add it manually from the main window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var automationCard: some View {
        SettingsCard(title: "Automation", subtitle: "DMX receiver and protocol settings") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable DMX Receiver", isOn: $settings.dmxEnabled)
                    .toggleStyle(.switch)

                if settings.dmxEnabled {
                    Picker("Protocol", selection: $settings.dmxProtocol) {
                        Text("ArtNet").tag(DMXProtocolType.artnet)
                        Text("sACN (E1.31)").tag(DMXProtocolType.sacn)
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        SettingsPill(text: "Port \(settings.dmxProtocol == .artnet ? "6454" : "5568")", tint: .blue)
                        SettingsPill(text: "Map devices from the context menu", tint: .purple)
                    }

                    Text("Incoming DMX packets will drive any device with a DMX mapping. Use the device context menu in the sidebar to assign addresses and profiles.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SettingsField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

private struct SettingsMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent)
                .frame(width: 28, height: 6)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SettingsPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14))
            .foregroundStyle(tint)
            .clipShape(Capsule())
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
                        Button(isDiscovering ? "Suche läuft…" : "LAN-Suche starten") { isDiscovering = true; Task { await controller.refreshLANOnly(); isDiscovering = false } }
                        Button("Mehr Info") { showLanInfo.toggle() }
                    }
                    if showLanInfo { Text("Die LAN-API ermöglicht direkte Steuerung im lokalen Netzwerk. Nicht alle Geräte werden unterstützt.").font(.footnote).foregroundStyle(.secondary) }
                }
                Section(header: Text("HomeKit")) {
                    Toggle("HomeKit aktivieren", isOn: $settings.homeKitEnabled)
                    Text("Aktiviere, um vorhandene HomeKit-Lichter zu laden, auch ohne Matter.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(width: 540)
            HStack { Spacer(); Button("Weiter") { UserDefaults.standard.set(true, forKey: "hasCompletedWelcome"); dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(30)
        .onAppear { apiKey = settings.goveeApiKey }
    }
}

// MARK: - DMX Configuration Sheet

struct DMXConfigSheet: View {
    @EnvironmentObject private var deviceStore: DeviceStore
    @EnvironmentObject private var profileStore: DMXProfileStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    
    let device: GoveeDevice
    
    @State private var universe: Int
    @State private var startChannel: Int
    @State private var selectedProfileID: String
    @State private var showCustomProfileEditor = false
    @State private var showProfileManager = false
    
    init(device: GoveeDevice) {
        self.device = device
        _universe = State(initialValue: device.dmxMapping?.universe ?? 0)
        _startChannel = State(initialValue: device.dmxMapping?.startChannel ?? 1)
        _selectedProfileID = State(initialValue: device.dmxMapping?.profileID ?? "builtin_rgbDimmer")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Configure DMX for \(device.name)")
                .font(.title2)
                .bold()
            
            Form {
                Section(header: Text("DMX Address")) {
                    Stepper("Universe: \(universe)", value: $universe, in: 0...32767)
                    Stepper("Start Channel: \(startChannel)", value: $startChannel, in: 1...512)
                }
                
                Section(header: Text("DMX Profile")) {
                    Picker("Profile", selection: $selectedProfileID) {
                        ForEach(profileStore.allProfiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Button("Create Custom Profile") {
                            showCustomProfileEditor = true
                        }
                        
                        Button("Manage Profiles") {
                            showProfileManager = true
                        }
                    }
                }
                
                if let profile = profileStore.getProfile(id: selectedProfileID) {
                    Section(header: Text("Channel Layout")) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(profile.channels) { channel in
                                HStack {
                                    Text("Ch \(startChannel + channel.channelNumber):")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .frame(width: 60, alignment: .leading)
                                    Text(channel.function.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Total Channels:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("\(profile.channelCount)")
                                    .font(.caption)
                                Spacer()
                                Text("Range:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("\(startChannel) - \(endChannel(profile: profile))")
                                    .font(.caption)
                            }
                            
                            if endChannel(profile: profile) > 512 {
                                Text("⚠️ Warning: End channel exceeds DMX universe limit (512)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section(header: Text("Protocol")) {
                    HStack {
                        Text("Current protocol:")
                            .font(.caption)
                        Text(settings.dmxProtocol.rawValue)
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    Text("Change protocol in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 450)
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Remove DMX") {
                    removeDMXMapping()
                    dismiss()
                }
                .foregroundColor(.red)
                .disabled(device.dmxMapping == nil)
                
                Button("Save") {
                    saveDMXMapping()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 550)
        .sheet(isPresented: $showCustomProfileEditor) {
            CustomProfileEditor()
                .environmentObject(profileStore)
        }
        .sheet(isPresented: $showProfileManager) {
            ProfileManagerView()
                .environmentObject(profileStore)
        }
    }
    
    private func endChannel(profile: DMXProfile) -> Int {
        startChannel + profile.channelCount - 1
    }
    
    private func saveDMXMapping() {
        let mapping = DMXChannelMapping(
            universe: universe,
            startChannel: startChannel,
            profileID: selectedProfileID
        )
        
        if let index = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
            var updatedDevice = deviceStore.devices[index]
            updatedDevice.dmxMapping = mapping
            updatedDevice.transports.insert(.dmx)
            deviceStore.devices[index] = updatedDevice
        }
    }
    
    private func removeDMXMapping() {
        if let index = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
            var updatedDevice = deviceStore.devices[index]
            updatedDevice.dmxMapping = nil
            updatedDevice.transports.remove(.dmx)
            deviceStore.devices[index] = updatedDevice
        }
    }
}

// MARK: - Custom Profile Editor

struct CustomProfileEditor: View {
    @EnvironmentObject private var profileStore: DMXProfileStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var profileName: String = ""
    @State private var channels: [DMXCustomChannel] = [
        DMXCustomChannel(channelNumber: 0, function: .dimmer)
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Custom DMX Profile")
                .font(.title2)
                .bold()
            
            Form {
                Section(header: Text("Profile Name")) {
                    TextField("Profile Name", text: $profileName)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section(header: HStack {
                    Text("Channel Mapping")
                    Spacer()
                    Button(action: addChannel) {
                        Label("Add Channel", systemImage: "plus.circle")
                    }
                }) {
                    if channels.isEmpty {
                        Text("No channels defined")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(channels.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                Text("Ch \(index + 1):")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .frame(width: 50, alignment: .leading)
                                
                                Picker("Function", selection: $channels[index].function) {
                                    ForEach(DMXChannelFunction.allCases, id: \.self) { function in
                                        Text(function.rawValue).tag(function)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                                
                                Spacer()
                                
                                Button(action: { deleteChannel(at: index) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .frame(height: 400)
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create Profile") {
                    createProfile()
                    dismiss()
                }
                .disabled(profileName.trimmingCharacters(in: .whitespaces).isEmpty || channels.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
    
    private func addChannel() {
        let nextChannel = channels.count
        channels.append(DMXCustomChannel(channelNumber: nextChannel, function: .unused))
    }
    
    private func deleteChannel(at index: Int) {
        channels.remove(at: index)
        // Renumber channels
        for i in 0..<channels.count {
            channels[i].channelNumber = i
        }
    }
    
    private func createProfile() {
        let profile = DMXProfile(
            name: profileName,
            channels: channels,
            isBuiltIn: false
        )
        profileStore.addProfile(profile)
    }
}

// MARK: - Profile Manager

struct ProfileManagerView: View {
    @EnvironmentObject private var profileStore: DMXProfileStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Manage DMX Profiles")
                .font(.title2)
                .bold()
            
            List {
                Section(header: Text("Built-in Profiles")) {
                    ForEach(DMXProfile.builtInProfiles) { profile in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .font(.headline)
                                Text("\(profile.channelCount) channels")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Custom Profiles")) {
                    if profileStore.customProfiles.isEmpty {
                        Text("No custom profiles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(profileStore.customProfiles) { profile in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(profile.name)
                                        .font(.headline)
                                    Text("\(profile.channelCount) channels")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    // Show channel functions
                                    Text(profile.channels.map { $0.function.rawValue }.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button(action: { profileStore.deleteProfile(id: profile.id) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .frame(height: 400)
            
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 500)
    }
}

#Preview {
    let settings = SettingsStore()
    let store = DeviceStore()
    let profiles = DMXProfileStore()
    return WelcomeView()
        .environmentObject(settings)
        .environmentObject(store)
        .environmentObject(profiles)
        .environmentObject(GoveeController(deviceStore: store, settings: settings, profileStore: profiles))
}
