import SwiftUI
import Foundation
import Combine
import Security
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Models

enum TransportKind: String, Codable, Hashable {
    case cloud, lan, homeKit, homeAssistant
}

struct DeviceColor: Codable, Hashable {
    var r: Int
    var g: Int
    var b: Int
}

struct GoveeDevice: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var model: String?
    var ipAddress: String?
    var online: Bool
    var supportsBrightness: Bool
    var supportsColor: Bool
    var supportsColorTemperature: Bool
    var transports: Set<TransportKind>
    var primaryTransport: TransportKind { transports.first ?? .cloud }
    var isOn: Bool?
    var brightness: Int?
    var color: DeviceColor?
    var colorTemperature: Int?
}

struct DeviceGroup: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var memberIDs: [String]
    
    init(id: String = UUID().uuidString, name: String, memberIDs: [String]) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
    }
}

// MARK: - Stores

final class SettingsStore: ObservableObject {
    @Published var goveeApiKey: String {
        didSet { try? APIKeyKeychain.save(key: goveeApiKey) }
    }
    @Published var prefersLan: Bool {
        didSet { UserDefaults.standard.set(prefersLan, forKey: "prefersLan") }
    }
    @Published var homeKitEnabled: Bool {
        didSet { UserDefaults.standard.set(homeKitEnabled, forKey: "homeKitEnabled") }
    }
    @Published var haBaseURL: String {
        didSet { UserDefaults.standard.set(haBaseURL, forKey: "haBaseURL") }
    }
    @Published var haToken: String {
        didSet { UserDefaults.standard.set(haToken, forKey: "haToken") }
    }
    
    init() {
        // Migrate from UserDefaults to Keychain
        if let oldKey = UserDefaults.standard.string(forKey: "goveeApiKey"), !oldKey.isEmpty {
            try? APIKeyKeychain.save(key: oldKey)
            UserDefaults.standard.removeObject(forKey: "goveeApiKey")
        }
        
        self.goveeApiKey = (try? APIKeyKeychain.load()) ?? ""
        self.prefersLan = UserDefaults.standard.object(forKey: "prefersLan") as? Bool ?? true
        self.homeKitEnabled = UserDefaults.standard.object(forKey: "homeKitEnabled") as? Bool ?? false
        self.haBaseURL = UserDefaults.standard.string(forKey: "haBaseURL") ?? ""
        self.haToken = UserDefaults.standard.string(forKey: "haToken") ?? ""
    }
}

@MainActor
final class DeviceStore: ObservableObject {
    @Published var devices: [GoveeDevice] = []
    @Published var selectedDeviceID: String?
    @Published var selectedGroupID: String?
    @Published var groups: [DeviceGroup] = [] {
        didSet { saveGroups() }
    }
    
    init() { loadGroups() }
    
    func upsert(_ device: GoveeDevice) {
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device
        } else {
            devices.append(device)
        }
    }
    
    func replaceAll(_ newDevices: [GoveeDevice]) {
        devices = newDevices
        saveDevicesToSharedContainer()
    }
    
    private func saveDevicesToSharedContainer() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.govee.mac"),
           let encoded = try? JSONEncoder().encode(devices) {
            sharedDefaults.set(encoded, forKey: "cachedDevices")
        }
    }
    
    func addGroup(name: String, memberIDs: [String]) {
        groups.append(DeviceGroup(name: name, memberIDs: memberIDs))
    }
    
    func deleteGroup(_ id: String) {
        groups.removeAll { $0.id == id }
        if selectedGroupID == id { selectedGroupID = nil }
    }
    
    private func saveGroups() {
        if let encoded = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(encoded, forKey: "deviceGroups")
        }
    }
    
    private func loadGroups() {
        if let data = UserDefaults.standard.data(forKey: "deviceGroups"),
           let decoded = try? JSONDecoder().decode([DeviceGroup].self, from: data) {
            groups = decoded
        }
    }
}

// MARK: - Protocols

protocol DeviceDiscoveryProtocol {
    func refreshDevices() async throws -> [GoveeDevice]
}

protocol DeviceControlProtocol {
    func setPower(device: GoveeDevice, on: Bool) async throws
    func setBrightness(device: GoveeDevice, value: Int) async throws
    func setColor(device: GoveeDevice, color: DeviceColor) async throws
    func setColorTemperature(device: GoveeDevice, value: Int) async throws
}

// MARK: - Cloud Implementation

struct CloudDiscovery: DeviceDiscoveryProtocol {
    let apiKey: String
    
    func refreshDevices() async throws -> [GoveeDevice] {
        guard !apiKey.isEmpty else { return [] }
        
        var request = URLRequest(url: URL(string: "https://developer-api.govee.com/v1/devices")!)
        request.addValue(apiKey, forHTTPHeaderField: "Govee-API-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
        
        struct CloudResponse: Codable {
            struct CloudDevice: Codable {
                let device: String
                let model: String
                let deviceName: String
                let controllable: Bool
                let retrievable: Bool
                let supportCmds: [String]
            }
            let data: CloudData
            struct CloudData: Codable {
                let devices: [CloudDevice]
            }
        }
        
        let decoded = try JSONDecoder().decode(CloudResponse.self, from: data)
        return decoded.data.devices.map { cd in
            GoveeDevice(
                id: cd.device,
                name: cd.deviceName,
                model: cd.model,
                ipAddress: nil,
                online: cd.controllable,
                supportsBrightness: cd.supportCmds.contains("brightness"),
                supportsColor: cd.supportCmds.contains("color"),
                supportsColorTemperature: cd.supportCmds.contains("colorTem"),
                transports: [.cloud],
                isOn: nil,
                brightness: nil,
                color: nil,
                colorTemperature: nil
            )
        }
    }
}

struct CloudControl: DeviceControlProtocol {
    let apiKey: String
    
    private func sendCommand(device: GoveeDevice, cmd: [String: Any]) async throws {
        guard !apiKey.isEmpty, let model = device.model else { return }
        
        var request = URLRequest(url: URL(string: "https://developer-api.govee.com/v1/devices/control")!)
        request.httpMethod = "PUT"
        request.addValue(apiKey, forHTTPHeaderField: "Govee-API-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "device": device.id,
            "model": model,
            "cmd": cmd
        ])
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        try await sendCommand(device: device, cmd: ["name": "turn", "value": on ? "on" : "off"])
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        try await sendCommand(device: device, cmd: ["name": "brightness", "value": min(max(value, 0), 100)])
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        try await sendCommand(device: device, cmd: ["name": "color", "value": ["r": color.r, "g": color.g, "b": color.b]])
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        try await sendCommand(device: device, cmd: ["name": "colorTem", "value": min(max(value, 2000), 9000)])
    }
}

// MARK: - LAN Implementation

actor LANServiceStore {
    var services: [NetService] = []
    var resolvedDevices: [GoveeDevice] = []
    
    func reset() {
        services = []
        resolvedDevices = []
    }
    
    func addService(_ service: NetService) {
        services.append(service)
    }
    
    func addDevice(_ device: GoveeDevice) {
        resolvedDevices.append(device)
    }
}

@MainActor
class LANDiscovery: NSObject, DeviceDiscoveryProtocol, NetServiceBrowserDelegate, NetServiceDelegate {
    private var browser: NetServiceBrowser?
    private let serviceStore = LANServiceStore()
    private var continuation: CheckedContinuation<[GoveeDevice], Error>?
    
    override init() {
        super.init()
    }
    
    deinit {
        cleanup()
    }
    
    private func cleanup() {
        browser?.stop()
        browser?.delegate = nil
        browser = nil
    }

    func refreshDevices() async throws -> [GoveeDevice] {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            Task { await self.serviceStore.reset() }
            
            browser = NetServiceBrowser()
            browser?.delegate = self
            browser?.searchForServices(ofType: "_govee._tcp.", inDomain: "local.")
            
            Task {
                try? await Task.sleep(for: .seconds(5))
                self.browser?.stop()
                self.browser?.delegate = nil
                if let cont = self.continuation {
                    let devices = await self.serviceStore.resolvedDevices
                    cont.resume(returning: devices)
                    self.continuation = nil
                }
            }
        }
    }
    
    // Handle delegate callbacks on the main actor to avoid Sendable violations
    @MainActor
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        // Do not pass NetService into actor; resolve immediately on main actor
        service.delegate = self
        service.resolve(withTimeout: 3.0)
    }
    
    @MainActor
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses, !addresses.isEmpty,
              let ipAddress = self.extractIPAddress(from: addresses[0]) else { return }
        
        let device = GoveeDevice(
            id: "lan-\(sender.name)-\(ipAddress)",
            name: sender.name,
            model: nil,
            ipAddress: ipAddress,
            online: true,
            supportsBrightness: true,
            supportsColor: true,
            supportsColorTemperature: false,
            transports: [.lan],
            isOn: nil,
            brightness: nil,
            color: nil,
            colorTemperature: nil
        )
        Task { await serviceStore.addDevice(device) }
    }
    
    private func extractIPAddress(from data: Data) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            guard let sockaddr = pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return }
            getnameinfo(sockaddr, socklen_t(data.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
        }
        return String(cString: hostname)
    }
    
    @MainActor
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        // Ignore resolution failures
    }
}

struct LANControl: DeviceControlProtocol {
    let deviceIP: String
    
    private func sendLANCommand(cmd: [String: Any]) async throws {
        var request = URLRequest(url: URL(string: "http://\(deviceIP)/device/control")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["msg": ["cmd": cmd]])
        request.timeoutInterval = 3
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        try await sendLANCommand(cmd: ["name": "turn", "value": on ? "on" : "off"])
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        try await sendLANCommand(cmd: ["name": "brightness", "value": min(max(value, 0), 100)])
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        try await sendLANCommand(cmd: ["name": "color", "value": ["r": color.r, "g": color.g, "b": color.b]])
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        try await sendLANCommand(cmd: ["name": "colorTem", "value": min(max(value, 2000), 9000)])
    }
}

// MARK: - HomeKit Implementation

#if canImport(HomeKit)
@available(macOS 10.15, *)
@MainActor
class HomeKitManager: NSObject, ObservableObject, HMHomeManagerDelegate {
    let homeManager = HMHomeManager()
    @Published var accessories: [HMAccessory] = []
    
    override init() {
        super.init()
        homeManager.delegate = self
    }
    
    func discoverDevices() async -> [GoveeDevice] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard let home = homeManager.primaryHome else { return [] }
        let goveeAccessories = home.accessories.filter { acc in
            acc.name.lowercased().contains("govee") ||
            acc.manufacturer?.lowercased().contains("govee") == true ||
            acc.manufacturer?.lowercased().contains("ihoment") == true
        }
        
        return goveeAccessories.compactMap { accessory in
            guard let lightService = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb }) else { return nil }
            
            let supportsBrightness = lightService.characteristics.contains { $0.characteristicType == HMCharacteristicTypeBrightness }
            let supportsColor = lightService.characteristics.contains { $0.characteristicType == HMCharacteristicTypeHue }
            let supportsCT = lightService.characteristics.contains { $0.characteristicType == HMCharacteristicTypeColorTemperature }
            
            return GoveeDevice(
                id: "homekit-\(accessory.uniqueIdentifier.uuidString)",
                name: accessory.name,
                model: accessory.model,
                ipAddress: nil,
                online: accessory.isReachable,
                supportsBrightness: supportsBrightness,
                supportsColor: supportsColor,
                supportsColorTemperature: supportsCT,
                transports: [.homeKit],
                isOn: nil,
                brightness: nil,
                color: nil,
                colorTemperature: nil
            )
        }
    }
    
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            if let home = manager.primaryHome {
                accessories = home.accessories
            }
        }
    }
}

struct HomeKitControl: DeviceControlProtocol {
    let homeManager: HMHomeManager
    
    private func getAccessory(for device: GoveeDevice) -> HMAccessory? {
        let idString = device.id.replacingOccurrences(of: "homekit-", with: "")
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return homeManager.primaryHome?.accessories.first { $0.uniqueIdentifier == uuid }
    }
    
    private func getLightService(_ accessory: HMAccessory) -> HMService? {
        accessory.services.first { $0.serviceType == HMServiceTypeLightbulb }
    }
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        guard let accessory = getAccessory(for: device),
              let service = getLightService(accessory),
              let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) else { return }
        try await characteristic.writeValue(on)
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        guard let accessory = getAccessory(for: device),
              let service = getLightService(accessory),
              let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeBrightness }) else { return }
        try await characteristic.writeValue(value)
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        guard let accessory = getAccessory(for: device),
              let service = getLightService(accessory) else { return }
        
        let r = Double(color.r) / 255.0
        let g = Double(color.g) / 255.0
        let b = Double(color.b) / 255.0
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        var hue: Double = 0
        if delta != 0 {
            if maxC == r {
                hue = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxC == g {
                hue = 60 * (((b - r) / delta) + 2)
            } else {
                hue = 60 * (((r - g) / delta) + 4)
            }
        }
        if hue < 0 { hue += 360 }
        let saturation = maxC == 0 ? 0 : (delta / maxC) * 100
        
        if let hueChar = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeHue }) {
            try await hueChar.writeValue(hue)
        }
        if let satChar = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeSaturation }) {
            try await satChar.writeValue(saturation)
        }
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        guard let accessory = getAccessory(for: device),
              let service = getLightService(accessory),
              let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeColorTemperature }) else { return }
        let mireds = Int(1_000_000 / Double(value))
        try await characteristic.writeValue(mireds)
    }
}
#endif

// MARK: - Home Assistant Implementation

struct HomeAssistantDiscovery: DeviceDiscoveryProtocol {
    let baseURL: URL
    let token: String
    
    func refreshDevices() async throws -> [GoveeDevice] {
        guard !token.isEmpty else { return [] }
        
        var req = URLRequest(url: baseURL.appendingPathComponent("api/states"))
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        
        var devices: [GoveeDevice] = []
        for obj in json {
            guard let entityId = obj["entity_id"] as? String, entityId.hasPrefix("light.") else { continue }
            if let attr = obj["attributes"] as? [String: Any] {
                let friendly = (attr["friendly_name"] as? String) ?? entityId
                if friendly.lowercased().contains("govee") {
                    let supportsBrightness = (attr["supported_features"] as? Int ?? 0) & 1 == 1
                    let modes = (attr["supported_color_modes"] as? [String])?.map { $0.lowercased() } ?? []
                    let supportsColor = modes.contains { ["rgb","hs","xy"].contains($0) }
                    let supportsCT = modes.contains("color_temp")
                    
                    let state = obj["state"] as? String
                    let isOn = state == "on"
                    let brightness = attr["brightness"] as? Int
                    let brightnessPercent = brightness.map { Int(Double($0) / 255.0 * 100.0) }
                    
                    devices.append(GoveeDevice(
                        id: entityId,
                        name: friendly,
                        model: nil,
                        ipAddress: nil,
                        online: true,
                        supportsBrightness: supportsBrightness,
                        supportsColor: supportsColor,
                        supportsColorTemperature: supportsCT,
                        transports: [.homeAssistant],
                        isOn: isOn,
                        brightness: brightnessPercent,
                        color: nil,
                        colorTemperature: nil
                    ))
                }
            }
        }
        return devices
    }
}

struct HomeAssistantControl: DeviceControlProtocol {
    let baseURL: URL
    let token: String
    
    private func callService(domain: String, service: String, data: [String: Any]) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/services/\(domain)/\(service)"))
        req.httpMethod = "POST"
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: data)
        
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        try await callService(domain: "light", service: on ? "turn_on" : "turn_off", data: ["entity_id": device.id])
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        try await callService(domain: "light", service: "turn_on", data: ["entity_id": device.id, "brightness_pct": min(max(value, 0), 100)])
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        try await callService(domain: "light", service: "turn_on", data: ["entity_id": device.id, "rgb_color": [color.r, color.g, color.b]])
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        let mired = Int(1_000_000 / Double(min(max(value, 2000), 9000)))
        try await callService(domain: "light", service: "turn_on", data: ["entity_id": device.id, "color_temp": mired])
    }
}

// MARK: - Controller

@MainActor
class GoveeController: ObservableObject {
    private let deviceStore: DeviceStore
    private let settings: SettingsStore
    private var pollingTask: Task<Void, Never>?
    
    #if canImport(HomeKit)
    @available(macOS 10.15, *)
    private var homeKitManager: HomeKitManager?
    #endif
    
    init(deviceStore: DeviceStore, settings: SettingsStore) {
        self.deviceStore = deviceStore
        self.settings = settings
        
        #if canImport(HomeKit)
        if #available(macOS 10.15, *), settings.homeKitEnabled {
            self.homeKitManager = HomeKitManager()
        }
        #endif
        
        startPolling()
    }
    
    deinit {
        pollingTask?.cancel()
    }
    
    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await refresh()
            }
        }
    }
    
    func refresh() async {
        var merged: [String: GoveeDevice] = [:]
        
        // Cloud
        if !settings.goveeApiKey.isEmpty {
            let cloudDiscovery = CloudDiscovery(apiKey: settings.goveeApiKey)
            if let devices = try? await cloudDiscovery.refreshDevices() {
                for dev in devices { merged[dev.id] = dev }
            }
        }
        
        // LAN
        if settings.prefersLan {
            let lanDiscovery = LANDiscovery()
            if let devices = try? await lanDiscovery.refreshDevices() {
                for dev in devices {
                    if var existing = merged[dev.id] {
                        existing.transports.insert(.lan)
                        existing.ipAddress = dev.ipAddress
                        merged[dev.id] = existing
                    } else {
                        merged[dev.id] = dev
                    }
                }
            }
        }
        
        // HomeKit
        #if canImport(HomeKit)
        if #available(macOS 10.15, *), settings.homeKitEnabled, let hkManager = homeKitManager {
            let devices = await hkManager.discoverDevices()
            for dev in devices {
                if var existing = merged[dev.id] {
                    existing.transports.insert(.homeKit)
                    merged[dev.id] = existing
                } else {
                    merged[dev.id] = dev
                }
            }
        }
        #endif
        
        // Home Assistant
        if let url = URL(string: settings.haBaseURL), !settings.haToken.isEmpty {
            let haDiscovery = HomeAssistantDiscovery(baseURL: url, token: settings.haToken)
            if let devices = try? await haDiscovery.refreshDevices() {
                for dev in devices {
                    if var existing = merged[dev.id] {
                        existing.transports.insert(.homeAssistant)
                        existing.isOn = dev.isOn ?? existing.isOn
                        existing.brightness = dev.brightness ?? existing.brightness
                        merged[dev.id] = existing
                    } else {
                        merged[dev.id] = dev
                    }
                }
            }
        }
        
        let devices = Array(merged.values).sorted { $0.name < $1.name }
        deviceStore.replaceAll(devices)
        
        if deviceStore.selectedDeviceID == nil {
            deviceStore.selectedDeviceID = devices.first?.id
        }
    }
    
    private func getControl(for device: GoveeDevice) -> DeviceControlProtocol? {
        if settings.prefersLan, device.transports.contains(.lan), let ip = device.ipAddress {
            return LANControl(deviceIP: ip)
        }
        
        #if canImport(HomeKit)
        if #available(macOS 10.15, *), device.transports.contains(.homeKit), let hkManager = homeKitManager {
            return HomeKitControl(homeManager: hkManager.homeManager)
        }
        #endif
        
        if device.transports.contains(.homeAssistant), let url = URL(string: settings.haBaseURL), !settings.haToken.isEmpty {
            return HomeAssistantControl(baseURL: url, token: settings.haToken)
        }
        
        if device.transports.contains(.cloud), !settings.goveeApiKey.isEmpty {
            return CloudControl(apiKey: settings.goveeApiKey)
        }
        
        return nil
    }
    
    private var selectedDevice: GoveeDevice? {
        deviceStore.devices.first { $0.id == deviceStore.selectedDeviceID }
    }
    
    func setPower(on: Bool) async {
        guard let device = selectedDevice, let control = getControl(for: device) else { return }
        do {
            try await control.setPower(device: device, on: on)
            if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
                deviceStore.devices[idx].isOn = on
            }
        } catch {
            print("Power error: \(error)")
        }
    }
    
    func setBrightness(_ value: Int) async {
        guard let device = selectedDevice, let control = getControl(for: device) else { return }
        do {
            try await control.setBrightness(device: device, value: value)
            if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
                deviceStore.devices[idx].brightness = value
            }
        } catch {
            print("Brightness error: \(error)")
        }
    }
    
    func setColor(_ color: DeviceColor) async {
        guard let device = selectedDevice, let control = getControl(for: device) else { return }
        do {
            try await control.setColor(device: device, color: color)
            if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
                deviceStore.devices[idx].color = color
            }
        } catch {
            print("Color error: \(error)")
        }
    }
    
    func setColorTemperature(_ value: Int) async {
        guard let device = selectedDevice, let control = getControl(for: device) else { return }
        do {
            try await control.setColorTemperature(device: device, value: value)
            if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
                deviceStore.devices[idx].colorTemperature = value
            }
        } catch {
            print("CT error: \(error)")
        }
    }
    
    func setGroupPower(groupID: String, on: Bool) async {
        let members = deviceStore.devices.filter { deviceStore.groups.first(where: { $0.id == groupID })?.memberIDs.contains($0.id) == true }
        for device in members {
            if let control = getControl(for: device) {
                try? await control.setPower(device: device, on: on)
            }
        }
    }
    
    func setGroupBrightness(groupID: String, value: Int) async {
        let members = deviceStore.devices.filter { deviceStore.groups.first(where: { $0.id == groupID })?.memberIDs.contains($0.id) == true }
        for device in members {
            if let control = getControl(for: device) {
                try? await control.setBrightness(device: device, value: value)
            }
        }
    }
    
    func setGroupColor(groupID: String, color: DeviceColor) async {
        let members = deviceStore.devices.filter { deviceStore.groups.first(where: { $0.id == groupID })?.memberIDs.contains($0.id) == true }
        for device in members where device.supportsColor {
            if let control = getControl(for: device) {
                try? await control.setColor(device: device, color: color)
            }
        }
    }
}
