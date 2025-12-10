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
    case cloud, lan, homeKit, homeAssistant, dmx, hue, wled, lifx
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

enum DMXChannelFunction: String, Codable, CaseIterable {
    case dimmer = "Dimmer"
    case red = "Red"
    case green = "Green"
    case blue = "Blue"
    case white = "White"
    case amber = "Amber"
    case strobe = "Strobe"
    case unused = "Unused"
}

struct DMXCustomChannel: Codable, Hashable, Identifiable {
    let id: UUID
    var channelNumber: Int // Relative to start (0-based offset)
    var function: DMXChannelFunction
    
    init(id: UUID = UUID(), channelNumber: Int, function: DMXChannelFunction) {
        self.id = id
        self.channelNumber = channelNumber
        self.function = function
    }
}

struct DMXProfile: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var channels: [DMXCustomChannel]
    var isBuiltIn: Bool
    
    init(id: String = UUID().uuidString, name: String, channels: [DMXCustomChannel], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.channels = channels
        self.isBuiltIn = isBuiltIn
    }
    
    var channelCount: Int {
        channels.isEmpty ? 1 : (channels.map { $0.channelNumber }.max() ?? 0) + 1
    }
    
    // Built-in profiles
    static var builtInProfiles: [DMXProfile] {
        [
            DMXProfile(
                id: "builtin_single",
                name: "Single Dimmer (1 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .dimmer)
                ],
                isBuiltIn: true
            ),
            DMXProfile(
                id: "builtin_rgb",
                name: "RGB (3 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .red),
                    DMXCustomChannel(channelNumber: 1, function: .green),
                    DMXCustomChannel(channelNumber: 2, function: .blue)
                ],
                isBuiltIn: true
            ),
            DMXProfile(
                id: "builtin_rgbw",
                name: "RGBW (4 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .red),
                    DMXCustomChannel(channelNumber: 1, function: .green),
                    DMXCustomChannel(channelNumber: 2, function: .blue),
                    DMXCustomChannel(channelNumber: 3, function: .white)
                ],
                isBuiltIn: true
            ),
            DMXProfile(
                id: "builtin_rgba",
                name: "RGBA (4 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .red),
                    DMXCustomChannel(channelNumber: 1, function: .green),
                    DMXCustomChannel(channelNumber: 2, function: .blue),
                    DMXCustomChannel(channelNumber: 3, function: .amber)
                ],
                isBuiltIn: true
            ),
            DMXProfile(
                id: "builtin_rgbDimmer",
                name: "RGB + Dimmer (4 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .dimmer),
                    DMXCustomChannel(channelNumber: 1, function: .red),
                    DMXCustomChannel(channelNumber: 2, function: .green),
                    DMXCustomChannel(channelNumber: 3, function: .blue)
                ],
                isBuiltIn: true
            ),
            DMXProfile(
                id: "builtin_extended",
                name: "Extended RGBWA (6 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .dimmer),
                    DMXCustomChannel(channelNumber: 1, function: .red),
                    DMXCustomChannel(channelNumber: 2, function: .green),
                    DMXCustomChannel(channelNumber: 3, function: .blue),
                    DMXCustomChannel(channelNumber: 4, function: .white),
                    DMXCustomChannel(channelNumber: 5, function: .amber)
                ],
                isBuiltIn: true
            )
        ]
    }
}

struct DMXChannelMapping: Codable, Hashable {
    var universe: Int
    var startChannel: Int // 1-512
    var profileID: String // Reference to DMXProfile
    
    // Legacy support - will be converted to custom profiles
    var channelMode: DMXChannelMode?
    
    enum DMXChannelMode: String, Codable {
        case single      // Single channel dimmer (1 channel)
        case rgb         // RGB (3 channels: R, G, B)
        case rgbw        // RGBW (4 channels: R, G, B, W)
        case rgba        // RGBA (4 channels: R, G, B, Amber)
        case rgbDimmer   // RGB + Dimmer (4 channels: Dimmer, R, G, B)
        case extended    // Extended mode (Dimmer, R, G, B, W, Amber, etc.)
    }
    
    init(universe: Int, startChannel: Int, profileID: String) {
        self.universe = universe
        self.startChannel = startChannel
        self.profileID = profileID
        self.channelMode = nil
    }
    
    // Legacy initializer
    init(universe: Int, startChannel: Int, channelMode: DMXChannelMode) {
        self.universe = universe
        self.startChannel = startChannel
        self.channelMode = channelMode
        // Map to built-in profile
        switch channelMode {
        case .single: self.profileID = "builtin_single"
        case .rgb: self.profileID = "builtin_rgb"
        case .rgbw: self.profileID = "builtin_rgbw"
        case .rgba: self.profileID = "builtin_rgba"
        case .rgbDimmer: self.profileID = "builtin_rgbDimmer"
        case .extended: self.profileID = "builtin_extended"
        }
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
    // Dictionary to store Hue username (API key) per bridge IP
    @Published var hueBridgeCredentials: [String: String] = [:] {
        didSet {
            if let encoded = try? JSONEncoder().encode(hueBridgeCredentials) {
                UserDefaults.standard.set(encoded, forKey: "hueBridgeCredentials")
            }
        }
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
        
        // Load Hue bridge credentials
        if let data = UserDefaults.standard.data(forKey: "hueBridgeCredentials"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.hueBridgeCredentials = decoded
        }
    }
}

@MainActor
final class DMXProfileStore: ObservableObject {
    @Published var customProfiles: [DMXProfile] = [] {
        didSet { saveProfiles() }
    }
    
    var allProfiles: [DMXProfile] {
        DMXProfile.builtInProfiles + customProfiles
    }
    
    init() {
        loadProfiles()
    }
    
    func getProfile(id: String) -> DMXProfile? {
        allProfiles.first { $0.id == id }
    }
    
    func addProfile(_ profile: DMXProfile) {
        customProfiles.append(profile)
    }
    
    func updateProfile(_ profile: DMXProfile) {
        if let index = customProfiles.firstIndex(where: { $0.id == profile.id }) {
            customProfiles[index] = profile
        }
    }
    
    func deleteProfile(id: String) {
        customProfiles.removeAll { $0.id == id }
    }
    
    private func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(customProfiles) {
            UserDefaults.standard.set(encoded, forKey: "dmxCustomProfiles")
        }
    }
    
    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: "dmxCustomProfiles"),
           let decoded = try? JSONDecoder().decode([DMXProfile].self, from: data) {
            customProfiles = decoded
        }
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
        
        // Determine transport type based on service type
        var transport: TransportKind = .lan
        let serviceType = sender.type
        
        if serviceType.contains("_wled") {
            transport = .wled
        } else if serviceType.contains("_lifx") {
            transport = .lifx
        } else if serviceType.contains("_govee") {
            transport = .lan
        }
        // Note: Hue devices broadcast as _hap._tcp. (HomeKit) but we discover them
        // separately via HueBridgeDiscovery using the Hue cloud discovery service
        
        let device = GoveeDevice(
            id: "\(transport.rawValue)-\(sender.name)-\(ipAddress)",
            name: sender.name,
            model: nil,
            ipAddress: ipAddress,
            online: true,
            supportsBrightness: true,
            supportsColor: true,
            supportsColorTemperature: transport == .hue || transport == .wled,
            transports: [transport],
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
        // Discover ALL HomeKit accessories with light services, not just Govee
        // This enables support for Philips Hue, LIFX, Nanoleaf, and other HomeKit lights
        let lightAccessories = home.accessories.filter { acc in
            acc.services.contains { $0.serviceType == HMServiceTypeLightbulb }
        }
        
        return lightAccessories.compactMap { accessory in
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
                // Accept all light entities from Home Assistant (not just Govee)
                // This allows control of Hue, LIFX, and other brands via HA
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
    
    func updateUniverse(_ universeID: Int, channels: [UInt8]) {
        universes[universeID] = channels
    }
    
    func getChannelValue(_ universeID: Int, channel: Int) -> UInt8? {
        guard let universe = universes[universeID], channel >= 1, channel <= 512 else { return nil }
        return universe[channel - 1]
    }
    
    func getChannelValues(_ universeID: Int, startChannel: Int, count: Int) -> [UInt8] {
        guard let universe = universes[universeID] else { return [] }
        let start = max(0, startChannel - 1)
        let end = min(512, start + count)
        return Array(universe[start..<end])
    }
}

@MainActor
class DMXReceiver: ObservableObject {
    private var socket: Int32 = -1
    private let universeManager = DMXUniverseManager()
    private var receiveTask: Task<Void, Never>?
    private let `protocol`: DMXProtocolType
    weak var controller: GoveeController?
    
    init(protocol: DMXProtocolType) {
        self.protocol = `protocol`
    }
    
    func start() throws {
        let port: UInt16
        switch `protocol` {
        case .artnet:
            port = 6454
        case .sacn:
            port = 5568
        }
        
        // Create UDP socket
        socket = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socket >= 0 else {
            throw NSError(domain: "DMXReceiver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
        }
        
        // Set socket options
        var reuseAddr: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        
        // Bind to port
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            Darwin.close(socket)
            throw NSError(domain: "DMXReceiver", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to bind socket to port \(port)"])
        }
        
        // For sACN, join multicast group
        if `protocol` == .sacn {
            // sACN uses multicast addresses 239.255.0.0 - 239.255.63.255
            // Universe 1 = 239.255.0.1, etc.
            // For now, join the base multicast group
            var mreq = ip_mreq()
            inet_pton(AF_INET, "239.255.0.1", &mreq.imr_multiaddr)
            mreq.imr_interface.s_addr = INADDR_ANY
            setsockopt(socket, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, socklen_t(MemoryLayout<ip_mreq>.size))
        }
        
        // Start receiving
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }
    
    func stop() {
        receiveTask?.cancel()
        if socket >= 0 {
            Darwin.close(socket)
            socket = -1
        }
    }
    
    deinit {
        if socket >= 0 {
            Darwin.close(socket)
        }
    }
    
    private func receiveLoop() async {
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        while !Task.isCancelled {
            let bytesReceived = recv(socket, &buffer, bufferSize, 0)
            
            if bytesReceived > 0 {
                let data = Data(buffer.prefix(bytesReceived))
                await processPacket(data)
            }
            
            // Small delay to prevent tight loop
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
    }
    
    private func processPacket(_ data: Data) async {
        switch `protocol` {
        case .artnet:
            await processArtNetPacket(data)
        case .sacn:
            await processSACNPacket(data)
        }
    }
    
    private func processArtNetPacket(_ data: Data) async {
        guard data.count >= 18 else { return }
        
        // Check Art-Net header
        let header = String(data: data.prefix(8), encoding: .utf8)
        guard header == "Art-Net\0" else { return }
        
        // Check OpCode (should be 0x5000 for ArtDMX)
        let opCode = UInt16(data[8]) | (UInt16(data[9]) << 8)
        guard opCode == 0x5000 else { return }
        
        // Get universe
        let universeLow = Int(data[14])
        let universeHigh = Int(data[15])
        let universe = universeLow | (universeHigh << 8)
        
        // Get data length
        let lengthHigh = Int(data[16])
        let lengthLow = Int(data[17])
        let length = (lengthHigh << 8) | lengthLow
        
        // Extract DMX data
        let dmxStart = 18
        let dmxEnd = min(dmxStart + length, data.count)
        guard dmxEnd > dmxStart else { return }
        
        let dmxData = Array(data[dmxStart..<dmxEnd])
        
        // Update universe
        await universeManager.updateUniverse(universe, channels: dmxData)
        
        // Update devices
        await updateDevicesFromDMX(universe: universe)
    }
    
    private func processSACNPacket(_ data: Data) async {
        guard data.count >= 126 else { return }
        
        // Check ACN Packet Identifier
        let identifier = String(data: data[4..<16], encoding: .utf8)
        guard identifier?.hasPrefix("ASC-E1.17") == true else { return }
        
        // Get universe from framing layer
        let universeHigh = Int(data[113])
        let universeLow = Int(data[114])
        let universe = (universeHigh << 8) | universeLow
        
        // DMX data starts at byte 126
        let dmxStart = 126
        guard data.count > dmxStart else { return }
        
        let dmxData = Array(data[dmxStart...])
        
        // Update universe
        await universeManager.updateUniverse(universe, channels: dmxData)
        
        // Update devices
        await updateDevicesFromDMX(universe: universe)
    }
    
    private func updateDevicesFromDMX(universe: Int) async {
        guard let controller = await MainActor.run(body: { controller }) else { return }
        
        let devices = await MainActor.run { controller.deviceStore.devices }
        let profileStore = await MainActor.run { controller.profileStore }
        
        for device in devices {
            guard let mapping = device.dmxMapping,
                  mapping.universe == universe else { continue }
            
            // Get profile
            guard let profile = await MainActor.run(body: { profileStore.getProfile(id: mapping.profileID) }) else { continue }
            
            // Get channel values
            let channelCount = profile.channelCount
            let values = await universeManager.getChannelValues(universe, startChannel: mapping.startChannel, count: channelCount)
            guard !values.isEmpty else { continue }
            
            // Apply to device based on profile
            await applyDMXToDevice(device: device, profile: profile, values: values)
        }
    }
    
    private func applyDMXToDevice(device: GoveeDevice, profile: DMXProfile, values: [UInt8]) async {
        guard let controller = await MainActor.run(body: { controller }) else { return }
        
        // Extract values by function
        var dimmerValue: UInt8? = nil
        var redValue: UInt8 = 0
        var greenValue: UInt8 = 0
        var blueValue: UInt8 = 0
        var whiteValue: UInt8 = 0
        
        for channel in profile.channels {
            guard channel.channelNumber < values.count else { continue }
            let value = values[channel.channelNumber]
            
            switch channel.function {
            case .dimmer:
                dimmerValue = value
            case .red:
                redValue = value
            case .green:
                greenValue = value
            case .blue:
                blueValue = value
            case .white:
                whiteValue = value
            case .amber:
                // Amber can be used as warmth or ignored
                break
            case .strobe, .unused:
                // Ignore these functions
                break
            }
        }
        
        await MainActor.run {
            Task {
                // Determine if light should be on
                let hasColor = redValue > 0 || greenValue > 0 || blueValue > 0
                let hasDimmer = dimmerValue ?? 0 > 0
                let hasWhite = whiteValue > 0
                let isOn = hasColor || hasDimmer || hasWhite
                
                try? await controller.setDevicePower(device: device, on: isOn)
                
                if isOn {
                    // Set brightness if dimmer is present
                    if let dimmer = dimmerValue {
                        let brightness = Int(Double(dimmer) / 255.0 * 100.0)
                        try? await controller.setDeviceBrightness(device: device, value: brightness)
                    } else if whiteValue > 0 {
                        // Use white as brightness if no dimmer
                        let brightness = Int(Double(whiteValue) / 255.0 * 100.0)
                        try? await controller.setDeviceBrightness(device: device, value: brightness)
                    }
                    
                    // Set color if RGB channels are present
                    if hasColor {
                        let color = DeviceColor(r: Int(redValue), g: Int(greenValue), b: Int(blueValue))
                        try? await controller.setDeviceColor(device: device, color: color)
                    }
                }
            }
        }
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
    // This is no longer used as a control protocol since we're receiving, not sending
    // But we keep it for compatibility
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        // No-op - control comes from DMX input
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        // No-op - control comes from DMX input
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        // No-op - control comes from DMX input
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        // No-op - control comes from DMX input
    }
}

// MARK: - Philips Hue Bridge Implementation

struct HueBridgeDiscovery: DeviceDiscoveryProtocol {
    func refreshDevices() async throws -> [GoveeDevice] {
        // Discover bridges using mDNS and Hue cloud discovery
        let bridges = try await discoverBridges()
        
        var devices: [GoveeDevice] = []
        for bridge in bridges {
            // Get lights from each bridge
            let lights = try? await getLightsFromBridge(bridge)
            if let lights = lights {
                devices.append(contentsOf: lights)
            }
        }
        return devices
    }
    
    private func discoverBridges() async throws -> [(ip: String, id: String)] {
        // Try mDNS discovery first via _hue._tcp service
        // Then fall back to Hue cloud discovery API
        var bridges: [(ip: String, id: String)] = []
        
        // Use Hue cloud discovery service
        if let url = URL(string: "https://discovery.meethue.com/") {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return bridges
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for bridge in json {
                    if let ip = bridge["internalipaddress"] as? String,
                       let id = bridge["id"] as? String {
                        bridges.append((ip: ip, id: id))
                    }
                }
            }
        }
        
        return bridges
    }
    
    private func getLightsFromBridge(_ bridge: (ip: String, id: String)) async throws -> [GoveeDevice] {
        // Note: This requires the user to have already registered an API key with the bridge
        // For now, we'll skip lights that require authentication
        // In a full implementation, we'd need to handle the "press link button" flow
        
        // Try to get config to check if we have access
        guard let url = URL(string: "http://\(bridge.ip)/api/config") else {
            return []
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }
        
        // For now, return empty array since we need API key setup
        // TODO: Implement API key registration flow with link button press
        return []
    }
}

struct HueBridgeControl: DeviceControlProtocol {
    let bridgeIP: String
    let username: String // Hue API username (created via link button)
    
    private func sendCommand(_ device: GoveeDevice, state: [String: Any]) async throws {
        guard let lightID = device.id.components(separatedBy: "-").last else {
            throw URLError(.badURL)
        }
        
        guard let url = URL(string: "http://\(bridgeIP)/api/\(username)/lights/\(lightID)/state") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: state)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        try await sendCommand(device, state: ["on": on])
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        // Hue uses 0-254 for brightness
        let hueBrightness = Int(Double(value) / 100.0 * 254.0)
        try await sendCommand(device, state: ["bri": hueBrightness])
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        // Convert RGB to Hue/Saturation
        let r = Double(color.r) / 255.0
        let g = Double(color.g) / 255.0
        let b = Double(color.b) / 255.0
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        var hue: Double = 0
        if delta != 0 {
            if maxC == r {
                let h = (g - b) / delta
                hue = 60 * (h < 0 ? h + 6 : h)  // Ensure positive result
            } else if maxC == g {
                hue = 60 * (((b - r) / delta) + 2)
            } else {
                hue = 60 * (((r - g) / delta) + 4)
            }
        }
        // Normalize hue to 0-360 range
        while hue < 0 { hue += 360 }
        while hue >= 360 { hue -= 360 }
        
        let saturation = maxC == 0 ? 0 : (delta / maxC)
        
        // Hue uses 0-65535 for hue, 0-254 for saturation
        let hueValue = Int(hue / 360.0 * 65535.0)
        let satValue = Int(saturation * 254.0)
        
        try await sendCommand(device, state: ["hue": hueValue, "sat": satValue])
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        // Hue uses mireds (1,000,000 / kelvin)
        let mireds = Int(1_000_000 / Double(value))
        try await sendCommand(device, state: ["ct": mireds])
    }
}

// MARK: - WLED Implementation

struct WLEDDiscovery: DeviceDiscoveryProtocol {
    func refreshDevices() async throws -> [GoveeDevice] {
        // WLED devices are discovered via mDNS (_wled._tcp.)
        // This is handled by LANDiscovery, but we need to identify them
        // For now, return empty as LANDiscovery will pick them up
        return []
    }
}

struct WLEDControl: DeviceControlProtocol {
    let deviceIP: String
    
    private func sendCommand(_ state: [String: Any]) async throws {
        guard let url = URL(string: "http://\(deviceIP)/json/state") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: state)
        request.timeoutInterval = 3
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        try await sendCommand(["on": on])
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        // WLED uses 0-255 for brightness
        let wledBrightness = Int(Double(value) / 100.0 * 255.0)
        try await sendCommand(["bri": wledBrightness])
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        // WLED accepts RGB as array [r, g, b]
        try await sendCommand(["seg": [["col": [[color.r, color.g, color.b]]]]])
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        // WLED doesn't directly support color temperature control
        // Could be approximated with RGB conversion, but not implemented
        throw SmartLightError.featureNotSupported("WLED color temperature control")
    }
}

// MARK: - Protocol Errors

enum SmartLightError: LocalizedError {
    case featureNotSupported(String)
    case notImplemented(String)
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .featureNotSupported(let detail):
            return "Feature not supported: \(detail)"
        case .notImplemented(let detail):
            return "Not yet implemented: \(detail)"
        case .authenticationRequired:
            return "Authentication required. Please configure device credentials."
        }
    }
}

// MARK: - LIFX Implementation

struct LIFXDiscovery: DeviceDiscoveryProtocol {
    func refreshDevices() async throws -> [GoveeDevice] {
        // LIFX devices are discovered via mDNS (_lifx._tcp.)
        // This is handled by LANDiscovery
        return []
    }
}

struct LIFXControl: DeviceControlProtocol {
    let deviceIP: String
    
    // LIFX LAN Protocol uses UDP packets on port 56700
    // Full implementation requires binary protocol over UDP
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        // Requires LIFX binary protocol implementation
        // Packet structure: Header (36 bytes) + Payload (varies by message type)
        throw SmartLightError.notImplemented("LIFX UDP binary protocol")
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        throw SmartLightError.notImplemented("LIFX UDP binary protocol")
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        throw SmartLightError.notImplemented("LIFX UDP binary protocol")
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        throw SmartLightError.notImplemented("LIFX UDP binary protocol")
    }
}

// MARK: - Controller

@MainActor
class GoveeController: ObservableObject {
    let deviceStore: DeviceStore
    let profileStore: DMXProfileStore
    private let settings: SettingsStore
    private var pollingTask: Task<Void, Never>?
    private var dmxReceiver: DMXReceiver?
    
    #if canImport(HomeKit)
    @available(macOS 10.15, *)
    private var homeKitManager: HomeKitManager?
    #endif
    
    init(deviceStore: DeviceStore, settings: SettingsStore, profileStore: DMXProfileStore) {
        self.deviceStore = deviceStore
        self.settings = settings
        self.profileStore = profileStore
        
        #if canImport(HomeKit)
        if #available(macOS 10.15, *), settings.homeKitEnabled {
            self.homeKitManager = HomeKitManager()
        }
        #endif
        
        if settings.dmxEnabled {
            let receiver = DMXReceiver(protocol: settings.dmxProtocol)
            receiver.controller = self
            self.dmxReceiver = receiver
            do {
                try receiver.start()
                print("DMX Receiver started on \(settings.dmxProtocol.rawValue)")
            } catch {
                print("Failed to start DMX receiver: \(error)")
            }
        }
        
        startPolling()
    }
    
    deinit {
        pollingTask?.cancel()
        dmxReceiver?.stop()
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
        
        // Philips Hue Bridge Discovery
        let hueDiscovery = HueBridgeDiscovery()
        if let devices = try? await hueDiscovery.refreshDevices() {
            for dev in devices {
                if var existing = merged[dev.id] {
                    existing.transports.insert(.hue)
                    merged[dev.id] = existing
                } else {
                    merged[dev.id] = dev
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
        // DMX devices are controlled via incoming DMX signals, not direct control
        // So we skip them here and fall through to other transports
        
        // WLED devices
        if device.transports.contains(.wled), let ip = device.ipAddress {
            return WLEDControl(deviceIP: ip)
        }
        
        // LIFX devices (LAN protocol)
        // Note: LIFX requires UDP binary protocol - not yet fully implemented
        if device.transports.contains(.lifx), let ip = device.ipAddress {
            // return LIFXControl(deviceIP: ip)  // Uncomment when UDP protocol is implemented
        }
        
        // Philips Hue Bridge devices
        if device.transports.contains(.hue), let ip = device.ipAddress,
           let username = settings.hueBridgeCredentials[ip] {
            return HueBridgeControl(bridgeIP: ip, username: username)
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
    
    // Public methods for DMX receiver to control specific devices
    func setDevicePower(device: GoveeDevice, on: Bool) async throws {
        // Don't use DMX control to avoid feedback loop
        var control: DeviceControlProtocol?
        
        if settings.prefersLan, device.transports.contains(.lan), let ip = device.ipAddress {
            control = LANControl(deviceIP: ip)
        } else if device.transports.contains(.cloud), !settings.goveeApiKey.isEmpty {
            control = CloudControl(apiKey: settings.goveeApiKey)
        }
        
        guard let ctrl = control else { return }
        try await ctrl.setPower(device: device, on: on)
        
        if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
            deviceStore.devices[idx].isOn = on
        }
    }
    
    func setDeviceBrightness(device: GoveeDevice, value: Int) async throws {
        var control: DeviceControlProtocol?
        
        if settings.prefersLan, device.transports.contains(.lan), let ip = device.ipAddress {
            control = LANControl(deviceIP: ip)
        } else if device.transports.contains(.cloud), !settings.goveeApiKey.isEmpty {
            control = CloudControl(apiKey: settings.goveeApiKey)
        }
        
        guard let ctrl = control else { return }
        try await ctrl.setBrightness(device: device, value: value)
        
        if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
            deviceStore.devices[idx].brightness = value
        }
    }
    
    func setDeviceColor(device: GoveeDevice, color: DeviceColor) async throws {
        var control: DeviceControlProtocol?
        
        if settings.prefersLan, device.transports.contains(.lan), let ip = device.ipAddress {
            control = LANControl(deviceIP: ip)
        } else if device.transports.contains(.cloud), !settings.goveeApiKey.isEmpty {
            control = CloudControl(apiKey: settings.goveeApiKey)
        }
        
        guard let ctrl = control else { return }
        try await ctrl.setColor(device: device, color: color)
        
        if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
            deviceStore.devices[idx].color = color
        }
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

