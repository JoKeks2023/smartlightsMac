import SwiftUI
import Foundation
import Combine

// MARK: - Stores

final class SettingsStore: ObservableObject {
    private let userDefaults: UserDefaults

    @Published var goveeApiKey: String {
        didSet { try? APIKeyKeychain.save(key: goveeApiKey) }
    }
    @Published var prefersLan: Bool {
        didSet { userDefaults.set(prefersLan, forKey: "prefersLan") }
    }
    @Published var homeKitEnabled: Bool {
        didSet { userDefaults.set(homeKitEnabled, forKey: "homeKitEnabled") }
    }
    @Published var haBaseURL: String {
        didSet { userDefaults.set(haBaseURL, forKey: "haBaseURL") }
    }
    @Published var haToken: String {
        didSet { try? HomeAssistantTokenKeychain.save(token: haToken) }
    }
    @Published var dmxEnabled: Bool {
        didSet { userDefaults.set(dmxEnabled, forKey: "dmxEnabled") }
    }
    @Published var dmxProtocol: DMXProtocolType {
        didSet { userDefaults.set(dmxProtocol.rawValue, forKey: "dmxProtocol") }
    }
    // Dictionary to store Hue username (API key) per bridge IP
    @Published var hueBridgeCredentials: [String: String] = [:] {
        didSet {
            if let encoded = try? JSONEncoder().encode(hueBridgeCredentials) {
                userDefaults.set(encoded, forKey: "hueBridgeCredentials")
            }
        }
    }
    @Published var savedColorPresets: [SavedColorPreset] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(savedColorPresets) {
                userDefaults.set(encoded, forKey: "savedColorPresets")
            }
        }
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Migrate from UserDefaults to Keychain
        if let oldKey = userDefaults.string(forKey: "goveeApiKey"), !oldKey.isEmpty {
            try? APIKeyKeychain.save(key: oldKey)
            userDefaults.removeObject(forKey: "goveeApiKey")
        }

        if let oldToken = userDefaults.string(forKey: "haToken"), !oldToken.isEmpty {
            try? HomeAssistantTokenKeychain.save(token: oldToken)
            userDefaults.removeObject(forKey: "haToken")
        }
        
        self.goveeApiKey = (try? APIKeyKeychain.load()) ?? ""
        self.prefersLan = userDefaults.object(forKey: "prefersLan") as? Bool ?? true
        self.homeKitEnabled = userDefaults.object(forKey: "homeKitEnabled") as? Bool ?? false
        self.haBaseURL = userDefaults.string(forKey: "haBaseURL") ?? ""
        self.haToken = (try? HomeAssistantTokenKeychain.load()) ?? ""
        self.dmxEnabled = userDefaults.object(forKey: "dmxEnabled") as? Bool ?? false
        let protocolString = userDefaults.string(forKey: "dmxProtocol") ?? DMXProtocolType.artnet.rawValue
        self.dmxProtocol = DMXProtocolType(rawValue: protocolString) ?? .artnet
        
        // Load Hue bridge credentials
        if let data = userDefaults.data(forKey: "hueBridgeCredentials"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.hueBridgeCredentials = decoded
        }

        if let data = userDefaults.data(forKey: "savedColorPresets"),
           let decoded = try? JSONDecoder().decode([SavedColorPreset].self, from: data) {
            self.savedColorPresets = decoded
        }
    }

    func saveColorPreset(_ color: DeviceColor) {
        if let existingIndex = savedColorPresets.firstIndex(where: { $0.color == color }) {
            let existing = savedColorPresets.remove(at: existingIndex)
            savedColorPresets.insert(existing, at: 0)
            return
        }

        savedColorPresets.insert(SavedColorPreset(color: color), at: 0)
        if savedColorPresets.count > 16 {
            savedColorPresets = Array(savedColorPresets.prefix(16))
        }
    }

    func deleteColorPreset(id: String) {
        savedColorPresets.removeAll { $0.id == id }
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
    private let userDefaults: UserDefaults
    private let devicesKey = "cachedDevices"
    private let groupsKey = "deviceGroups"

    @Published var devices: [GoveeDevice] = [] {
        didSet { saveDevices() }
    }
    @Published var selectedDeviceID: String?
    @Published var selectedGroupID: String?
    @Published var groups: [DeviceGroup] = [] {
        didSet {
            saveGroups()
            // Persist groups locally to UserDefaults as a fallback when
            // CloudSyncManager (iCloud/App Groups sync) is not available at
            // compile-time for this build configuration.
            if let encoded = try? JSONEncoder().encode(groups) {
                userDefaults.set(encoded, forKey: groupsKey)
            }
        }
    }
    
    // Note: CloudSyncManager integration (iCloud / App Groups) is implemented
    // in a separate service. To avoid build-time coupling issues in some
    // configurations, DeviceStore persists locally and exposes explicit
    // async methods for cloud sync which may be implemented by the
    // CloudSyncManager when available.
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadDevices()
        loadGroups()
    }
    
    func upsert(_ device: GoveeDevice) {
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device
        } else {
            devices.append(device)
        }
    }
    
    func replaceAll(_ newDevices: [GoveeDevice]) {
        devices = newDevices
    }
    
    /// App Group container the GoveeWidget extension reads from
    /// (see GoveeWidget/GoveeWidget.swift and both targets' entitlements).
    private static let widgetSharedSuiteName = "group.com.govee.mac"

    private func saveDevices() {
        // Persist devices to UserDefaults as a local shared cache. When the
        // CloudSyncManager is available it can read/write the same keys.
        guard let encoded = try? JSONEncoder().encode(devices) else { return }
        userDefaults.set(encoded, forKey: devicesKey)

        // Also mirror to the App Group suite so the widget extension (a
        // separate process) can read the current device list. Best-effort:
        // the suite may not exist in unit tests or non-sandboxed contexts.
        UserDefaults(suiteName: Self.widgetSharedSuiteName)?.set(encoded, forKey: devicesKey)
    }

    private func loadDevices() {
        if let data = userDefaults.data(forKey: devicesKey),
           let decoded = try? JSONDecoder().decode([GoveeDevice].self, from: data) {
            devices = decoded
        }
    }
    
    /// Sync devices and groups to iCloud (optional)
    func syncToCloud() async throws {
        throw SmartLightError.notImplemented("Cloud sync is not available in this build")
    }
    
    /// Load devices from iCloud (optional)
    func loadFromCloud() async throws {
        throw SmartLightError.notImplemented("Cloud load is not available in this build")
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
            userDefaults.set(encoded, forKey: groupsKey)
        }
    }
    
    private func loadGroups() {
        if let data = userDefaults.data(forKey: groupsKey),
           let decoded = try? JSONDecoder().decode([DeviceGroup].self, from: data) {
            groups = decoded
        }
    }
}
