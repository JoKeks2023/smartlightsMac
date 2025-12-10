//
//  CloudSyncManager.swift
//  Govee Mac
//
//  Cross-platform sync manager for macOS and iOS companion app
//  Uses CloudKit for iCloud sync and App Groups for local data sharing
//

import Foundation
import CloudKit
import Combine

// MARK: - Sync Configuration

struct SyncConfiguration {
    static let appGroupIdentifier = "group.com.govee.mac"
    static let cloudContainerIdentifier = "iCloud.com.govee.smartlights"
    
    // UserDefaults keys
    static let devicesKey = "cachedDevices"
    static let groupsKey = "deviceGroups"
    static let settingsKey = "syncedSettings"
    static let lastSyncKey = "lastSyncTimestamp"
}

// MARK: - Syncable Models

/// Protocol for models that can be synced across devices
protocol SyncableModel: Codable {
    var syncID: String { get }
    var lastModified: Date { get set }
}

/// Wrapper for synced settings
struct SyncedSettings: Codable {
    var prefersLan: Bool
    var homeKitEnabled: Bool
    var dmxEnabled: Bool
    var lastModified: Date
    
    init(prefersLan: Bool = true, homeKitEnabled: Bool = false, dmxEnabled: Bool = false) {
        self.prefersLan = prefersLan
        self.homeKitEnabled = homeKitEnabled
        self.dmxEnabled = dmxEnabled
        self.lastModified = Date()
    }
}

// MARK: - Sync Manager

@MainActor
class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let container: CKContainer
    private let database: CKDatabase
    private let sharedDefaults: UserDefaults?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize CloudKit container
        self.container = CKContainer(identifier: SyncConfiguration.cloudContainerIdentifier)
        self.database = container.privateCloudDatabase
        
        // Initialize App Groups shared storage
        self.sharedDefaults = UserDefaults(suiteName: SyncConfiguration.appGroupIdentifier)
        
        // Load last sync date
        if let timestamp = sharedDefaults?.double(forKey: SyncConfiguration.lastSyncKey), timestamp > 0 {
            self.lastSyncDate = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    // MARK: - App Groups Sync (Local)
    
    /// Save devices to shared App Groups container (for widget and iOS app access)
    func saveDevicesToAppGroups(_ devices: [GoveeDevice]) {
        guard let sharedDefaults = sharedDefaults else { return }
        
        if let encoded = try? JSONEncoder().encode(devices) {
            sharedDefaults.set(encoded, forKey: SyncConfiguration.devicesKey)
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: SyncConfiguration.lastSyncKey)
            lastSyncDate = Date()
        }
    }
    
    /// Load devices from shared App Groups container
    func loadDevicesFromAppGroups() -> [GoveeDevice]? {
        guard let sharedDefaults = sharedDefaults,
              let data = sharedDefaults.data(forKey: SyncConfiguration.devicesKey),
              let devices = try? JSONDecoder().decode([GoveeDevice].self, from: data) else {
            return nil
        }
        return devices
    }
    
    /// Save groups to shared App Groups container
    func saveGroupsToAppGroups(_ groups: [DeviceGroup]) {
        guard let sharedDefaults = sharedDefaults else { return }
        
        if let encoded = try? JSONEncoder().encode(groups) {
            sharedDefaults.set(encoded, forKey: SyncConfiguration.groupsKey)
        }
    }
    
    /// Load groups from shared App Groups container
    func loadGroupsFromAppGroups() -> [DeviceGroup]? {
        guard let sharedDefaults = sharedDefaults,
              let data = sharedDefaults.data(forKey: SyncConfiguration.groupsKey),
              let groups = try? JSONDecoder().decode([DeviceGroup].self, from: data) else {
            return nil
        }
        return groups
    }
    
    /// Save settings to shared App Groups container
    func saveSettingsToAppGroups(_ settings: SyncedSettings) {
        guard let sharedDefaults = sharedDefaults else { return }
        
        if let encoded = try? JSONEncoder().encode(settings) {
            sharedDefaults.set(encoded, forKey: SyncConfiguration.settingsKey)
        }
    }
    
    /// Load settings from shared App Groups container
    func loadSettingsFromAppGroups() -> SyncedSettings? {
        guard let sharedDefaults = sharedDefaults,
              let data = sharedDefaults.data(forKey: SyncConfiguration.settingsKey),
              let settings = try? JSONDecoder().decode(SyncedSettings.self, from: data) else {
            return nil
        }
        return settings
    }
    
    // MARK: - CloudKit Sync (Cross-device)
    
    /// Check if user is logged into iCloud
    func checkCloudKitAvailability() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            syncError = error
            return false
        }
    }
    
    /// Sync devices to CloudKit
    func syncDevicesToCloud(_ devices: [GoveeDevice]) async throws {
        guard await checkCloudKitAvailability() else {
            throw NSError(domain: "CloudSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"])
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        // Convert devices to CloudKit records
        var records: [CKRecord] = []
        for device in devices {
            let recordID = CKRecord.ID(recordName: "device-\(device.id)")
            let record = CKRecord(recordType: "Device", recordID: recordID)
            
            record["deviceID"] = device.id
            record["name"] = device.name
            record["model"] = device.model
            record["online"] = device.online ? 1 : 0
            record["supportsBrightness"] = device.supportsBrightness ? 1 : 0
            record["supportsColor"] = device.supportsColor ? 1 : 0
            record["supportsColorTemperature"] = device.supportsColorTemperature ? 1 : 0
            record["lastModified"] = Date()
            
            records.append(record)
        }
        
        // Save to CloudKit in batches
        let batchSize = 100
        for batch in stride(from: 0, to: records.count, by: batchSize) {
            let end = min(batch + batchSize, records.count)
            let batchRecords = Array(records[batch..<end])
            
            try await database.modifyRecords(saving: batchRecords, deleting: [])
        }
        
        lastSyncDate = Date()
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: SyncConfiguration.lastSyncKey)
    }
    
    /// Fetch devices from CloudKit
    func fetchDevicesFromCloud() async throws -> [GoveeDevice] {
        guard await checkCloudKitAvailability() else {
            throw NSError(domain: "CloudSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"])
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let query = CKQuery(recordType: "Device", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]
        
        var devices: [GoveeDevice] = []
        
        // Fetch all matching records
        let (results, _) = try await database.records(matching: query)
        
        for (_, result) in results {
            switch result {
            case .success(let record):
                // Parse CloudKit record to GoveeDevice
                if let deviceID = record["deviceID"] as? String,
                   let name = record["name"] as? String {
                    let device = GoveeDevice(
                        id: deviceID,
                        name: name,
                        model: record["model"] as? String,
                        ipAddress: nil,
                        online: (record["online"] as? Int) == 1,
                        supportsBrightness: (record["supportsBrightness"] as? Int) == 1,
                        supportsColor: (record["supportsColor"] as? Int) == 1,
                        supportsColorTemperature: (record["supportsColorTemperature"] as? Int) == 1,
                        transports: [.cloud],
                        isOn: nil,
                        brightness: nil,
                        color: nil,
                        colorTemperature: nil
                    )
                    devices.append(device)
                }
            case .failure(let error):
                print("Failed to fetch device record: \(error)")
            }
        }
        
        return devices
    }
    
    /// Sync groups to CloudKit
    func syncGroupsToCloud(_ groups: [DeviceGroup]) async throws {
        guard await checkCloudKitAvailability() else {
            throw NSError(domain: "CloudSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"])
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        var records: [CKRecord] = []
        for group in groups {
            let recordID = CKRecord.ID(recordName: "group-\(group.id)")
            let record = CKRecord(recordType: "DeviceGroup", recordID: recordID)
            
            record["groupID"] = group.id
            record["name"] = group.name
            record["memberIDs"] = group.memberIDs
            record["lastModified"] = Date()
            
            records.append(record)
        }
        
        try await database.modifyRecords(saving: records, deleting: [])
        
        lastSyncDate = Date()
    }
    
    /// Fetch groups from CloudKit
    func fetchGroupsFromCloud() async throws -> [DeviceGroup] {
        guard await checkCloudKitAvailability() else {
            throw NSError(domain: "CloudSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"])
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let query = CKQuery(recordType: "DeviceGroup", predicate: NSPredicate(value: true))
        let (results, _) = try await database.records(matching: query)
        
        var groups: [DeviceGroup] = []
        
        for (_, result) in results {
            switch result {
            case .success(let record):
                if let groupID = record["groupID"] as? String,
                   let name = record["name"] as? String,
                   let memberIDs = record["memberIDs"] as? [String] {
                    let group = DeviceGroup(id: groupID, name: name, memberIDs: memberIDs)
                    groups.append(group)
                }
            case .failure(let error):
                print("Failed to fetch group record: \(error)")
            }
        }
        
        return groups
    }
    
    // MARK: - Convenience Methods
    
    /// Full sync: Upload local data to cloud and download cloud data
    func performFullSync(devices: [GoveeDevice], groups: [DeviceGroup]) async throws {
        // Upload to cloud
        try await syncDevicesToCloud(devices)
        try await syncGroupsToCloud(groups)
        
        // Also save to App Groups for immediate local access
        saveDevicesToAppGroups(devices)
        saveGroupsToAppGroups(groups)
    }
    
    /// Subscribe to CloudKit changes (for real-time sync)
    func subscribeToCloudChanges() async throws {
        let subscription = CKQuerySubscription(
            recordType: "Device",
            predicate: NSPredicate(value: true),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        try await database.save(subscription)
    }
}

// MARK: - Extension for GoveeDevice

extension GoveeDevice: SyncableModel {
    var syncID: String { id }
    var lastModified: Date {
        get { Date() }
        set { }
    }
}

// MARK: - Extension for DeviceGroup

extension DeviceGroup: SyncableModel {
    var syncID: String { id }
    var lastModified: Date {
        get { Date() }
        set { }
    }
}
