import Foundation
import Combine

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
        receiveTask = Task.detached(priority: .utility) { [weak self] in
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
        
        Task { @MainActor in
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
