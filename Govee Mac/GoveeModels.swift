import SwiftUI
import Foundation
import Combine
import Security
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Keychain Helper

enum APIKeyKeychain {
    private static let service = "com.govee.mac.api"
    private static let account = "goveeApiKey"

    static func save(key: String) throws {
        let data = Data(key.utf8)
        // Delete existing item if any
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Keychain save failed: \(status)"])
        }
    }

    static func load() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Keychain load failed: \(status)"])
        }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Models

enum TransportKind: String, Codable, Hashable {
    case cloud, lan, homeKit, homeAssistant, dmx
}

enum DMXProtocolType: String, Codable, Hashable {
    case artnet = "ArtNet"
    case sacn = "sACN"
}

struct DeviceColor: Codable, Hashable {
    var r: Int
    var g: Int
    var b: Int
}

struct DMXChannelMapping: Codable, Hashable {
    var universe: Int
    var startChannel: Int // 1-512
    var channelMode: DMXChannelMode
    
    enum DMXChannelMode: String, Codable {
        case single      // Single channel dimmer (1 channel)
        case rgb         // RGB (3 channels: R, G, B)
        case rgbw        // RGBW (4 channels: R, G, B, W)
        case rgba        // RGBA (4 channels: R, G, B, Amber)
        case rgbDimmer   // RGB + Dimmer (4 channels: Dimmer, R, G, B)
        case extended    // Extended mode (Dimmer, R, G, B, W, Amber, etc.)
    }
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
    var dmxMapping: DMXChannelMapping?
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
    @Published var dmxEnabled: Bool {
        didSet { UserDefaults.standard.set(dmxEnabled, forKey: "dmxEnabled") }
    }
    @Published var dmxProtocol: DMXProtocolType {
        didSet { UserDefaults.standard.set(dmxProtocol.rawValue, forKey: "dmxProtocol") }
    }
    @Published var dmxBroadcastAddress: String {
        didSet { UserDefaults.standard.set(dmxBroadcastAddress, forKey: "dmxBroadcastAddress") }
    }
    @Published var dmxOutputRate: Int {
        didSet { UserDefaults.standard.set(dmxOutputRate, forKey: "dmxOutputRate") }
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
        self.dmxEnabled = UserDefaults.standard.object(forKey: "dmxEnabled") as? Bool ?? false
        let protocolString = UserDefaults.standard.string(forKey: "dmxProtocol") ?? DMXProtocolType.artnet.rawValue
        self.dmxProtocol = DMXProtocolType(rawValue: protocolString) ?? .artnet
        self.dmxBroadcastAddress = UserDefaults.standard.string(forKey: "dmxBroadcastAddress") ?? "255.255.255.255"
        self.dmxOutputRate = UserDefaults.standard.object(forKey: "dmxOutputRate") as? Int ?? 40
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

class LANDiscovery: NSObject, DeviceDiscoveryProtocol, NetServiceBrowserDelegate, NetServiceDelegate {
    private var browser: NetServiceBrowser?
    private let serviceStore = LANServiceStore()
    private var continuation: CheckedContinuation<[GoveeDevice], Error>?

    private func takeContinuation() -> CheckedContinuation<[GoveeDevice], Error>? {
        let cont = continuation
        continuation = nil
        return cont
    }
    
    override init() {
        super.init()
    }
    
    deinit {
        Task { [weak self] in
            await MainActor.run { self?.cleanup() }
        }
    }
    
    private func cleanup() {
        browser?.stop()
        browser?.delegate = nil
        browser = nil
    }

    func refreshDevices() async throws -> [GoveeDevice] {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(returning: [])
                return
            }
            self.continuation = continuation

            Task { [weak self] in
                guard let self = self else { return }
                await self.serviceStore.reset()
            }

            self.browser = NetServiceBrowser()
            self.browser?.delegate = self
            // Search for common smart light service types
            // Govee, WLED, Hue (Bonjour), Lifx, and generic HTTP lights
            self.browser?.searchForServices(ofType: "_govee._tcp.", inDomain: "local.")
            self.browser?.searchForServices(ofType: "_wled._tcp.", inDomain: "local.")
            self.browser?.searchForServices(ofType: "_hap._tcp.", inDomain: "local.")
            self.browser?.searchForServices(ofType: "_lifx._tcp.", inDomain: "local.")
            self.browser?.searchForServices(ofType: "_http._tcp.", inDomain: "local.")

            Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard let self = self else { return }
                await MainActor.run {
                    self.browser?.stop()
                    self.browser?.delegate = nil
                }
                if let cont = self.takeContinuation() {
                    let devices = await self.serviceStore.resolvedDevices
                    cont.resume(returning: devices)
                }
            }
        }
    }
    
    // Handle delegate callbacks and ensure resolve runs on the main thread
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            service.delegate = self
            service.resolve(withTimeout: 3.0)
        }
    }
    
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
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        // Ignore resolution failures
    }
}

struct LANControl: DeviceControlProtocol {
    let deviceIP: String
    
    private func sendLANCommand(cmd: [String: Any]) async throws {
        guard let url = URL(string: "http://\(deviceIP)/device/control") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
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
        Task { @MainActor [weak self] in
            if let home = manager.primaryHome {
                self?.accessories = home.accessories
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

// MARK: - DMX Implementation

actor DMXUniverseManager {
    private var universes: [Int: [UInt8]] = [:]
    
    func getUniverse(_ universeID: Int) -> [UInt8] {
        if universes[universeID] == nil {
            universes[universeID] = Array(repeating: 0, count: 512)
        }
        return universes[universeID]!
    }
    
    func setChannel(_ universeID: Int, channel: Int, value: UInt8) {
        if universes[universeID] == nil {
            universes[universeID] = Array(repeating: 0, count: 512)
        }
        if channel >= 1 && channel <= 512 {
            universes[universeID]![channel - 1] = value
        }
    }
    
    func setChannels(_ universeID: Int, startChannel: Int, values: [UInt8]) {
        if universes[universeID] == nil {
            universes[universeID] = Array(repeating: 0, count: 512)
        }
        for (offset, value) in values.enumerated() {
            let channel = startChannel + offset
            if channel >= 1 && channel <= 512 {
                universes[universeID]![channel - 1] = value
            }
        }
    }
}

class DMXController {
    private let socket: CFSocket?
    private let protocol: DMXProtocolType
    private let broadcastAddress: String
    private let universeManager = DMXUniverseManager()
    private var sequenceNumber: UInt8 = 0
    
    init(protocol: DMXProtocolType, broadcastAddress: String = "255.255.255.255") {
        self.protocol = `protocol`
        self.broadcastAddress = broadcastAddress
        
        // Create UDP socket
        var context = CFSocketContext()
        self.socket = CFSocketCreate(
            kCFAllocatorDefault,
            PF_INET,
            SOCK_DGRAM,
            IPPROTO_UDP,
            0,
            nil,
            &context
        )
        
        // Enable broadcast
        if let socket = self.socket {
            let fd = CFSocketGetNative(socket)
            var broadcast: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
        }
    }
    
    deinit {
        if let socket = socket {
            CFSocketInvalidate(socket)
        }
    }
    
    func sendDMXData(universe: Int, channels: [UInt8]) async throws {
        guard let socket = socket else { return }
        
        let packet: Data
        switch `protocol` {
        case .artnet:
            packet = createArtNetPacket(universe: universe, data: channels)
        case .sacn:
            packet = createSACNPacket(universe: universe, data: channels)
        }
        
        // Setup address
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        
        let port: UInt16
        switch `protocol` {
        case .artnet:
            port = 6454
        case .sacn:
            port = 5568
        }
        addr.sin_port = port.bigEndian
        
        if broadcastAddress == "255.255.255.255" {
            addr.sin_addr.s_addr = INADDR_BROADCAST
        } else {
            broadcastAddress.withCString { cString in
                inet_pton(AF_INET, cString, &addr.sin_addr)
            }
        }
        
        // Send packet
        let addressData = Data(bytes: &addr, count: MemoryLayout<sockaddr_in>.size)
        packet.withUnsafeBytes { bufferPtr in
            if let baseAddress = bufferPtr.baseAddress {
                let data = CFDataCreate(kCFAllocatorDefault, baseAddress.assumingMemoryBound(to: UInt8.self), packet.count)
                let address = CFDataCreate(kCFAllocatorDefault, addressData.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) }, addressData.count)
                CFSocketSendData(socket, address, data, 0)
            }
        }
    }
    
    private func createArtNetPacket(universe: Int, data: [UInt8]) -> Data {
        var packet = Data()
        
        // Art-Net header
        packet.append(contentsOf: "Art-Net\0".utf8) // ID (8 bytes)
        packet.append(contentsOf: [0x00, 0x50]) // OpCode ArtDMX (0x5000 little-endian)
        packet.append(contentsOf: [0x00, 0x0e]) // Protocol version 14
        packet.append(0) // Sequence (0 = no sequence)
        packet.append(0) // Physical port
        packet.append(UInt8(universe & 0xFF)) // Universe low byte
        packet.append(UInt8((universe >> 8) & 0xFF)) // Universe high byte
        
        // Length (high byte first)
        let length = UInt16(min(data.count, 512))
        packet.append(UInt8((length >> 8) & 0xFF))
        packet.append(UInt8(length & 0xFF))
        
        // DMX data
        packet.append(contentsOf: data.prefix(512))
        
        return packet
    }
    
    private func createSACNPacket(universe: Int, data: [UInt8]) -> Data {
        var packet = Data()
        
        // Root Layer
        packet.append(contentsOf: [0x00, 0x10]) // Preamble Size
        packet.append(contentsOf: [0x00, 0x00]) // Post-amble Size
        packet.append(contentsOf: "ASC-E1.17\0\0\0".utf8) // ACN Packet Identifier (12 bytes)
        
        let rootFlags: UInt16 = 0x7000 | UInt16(638) // Flags and PDU length
        packet.append(UInt8((rootFlags >> 8) & 0xFF))
        packet.append(UInt8(rootFlags & 0xFF))
        
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x04]) // Root Vector (VECTOR_ROOT_E131_DATA)
        
        // CID (Component Identifier) - 16 bytes UUID
        let uuid = UUID()
        packet.append(contentsOf: uuid.uuid.0.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.1.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.2.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.3.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.4.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.5.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.6.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.7.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.8.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.9.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.10.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.11.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.12.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.13.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.14.bigEndian.bytes)
        packet.append(contentsOf: uuid.uuid.15.bigEndian.bytes)
        
        // Framing Layer
        let framingFlags: UInt16 = 0x7000 | UInt16(610)
        packet.append(UInt8((framingFlags >> 8) & 0xFF))
        packet.append(UInt8(framingFlags & 0xFF))
        
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x02]) // Framing Vector (VECTOR_E131_DATA_PACKET)
        
        // Source Name (64 bytes)
        let sourceName = "Govee Mac DMX".padding(toLength: 64, withPad: "\0", startingAt: 0)
        packet.append(contentsOf: sourceName.utf8.prefix(64))
        
        packet.append(100) // Priority
        packet.append(contentsOf: [0x00, 0x00]) // Synchronization Address (reserved)
        
        sequenceNumber = sequenceNumber &+ 1
        packet.append(sequenceNumber) // Sequence Number
        packet.append(0) // Options
        packet.append(UInt8((universe >> 8) & 0xFF)) // Universe high byte
        packet.append(UInt8(universe & 0xFF)) // Universe low byte
        
        // DMP Layer
        let dmpFlags: UInt16 = 0x7000 | UInt16(523)
        packet.append(UInt8((dmpFlags >> 8) & 0xFF))
        packet.append(UInt8(dmpFlags & 0xFF))
        
        packet.append(0x02) // DMP Vector (VECTOR_DMP_SET_PROPERTY)
        packet.append(0xa1) // Address Type & Data Type
        packet.append(contentsOf: [0x00, 0x00]) // First Property Address
        packet.append(contentsOf: [0x00, 0x01]) // Address Increment
        
        let propertyCount = UInt16(data.count + 1)
        packet.append(UInt8((propertyCount >> 8) & 0xFF))
        packet.append(UInt8(propertyCount & 0xFF))
        
        packet.append(0) // START Code
        packet.append(contentsOf: data.prefix(512))
        
        return packet
    }
}

extension UInt8 {
    var bytes: [UInt8] {
        return [self]
    }
}

extension UInt16 {
    var bytes: [UInt8] {
        return [UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)]
    }
}

struct DMXControl: DeviceControlProtocol {
    let controller: DMXController
    let universeManager: DMXUniverseManager
    
    private func updateDevice(_ device: GoveeDevice, updateBlock: @escaping ([UInt8]) -> [UInt8]) async throws {
        guard let mapping = device.dmxMapping else { return }
        
        let currentData = await universeManager.getUniverse(mapping.universe)
        let updatedData = updateBlock(currentData)
        
        await universeManager.setChannels(mapping.universe, startChannel: mapping.startChannel, values: updatedData)
        try await controller.sendDMXData(universe: mapping.universe, channels: await universeManager.getUniverse(mapping.universe))
    }
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        try await updateDevice(device) { currentData in
            guard let mapping = device.dmxMapping else { return [] }
            
            switch mapping.channelMode {
            case .single:
                return [on ? 255 : 0]
            case .rgb:
                // For RGB, set all channels to 0 or restore last color
                return on ? [255, 255, 255] : [0, 0, 0]
            case .rgbw, .rgba:
                return on ? [255, 255, 255, 255] : [0, 0, 0, 0]
            case .rgbDimmer:
                return on ? [255, 255, 255, 255] : [0, 0, 0, 0]
            case .extended:
                return on ? [255, 255, 255, 255, 255, 255] : [0, 0, 0, 0, 0, 0]
            }
        }
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        let dmxValue = UInt8(min(max(value, 0), 100) * 255 / 100)
        
        try await updateDevice(device) { currentData in
            guard let mapping = device.dmxMapping else { return [] }
            
            switch mapping.channelMode {
            case .single:
                return [dmxValue]
            case .rgb:
                // For RGB without dimmer, scale all RGB channels
                if currentData.count >= 3 {
                    let r = currentData[0]
                    let g = currentData[1]
                    let b = currentData[2]
                    return [
                        UInt8(Double(r) * Double(dmxValue) / 255.0),
                        UInt8(Double(g) * Double(dmxValue) / 255.0),
                        UInt8(Double(b) * Double(dmxValue) / 255.0)
                    ]
                }
                return [dmxValue, dmxValue, dmxValue]
            case .rgbDimmer:
                // Dimmer is first channel
                var result = currentData
                if result.count >= 4 {
                    result[0] = dmxValue
                } else {
                    result = [dmxValue, 255, 255, 255]
                }
                return Array(result.prefix(4))
            case .rgbw, .rgba:
                // Scale all color channels
                if currentData.count >= 4 {
                    return currentData.enumerated().map { idx, val in
                        UInt8(Double(val) * Double(dmxValue) / 255.0)
                    }
                }
                return [dmxValue, dmxValue, dmxValue, dmxValue]
            case .extended:
                // First channel is usually dimmer
                var result = currentData
                if result.count >= 6 {
                    result[0] = dmxValue
                } else {
                    result = [dmxValue, 255, 255, 255, 255, 255]
                }
                return Array(result.prefix(6))
            }
        }
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        try await updateDevice(device) { currentData in
            guard let mapping = device.dmxMapping else { return [] }
            
            switch mapping.channelMode {
            case .single:
                // Single channel can only do brightness, calculate from RGB
                let brightness = (color.r + color.g + color.b) / 3
                return [UInt8(brightness)]
            case .rgb:
                return [UInt8(color.r), UInt8(color.g), UInt8(color.b)]
            case .rgbw:
                // Calculate white channel from RGB
                let white = min(color.r, color.g, color.b)
                return [UInt8(color.r), UInt8(color.g), UInt8(color.b), UInt8(white)]
            case .rgba:
                return [UInt8(color.r), UInt8(color.g), UInt8(color.b), 0]
            case .rgbDimmer:
                // Keep existing dimmer value if available
                let dimmer = currentData.count > 0 ? currentData[0] : 255
                return [dimmer, UInt8(color.r), UInt8(color.g), UInt8(color.b)]
            case .extended:
                // Keep dimmer, set RGB, and additional channels
                let dimmer = currentData.count > 0 ? currentData[0] : 255
                return [dimmer, UInt8(color.r), UInt8(color.g), UInt8(color.b), 0, 0]
            }
        }
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        // Color temperature control for DMX is complex and device-specific
        // This is a basic implementation that adjusts white/amber balance
        try await updateDevice(device) { currentData in
            guard let mapping = device.dmxMapping else { return [] }
            
            // Map color temperature (2000-9000K) to warm/cool balance
            let normalizedTemp = Double(min(max(value, 2000), 9000) - 2000) / 7000.0
            let coolWhite = UInt8(normalizedTemp * 255.0)
            let warmWhite = UInt8((1.0 - normalizedTemp) * 255.0)
            
            switch mapping.channelMode {
            case .single:
                return [UInt8((coolWhite + warmWhite) / 2)]
            case .rgb:
                // Approximate color temp with RGB
                if normalizedTemp > 0.5 {
                    return [coolWhite, coolWhite, 255]
                } else {
                    return [255, warmWhite, warmWhite]
                }
            case .rgbw:
                return currentData.count >= 4 ? [currentData[0], currentData[1], currentData[2], UInt8((coolWhite + warmWhite) / 2)] : [255, 255, 255, 255]
            case .rgba:
                return currentData.count >= 4 ? [currentData[0], currentData[1], currentData[2], warmWhite] : [255, 255, 255, 128]
            case .rgbDimmer:
                let dimmer = currentData.count > 0 ? currentData[0] : 255
                if normalizedTemp > 0.5 {
                    return [dimmer, coolWhite, coolWhite, 255]
                } else {
                    return [dimmer, 255, warmWhite, warmWhite]
                }
            case .extended:
                let dimmer = currentData.count > 0 ? currentData[0] : 255
                return [dimmer, 255, 255, 255, coolWhite, warmWhite]
            }
        }
    }
}

// MARK: - Controller

@MainActor
class GoveeController: ObservableObject {
    private let deviceStore: DeviceStore
    private let settings: SettingsStore
    private var pollingTask: Task<Void, Never>?
    private var dmxController: DMXController?
    private let dmxUniverseManager = DMXUniverseManager()
    
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
        
        if settings.dmxEnabled {
            self.dmxController = DMXController(
                protocol: settings.dmxProtocol,
                broadcastAddress: settings.dmxBroadcastAddress
            )
        }
        
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
        // DMX has highest priority for devices with DMX mapping
        if settings.dmxEnabled, device.transports.contains(.dmx), device.dmxMapping != nil, let dmxCtrl = dmxController {
            return DMXControl(controller: dmxCtrl, universeManager: dmxUniverseManager)
        }
        
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

