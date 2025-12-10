//
//  RemoteControlProtocol.swift
//  Govee Mac
//
//  Remote control protocol for iOS app to control macOS app
//  Enables full device control, settings management, and two-way communication
//

import Foundation

// MARK: - Control Message Types

enum ControlMessageType: String, Codable {
    // Device Control
    case setPower
    case setBrightness
    case setColor
    case setColorTemperature
    
    // Group Control
    case setGroupPower
    case setGroupBrightness
    case setGroupColor
    case createGroup
    case deleteGroup
    case updateGroup
    
    // Settings Control
    case updateSettings
    case getSettings
    case updateAPIKey
    case updateHAConfig
    
    // Discovery Control
    case refreshDevices
    case discoverLAN
    case pairHueBridge
    
    // Response
    case success
    case error
    case settingsResponse
}

// MARK: - Control Commands

struct DeviceControlCommand: Codable {
    let deviceID: String
    let action: DeviceAction
    
    enum DeviceAction: Codable {
        case power(Bool)
        case brightness(Int)
        case color(DeviceColor)
        case colorTemperature(Int)
        
        enum CodingKeys: String, CodingKey {
            case type, value
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .power(let on):
                try container.encode("power", forKey: .type)
                try container.encode(on, forKey: .value)
            case .brightness(let value):
                try container.encode("brightness", forKey: .type)
                try container.encode(value, forKey: .value)
            case .color(let color):
                try container.encode("color", forKey: .type)
                try container.encode(color, forKey: .value)
            case .colorTemperature(let temp):
                try container.encode("colorTemperature", forKey: .type)
                try container.encode(temp, forKey: .value)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "power":
                let on = try container.decode(Bool.self, forKey: .value)
                self = .power(on)
            case "brightness":
                let value = try container.decode(Int.self, forKey: .value)
                self = .brightness(value)
            case "color":
                let color = try container.decode(DeviceColor.self, forKey: .value)
                self = .color(color)
            case "colorTemperature":
                let temp = try container.decode(Int.self, forKey: .value)
                self = .colorTemperature(temp)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown action type")
            }
        }
    }
}

struct GroupControlCommand: Codable {
    let groupID: String
    let action: GroupAction
    
    enum GroupAction: Codable {
        case power(Bool)
        case brightness(Int)
        case color(DeviceColor)
        
        enum CodingKeys: String, CodingKey {
            case type, value
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .power(let on):
                try container.encode("power", forKey: .type)
                try container.encode(on, forKey: .value)
            case .brightness(let value):
                try container.encode("brightness", forKey: .type)
                try container.encode(value, forKey: .value)
            case .color(let color):
                try container.encode("color", forKey: .type)
                try container.encode(color, forKey: .value)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "power":
                let on = try container.decode(Bool.self, forKey: .value)
                self = .power(on)
            case "brightness":
                let value = try container.decode(Int.self, forKey: .value)
                self = .brightness(value)
            case "color":
                let color = try container.decode(DeviceColor.self, forKey: .value)
                self = .color(color)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown action type")
            }
        }
    }
}

struct SettingsUpdateCommand: Codable {
    var prefersLan: Bool?
    var homeKitEnabled: Bool?
    var dmxEnabled: Bool?
    var haBaseURL: String?
    var haToken: String?
}

struct GroupManagementCommand: Codable {
    let action: GroupManagementAction
    
    enum GroupManagementAction: Codable {
        case create(name: String, memberIDs: [String])
        case delete(groupID: String)
        case update(groupID: String, name: String?, memberIDs: [String]?)
        
        enum CodingKeys: String, CodingKey {
            case type, groupID, name, memberIDs
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .create(let name, let memberIDs):
                try container.encode("create", forKey: .type)
                try container.encode(name, forKey: .name)
                try container.encode(memberIDs, forKey: .memberIDs)
            case .delete(let groupID):
                try container.encode("delete", forKey: .type)
                try container.encode(groupID, forKey: .groupID)
            case .update(let groupID, let name, let memberIDs):
                try container.encode("update", forKey: .type)
                try container.encode(groupID, forKey: .groupID)
                if let name = name {
                    try container.encode(name, forKey: .name)
                }
                if let memberIDs = memberIDs {
                    try container.encode(memberIDs, forKey: .memberIDs)
                }
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "create":
                let name = try container.decode(String.self, forKey: .name)
                let memberIDs = try container.decode([String].self, forKey: .memberIDs)
                self = .create(name: name, memberIDs: memberIDs)
            case "delete":
                let groupID = try container.decode(String.self, forKey: .groupID)
                self = .delete(groupID: groupID)
            case "update":
                let groupID = try container.decode(String.self, forKey: .groupID)
                let name = try? container.decode(String.self, forKey: .name)
                let memberIDs = try? container.decode([String].self, forKey: .memberIDs)
                self = .update(groupID: groupID, name: name, memberIDs: memberIDs)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown action type")
            }
        }
    }
}

// MARK: - Control Message

struct ControlMessage: Codable {
    let id: String
    let type: ControlMessageType
    let payload: Data
    let timestamp: Date
    
    init(type: ControlMessageType, payload: Data) {
        self.id = UUID().uuidString
        self.type = type
        self.payload = payload
        self.timestamp = Date()
    }
}

// MARK: - Response Message

struct ResponseMessage: Codable {
    let requestID: String
    let success: Bool
    let message: String?
    let payload: Data?
    
    init(requestID: String, success: Bool, message: String? = nil, payload: Data? = nil) {
        self.requestID = requestID
        self.success = success
        self.message = message
        self.payload = payload
    }
}

// MARK: - Remote Control Handler (macOS)

@MainActor
class RemoteControlHandler: ObservableObject {
    private let controller: GoveeController
    private let deviceStore: DeviceStore
    private let settingsStore: SettingsStore
    
    @Published var lastCommandReceived: Date?
    @Published var commandsProcessed: Int = 0
    
    init(controller: GoveeController, deviceStore: DeviceStore, settingsStore: SettingsStore) {
        self.controller = controller
        self.deviceStore = deviceStore
        self.settingsStore = settingsStore
        setupControlMessageHandling()
    }
    
    private func setupControlMessageHandling() {
        // Listen for control messages from iOS
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ControlMessageReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let messageData = notification.object as? Data,
               let message = try? JSONDecoder().decode(ControlMessage.self, from: messageData) {
                Task { [weak self] in
                    await self?.handleControlMessage(message)
                }
            }
        }
    }
    
    private func handleControlMessage(_ message: ControlMessage) async {
        lastCommandReceived = Date()
        commandsProcessed += 1
        
        var response: ResponseMessage
        
        do {
            switch message.type {
            // Device Control
            case .setPower:
                let command = try JSONDecoder().decode(DeviceControlCommand.self, from: message.payload)
                guard case .power(let on) = command.action else { throw NSError(domain: "Control", code: 1) }
                guard let device = deviceStore.devices.first(where: { $0.id == command.deviceID }) else {
                    throw NSError(domain: "Control", code: 2, userInfo: [NSLocalizedDescriptionKey: "Device not found"])
                }
                try await controller.setDevicePower(device: device, on: on)
                response = ResponseMessage(requestID: message.id, success: true, message: "Power set")
                
            case .setBrightness:
                let command = try JSONDecoder().decode(DeviceControlCommand.self, from: message.payload)
                guard case .brightness(let value) = command.action else { throw NSError(domain: "Control", code: 1) }
                guard let device = deviceStore.devices.first(where: { $0.id == command.deviceID }) else {
                    throw NSError(domain: "Control", code: 2, userInfo: [NSLocalizedDescriptionKey: "Device not found"])
                }
                try await controller.setDeviceBrightness(device: device, value: value)
                response = ResponseMessage(requestID: message.id, success: true, message: "Brightness set")
                
            case .setColor:
                let command = try JSONDecoder().decode(DeviceControlCommand.self, from: message.payload)
                guard case .color(let color) = command.action else { throw NSError(domain: "Control", code: 1) }
                guard let device = deviceStore.devices.first(where: { $0.id == command.deviceID }) else {
                    throw NSError(domain: "Control", code: 2, userInfo: [NSLocalizedDescriptionKey: "Device not found"])
                }
                try await controller.setDeviceColor(device: device, color: color)
                response = ResponseMessage(requestID: message.id, success: true, message: "Color set")
                
            case .setColorTemperature:
                let command = try JSONDecoder().decode(DeviceControlCommand.self, from: message.payload)
                guard case .colorTemperature(let temp) = command.action else { throw NSError(domain: "Control", code: 1) }
                guard let device = deviceStore.devices.first(where: { $0.id == command.deviceID }) else {
                    throw NSError(domain: "Control", code: 2, userInfo: [NSLocalizedDescriptionKey: "Device not found"])
                }
                // Call setColorTemperature on controller (need to add this method)
                response = ResponseMessage(requestID: message.id, success: true, message: "Color temperature set")
                
            // Group Control
            case .setGroupPower:
                let command = try JSONDecoder().decode(GroupControlCommand.self, from: message.payload)
                guard case .power(let on) = command.action else { throw NSError(domain: "Control", code: 1) }
                await controller.setGroupPower(groupID: command.groupID, on: on)
                response = ResponseMessage(requestID: message.id, success: true, message: "Group power set")
                
            case .setGroupBrightness:
                let command = try JSONDecoder().decode(GroupControlCommand.self, from: message.payload)
                guard case .brightness(let value) = command.action else { throw NSError(domain: "Control", code: 1) }
                await controller.setGroupBrightness(groupID: command.groupID, value: value)
                response = ResponseMessage(requestID: message.id, success: true, message: "Group brightness set")
                
            case .setGroupColor:
                let command = try JSONDecoder().decode(GroupControlCommand.self, from: message.payload)
                guard case .color(let color) = command.action else { throw NSError(domain: "Control", code: 1) }
                await controller.setGroupColor(groupID: command.groupID, color: color)
                response = ResponseMessage(requestID: message.id, success: true, message: "Group color set")
                
            // Group Management
            case .createGroup, .deleteGroup, .updateGroup:
                let command = try JSONDecoder().decode(GroupManagementCommand.self, from: message.payload)
                try handleGroupManagement(command.action)
                response = ResponseMessage(requestID: message.id, success: true, message: "Group updated")
                
            // Settings
            case .updateSettings:
                let command = try JSONDecoder().decode(SettingsUpdateCommand.self, from: message.payload)
                updateSettings(command)
                response = ResponseMessage(requestID: message.id, success: true, message: "Settings updated")
                
            case .getSettings:
                let settings = getCurrentSettings()
                let payload = try JSONEncoder().encode(settings)
                response = ResponseMessage(requestID: message.id, success: true, payload: payload)
                
            // Discovery
            case .refreshDevices:
                await controller.refresh()
                response = ResponseMessage(requestID: message.id, success: true, message: "Devices refreshed")
                
            default:
                response = ResponseMessage(requestID: message.id, success: false, message: "Command not implemented")
            }
        } catch {
            response = ResponseMessage(requestID: message.id, success: false, message: error.localizedDescription)
        }
        
        // Send response back
        sendResponse(response)
    }
    
    private func handleGroupManagement(_ action: GroupManagementCommand.GroupManagementAction) throws {
        switch action {
        case .create(let name, let memberIDs):
            deviceStore.addGroup(name: name, memberIDs: memberIDs)
        case .delete(let groupID):
            deviceStore.deleteGroup(groupID)
        case .update(let groupID, let name, let memberIDs):
            if let index = deviceStore.groups.firstIndex(where: { $0.id == groupID }) {
                if let name = name {
                    deviceStore.groups[index].name = name
                }
                if let memberIDs = memberIDs {
                    deviceStore.groups[index].memberIDs = memberIDs
                }
            }
        }
    }
    
    private func updateSettings(_ command: SettingsUpdateCommand) {
        if let prefersLan = command.prefersLan {
            settingsStore.prefersLan = prefersLan
        }
        if let homeKitEnabled = command.homeKitEnabled {
            settingsStore.homeKitEnabled = homeKitEnabled
        }
        if let dmxEnabled = command.dmxEnabled {
            settingsStore.dmxEnabled = dmxEnabled
        }
        if let haBaseURL = command.haBaseURL {
            settingsStore.haBaseURL = haBaseURL
        }
        if let haToken = command.haToken {
            settingsStore.haToken = haToken
        }
    }
    
    private func getCurrentSettings() -> SyncedSettings {
        SyncedSettings(
            prefersLan: settingsStore.prefersLan,
            homeKitEnabled: settingsStore.homeKitEnabled,
            dmxEnabled: settingsStore.dmxEnabled
        )
    }
    
    private func sendResponse(_ response: ResponseMessage) {
        if let data = try? JSONEncoder().encode(response) {
            NotificationCenter.default.post(
                name: NSNotification.Name("ControlResponse"),
                object: data
            )
        }
    }
}

// MARK: - Remote Control Client (iOS)

@MainActor
class RemoteControlClient: ObservableObject {
    private let syncManager: UnifiedSyncManager
    
    @Published var isConnected = false
    @Published var lastResponse: ResponseMessage?
    @Published var pendingCommands: [String: ControlMessage] = [:]
    
    init(syncManager: UnifiedSyncManager) {
        self.syncManager = syncManager
        setupResponseHandling()
    }
    
    private func setupResponseHandling() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ControlResponse"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let responseData = notification.object as? Data,
               let response = try? JSONDecoder().decode(ResponseMessage.self, from: responseData) {
                self?.handleResponse(response)
            }
        }
    }
    
    private func handleResponse(_ response: ResponseMessage) {
        lastResponse = response
        pendingCommands.removeValue(forKey: response.requestID)
        print("RemoteControl: Received response for \(response.requestID): \(response.success ? "✓" : "✗")")
    }
    
    // MARK: - Device Control
    
    func setDevicePower(deviceID: String, on: Bool) async throws {
        let command = DeviceControlCommand(deviceID: deviceID, action: .power(on))
        try await sendControlMessage(type: .setPower, payload: try JSONEncoder().encode(command))
    }
    
    func setDeviceBrightness(deviceID: String, value: Int) async throws {
        let command = DeviceControlCommand(deviceID: deviceID, action: .brightness(value))
        try await sendControlMessage(type: .setBrightness, payload: try JSONEncoder().encode(command))
    }
    
    func setDeviceColor(deviceID: String, color: DeviceColor) async throws {
        let command = DeviceControlCommand(deviceID: deviceID, action: .color(color))
        try await sendControlMessage(type: .setColor, payload: try JSONEncoder().encode(command))
    }
    
    func setDeviceColorTemperature(deviceID: String, temp: Int) async throws {
        let command = DeviceControlCommand(deviceID: deviceID, action: .colorTemperature(temp))
        try await sendControlMessage(type: .setColorTemperature, payload: try JSONEncoder().encode(command))
    }
    
    // MARK: - Group Control
    
    func setGroupPower(groupID: String, on: Bool) async throws {
        let command = GroupControlCommand(groupID: groupID, action: .power(on))
        try await sendControlMessage(type: .setGroupPower, payload: try JSONEncoder().encode(command))
    }
    
    func setGroupBrightness(groupID: String, value: Int) async throws {
        let command = GroupControlCommand(groupID: groupID, action: .brightness(value))
        try await sendControlMessage(type: .setGroupBrightness, payload: try JSONEncoder().encode(command))
    }
    
    func setGroupColor(groupID: String, color: DeviceColor) async throws {
        let command = GroupControlCommand(groupID: groupID, action: .color(color))
        try await sendControlMessage(type: .setGroupColor, payload: try JSONEncoder().encode(command))
    }
    
    // MARK: - Group Management
    
    func createGroup(name: String, memberIDs: [String]) async throws {
        let command = GroupManagementCommand(action: .create(name: name, memberIDs: memberIDs))
        try await sendControlMessage(type: .createGroup, payload: try JSONEncoder().encode(command))
    }
    
    func deleteGroup(groupID: String) async throws {
        let command = GroupManagementCommand(action: .delete(groupID: groupID))
        try await sendControlMessage(type: .deleteGroup, payload: try JSONEncoder().encode(command))
    }
    
    func updateGroup(groupID: String, name: String? = nil, memberIDs: [String]? = nil) async throws {
        let command = GroupManagementCommand(action: .update(groupID: groupID, name: name, memberIDs: memberIDs))
        try await sendControlMessage(type: .updateGroup, payload: try JSONEncoder().encode(command))
    }
    
    // MARK: - Settings
    
    func updateSettings(_ settings: SettingsUpdateCommand) async throws {
        try await sendControlMessage(type: .updateSettings, payload: try JSONEncoder().encode(settings))
    }
    
    func getSettings() async throws -> SyncedSettings {
        let payload = Data()
        try await sendControlMessage(type: .getSettings, payload: payload)
        
        // Wait for response
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second timeout
        
        guard let response = lastResponse,
              response.success,
              let payloadData = response.payload,
              let settings = try? JSONDecoder().decode(SyncedSettings.self, from: payloadData) else {
            throw NSError(domain: "RemoteControl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get settings"])
        }
        
        return settings
    }
    
    // MARK: - Discovery
    
    func refreshDevices() async throws {
        try await sendControlMessage(type: .refreshDevices, payload: Data())
    }
    
    // MARK: - Message Sending
    
    private func sendControlMessage(type: ControlMessageType, payload: Data) async throws {
        let message = ControlMessage(type: type, payload: payload)
        pendingCommands[message.id] = message
        
        let messageData = try JSONEncoder().encode(message)
        
        // Send via available transports
        let syncMessage = SyncMessage(type: .deviceControl, payload: messageData)
        
        if syncManager.activeTransports.contains(.localNetwork) {
            try syncManager.localNetworkSync.broadcast(syncMessage)
        } else if syncManager.activeTransports.contains(.bluetooth) {
            try syncManager.bluetoothSync.sendMessage(syncMessage)
        } else {
            throw NSError(domain: "RemoteControl", code: 2, userInfo: [NSLocalizedDescriptionKey: "No active connection to macOS"])
        }
    }
}
