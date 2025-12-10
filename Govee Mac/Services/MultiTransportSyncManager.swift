//
//  MultiTransportSyncManager.swift
//  Govee Mac
//
//  Multi-transport sync supporting CloudKit, Local Network (Bonjour), and Bluetooth
//  Enables seamless sync between macOS and iOS companion app
//

import Foundation
import Network
import MultipeerConnectivity
import Combine

// MARK: - Sync Transport Protocol

enum SyncTransport: String, Codable {
    case cloud        // CloudKit - Internet-based, cross-location
    case localNetwork // Bonjour - Same WiFi network
    case bluetooth    // Bluetooth LE - Close proximity
    case appGroups    // App Groups - Same device only
}

protocol SyncTransportProtocol {
    func sendDevices(_ devices: [GoveeDevice]) async throws
    func sendGroups(_ groups: [DeviceGroup]) async throws
    func receiveDevices() async throws -> [GoveeDevice]
    func receiveGroups() async throws -> [DeviceGroup]
}

// MARK: - Sync Message

struct SyncMessage: Codable {
    enum MessageType: String, Codable {
        case devicesUpdate
        case groupsUpdate
        case settingsUpdate
        case deviceControl
        case ping
    }
    
    let id: String
    let type: MessageType
    let timestamp: Date
    let payload: Data
    
    init(type: MessageType, payload: Data) {
        self.id = UUID().uuidString
        self.type = type
        self.timestamp = Date()
        self.payload = payload
    }
}

// MARK: - Local Network Sync (Bonjour)

@MainActor
class LocalNetworkSync: NSObject, ObservableObject {
    private let serviceType = "_smartlights._tcp"
    private let serviceName = "SmartLights Sync"
    
    @Published var isAdvertising = false
    @Published var discoveredPeers: [NWBrowser.Result] = []
    @Published var connectedPeers: [NWConnection] = []
    
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]
    
    private var messageHandlers: [(SyncMessage) -> Void] = []
    
    // MARK: - Server (macOS)
    
    func startAdvertising() throws {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        
        // Create listener
        listener = try NWListener(using: parameters)
        
        listener?.service = NWListener.Service(
            name: serviceName,
            type: serviceType
        )
        
        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.handleNewConnection(connection)
            }
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.isAdvertising = true
                    print("LocalNetworkSync: Advertising on local network")
                case .failed(let error):
                    print("LocalNetworkSync: Failed to advertise: \(error)")
                    self?.isAdvertising = false
                case .cancelled:
                    self?.isAdvertising = false
                default:
                    break
                }
            }
        }
        
        listener?.start(queue: .main)
    }
    
    func stopAdvertising() {
        listener?.cancel()
        listener = nil
        isAdvertising = false
    }
    
    // MARK: - Client (iOS)
    
    func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)
        
        browser?.stateUpdateHandler = { state in
            print("LocalNetworkSync: Browser state: \(state)")
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                self?.discoveredPeers = Array(results)
                print("LocalNetworkSync: Discovered \(results.count) peers")
            }
        }
        
        browser?.start(queue: .main)
    }
    
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }
    
    func connect(to peer: NWBrowser.Result) {
        guard case .service(let name, let type, let domain, _) = peer.endpoint else {
            return
        }
        
        let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        
        let connection = NWConnection(to: endpoint, using: parameters)
        handleNewConnection(connection)
        connection.start(queue: .main)
    }
    
    // MARK: - Connection Handling
    
    private func handleNewConnection(_ connection: NWConnection) {
        let connectionID = UUID().uuidString
        connections[connectionID] = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    if let self = self {
                        self.connectedPeers.append(connection)
                        print("LocalNetworkSync: Connected to peer")
                    }
                case .failed(let error):
                    print("LocalNetworkSync: Connection failed: \(error)")
                    self?.connections.removeValue(forKey: connectionID)
                case .cancelled:
                    self?.connections.removeValue(forKey: connectionID)
                    if let self = self {
                        self.connectedPeers.removeAll { $0 === connection }
                    }
                default:
                    break
                }
            }
        }
        
        connection.start(queue: .main)
        receiveMessage(on: connection)
    }
    
    // MARK: - Messaging
    
    func sendMessage(_ message: SyncMessage, to connection: NWConnection) throws {
        let data = try JSONEncoder().encode(message)
        let lengthData = withUnsafeBytes(of: UInt32(data.count).bigEndian) { Data($0) }
        
        connection.send(content: lengthData + data, completion: .contentProcessed { error in
            if let error = error {
                print("LocalNetworkSync: Send error: \(error)")
            }
        })
    }
    
    func broadcast(_ message: SyncMessage) throws {
        for connection in connectedPeers {
            try sendMessage(message, to: connection)
        }
    }
    
    private func receiveMessage(on connection: NWConnection) {
        // First receive 4 bytes for message length
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let data = data, !isComplete, error == nil else {
                return
            }
            
            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            // Then receive the actual message
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { messageData, _, _, error in
                guard let messageData = messageData, error == nil else {
                    return
                }
                
                if let message = try? JSONDecoder().decode(SyncMessage.self, from: messageData) {
                    Task { @MainActor [weak self] in
                        self?.messageHandlers.forEach { $0(message) }
                    }
                }
                
                // Continue receiving
                Task { @MainActor [weak self] in
                    self?.receiveMessage(on: connection)
                }
            }
        }
    }
    
    func onMessage(_ handler: @escaping (SyncMessage) -> Void) {
        messageHandlers.append(handler)
    }
    
    deinit {
        stopAdvertising()
        stopBrowsing()
    }
}

// MARK: - Bluetooth Sync (Multipeer Connectivity)

@MainActor
class BluetoothSync: NSObject, ObservableObject {
    private let serviceType = "smartlights-bt"
    private let myPeerID: MCPeerID
    
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var session: MCSession?
    
    private var messageHandlers: [(SyncMessage) -> Void] = []
    
    override init() {
        // Use device name or app identifier
        let deviceName = ProcessInfo.processInfo.hostName
        self.myPeerID = MCPeerID(displayName: deviceName)
        super.init()
        
        // Create session
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
    }
    
    // MARK: - Advertising (macOS or iOS can advertise)
    
    func startAdvertising() {
        guard let session = session else { return }
        
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        isAdvertising = true
        
        print("BluetoothSync: Started advertising")
    }
    
    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        isAdvertising = false
    }
    
    // MARK: - Browsing (iOS or macOS can browse)
    
    func startBrowsing() {
        guard let session = session else { return }
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        isBrowsing = true
        
        print("BluetoothSync: Started browsing")
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        isBrowsing = false
    }
    
    // MARK: - Messaging
    
    func sendMessage(_ message: SyncMessage) throws {
        guard let session = session, !session.connectedPeers.isEmpty else {
            throw NSError(domain: "BluetoothSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "No connected peers"])
        }
        
        let data = try JSONEncoder().encode(message)
        try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        print("BluetoothSync: Sent message to \(session.connectedPeers.count) peers")
    }
    
    func onMessage(_ handler: @escaping (SyncMessage) -> Void) {
        messageHandlers.append(handler)
    }
    
    deinit {
        stopAdvertising()
        stopBrowsing()
        session?.disconnect()
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension BluetoothSync: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            // Auto-accept invitations
            invitationHandler(true, self.session)
            print("BluetoothSync: Accepted invitation from \(peerID.displayName)")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension BluetoothSync: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Task { @MainActor in
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
                print("BluetoothSync: Found peer \(peerID.displayName)")
            }
            
            // Auto-invite found peers
            if let session = self.session {
                browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
            }
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeers.removeAll { $0 == peerID }
            print("BluetoothSync: Lost peer \(peerID.displayName)")
        }
    }
}

// MARK: - MCSessionDelegate

extension BluetoothSync: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                print("BluetoothSync: Connected to \(peerID.displayName)")
            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                print("BluetoothSync: Disconnected from \(peerID.displayName)")
            case .connecting:
                print("BluetoothSync: Connecting to \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = try? JSONDecoder().decode(SyncMessage.self, from: data) {
            Task { @MainActor in
                self.messageHandlers.forEach { $0(message) }
                print("BluetoothSync: Received message from \(peerID.displayName)")
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used
    }
    
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }
    
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }
}

// MARK: - Unified Sync Manager

@MainActor
class UnifiedSyncManager: ObservableObject {
    static let shared = UnifiedSyncManager()
    
    @Published var activeTransports: Set<SyncTransport> = []
    @Published var preferredTransport: SyncTransport = .cloud
    
    let cloudSync = CloudSyncManager.shared
    let localNetworkSync = LocalNetworkSync()
    let bluetoothSync = BluetoothSync()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupMessageHandlers()
    }
    
    // MARK: - Transport Management
    
    func enableTransport(_ transport: SyncTransport, isServer: Bool = true) throws {
        switch transport {
        case .cloud:
            // Cloud is always available, just mark as active
            activeTransports.insert(.cloud)
            
        case .localNetwork:
            if isServer {
                try localNetworkSync.startAdvertising()
            } else {
                localNetworkSync.startBrowsing()
            }
            activeTransports.insert(.localNetwork)
            
        case .bluetooth:
            if isServer {
                bluetoothSync.startAdvertising()
            } else {
                bluetoothSync.startBrowsing()
            }
            activeTransports.insert(.bluetooth)
            
        case .appGroups:
            // App Groups is always available
            activeTransports.insert(.appGroups)
        }
    }
    
    func disableTransport(_ transport: SyncTransport) {
        switch transport {
        case .cloud:
            activeTransports.remove(.cloud)
            
        case .localNetwork:
            localNetworkSync.stopAdvertising()
            localNetworkSync.stopBrowsing()
            activeTransports.remove(.localNetwork)
            
        case .bluetooth:
            bluetoothSync.stopAdvertising()
            bluetoothSync.stopBrowsing()
            activeTransports.remove(.bluetooth)
            
        case .appGroups:
            activeTransports.remove(.appGroups)
        }
    }
    
    // MARK: - Message Handling
    
    private func setupMessageHandlers() {
        // Handle local network messages
        localNetworkSync.onMessage { [weak self] message in
            Task { @MainActor [weak self] in
                await self?.handleSyncMessage(message, from: .localNetwork)
            }
        }
        
        // Handle Bluetooth messages
        bluetoothSync.onMessage { [weak self] message in
            Task { @MainActor [weak self] in
                await self?.handleSyncMessage(message, from: .bluetooth)
            }
        }
    }
    
    private func handleSyncMessage(_ message: SyncMessage, from transport: SyncTransport) async {
        print("UnifiedSync: Received \(message.type) via \(transport)")
        
        switch message.type {
        case .devicesUpdate:
            if let devices = try? JSONDecoder().decode([GoveeDevice].self, from: message.payload) {
                // Update local device store
                NotificationCenter.default.post(
                    name: NSNotification.Name("DevicesUpdated"),
                    object: devices
                )
            }
            
        case .groupsUpdate:
            if let groups = try? JSONDecoder().decode([DeviceGroup].self, from: message.payload) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("GroupsUpdated"),
                    object: groups
                )
            }
            
        case .settingsUpdate:
            if let settings = try? JSONDecoder().decode(SyncedSettings.self, from: message.payload) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SettingsUpdated"),
                    object: settings
                )
            }
            
        case .deviceControl:
            // Forward control commands to RemoteControlHandler
            NotificationCenter.default.post(
                name: NSNotification.Name("ControlMessageReceived"),
                object: message.payload
            )
            
        case .ping:
            print("UnifiedSync: Ping received from \(transport)")
        }
    }
    
    // MARK: - Sync Operations
    
    func syncDevices(_ devices: [GoveeDevice]) async throws {
        let payload = try JSONEncoder().encode(devices)
        let message = SyncMessage(type: .devicesUpdate, payload: payload)
        
        // Sync via all active transports
        if activeTransports.contains(.appGroups) {
            cloudSync.saveDevicesToAppGroups(devices)
        }
        
        if activeTransports.contains(.cloud) {
            try await cloudSync.syncDevicesToCloud(devices)
        }
        
        if activeTransports.contains(.localNetwork) {
            try localNetworkSync.broadcast(message)
        }
        
        if activeTransports.contains(.bluetooth) {
            try bluetoothSync.sendMessage(message)
        }
    }
    
    func syncGroups(_ groups: [DeviceGroup]) async throws {
        let payload = try JSONEncoder().encode(groups)
        let message = SyncMessage(type: .groupsUpdate, payload: payload)
        
        if activeTransports.contains(.appGroups) {
            cloudSync.saveGroupsToAppGroups(groups)
        }
        
        if activeTransports.contains(.cloud) {
            try await cloudSync.syncGroupsToCloud(groups)
        }
        
        if activeTransports.contains(.localNetwork) {
            try localNetworkSync.broadcast(message)
        }
        
        if activeTransports.contains(.bluetooth) {
            try bluetoothSync.sendMessage(message)
        }
    }
    
    func syncSettings(_ settings: SyncedSettings) async throws {
        let payload = try JSONEncoder().encode(settings)
        let message = SyncMessage(type: .settingsUpdate, payload: payload)
        
        if activeTransports.contains(.appGroups) {
            cloudSync.saveSettingsToAppGroups(settings)
        }
        
        if activeTransports.contains(.localNetwork) {
            try localNetworkSync.broadcast(message)
        }
        
        if activeTransports.contains(.bluetooth) {
            try bluetoothSync.sendMessage(message)
        }
    }
    
    // MARK: - Connection Status
    
    var isConnectedViaLocalNetwork: Bool {
        !localNetworkSync.connectedPeers.isEmpty
    }
    
    var isConnectedViaBluetooth: Bool {
        !bluetoothSync.connectedPeers.isEmpty
    }
    
    var isConnectedViaCloud: Bool {
        cloudSync.lastSyncDate != nil
    }
    
    var connectionStatus: String {
        var statuses: [String] = []
        if isConnectedViaCloud { statuses.append("Cloud") }
        if isConnectedViaLocalNetwork { statuses.append("Local Network") }
        if isConnectedViaBluetooth { statuses.append("Bluetooth") }
        return statuses.isEmpty ? "Not Connected" : statuses.joined(separator: ", ")
    }
}
