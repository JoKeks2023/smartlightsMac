import Foundation

// MARK: - LAN Implementation

final class LANDiscovery: DeviceDiscoveryProtocol {
    private let multicastAddress = "239.255.255.250"
    private let scanPort: UInt16 = 4001
    private let responsePort: UInt16 = 4002

    func refreshDevices() async throws -> [GoveeDevice] {
        try await Task.detached(priority: .utility) {
            try self.performScan()
        }.value
    }

    private func performScan() throws -> [GoveeDevice] {
        let socketFD = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            throw URLError(.cannotOpenFile)
        }
        defer { Darwin.close(socketFD) }

        var reuseAddr: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout.size(ofValue: reuseAddr)))

        var receiveAddress = sockaddr_in()
        receiveAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        receiveAddress.sin_family = sa_family_t(AF_INET)
        receiveAddress.sin_port = responsePort.bigEndian
        receiveAddress.sin_addr = in_addr(s_addr: INADDR_ANY)

        let bindResult = withUnsafePointer(to: &receiveAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw URLError(.cannotConnectToHost)
        }

        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))

        let payload = """
        {"msg":{"cmd":"scan","data":{"account_topic":"reserve"}}}
        """
        let payloadData = Data(payload.utf8)

        var multicastSocket = sockaddr_in()
        multicastSocket.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        multicastSocket.sin_family = sa_family_t(AF_INET)
        multicastSocket.sin_port = scanPort.bigEndian
        inet_pton(AF_INET, multicastAddress, &multicastSocket.sin_addr)

        let sendResult = payloadData.withUnsafeBytes { bytes in
            withUnsafePointer(to: &multicastSocket) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    Darwin.sendto(socketFD, bytes.baseAddress, payloadData.count, 0, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sendResult >= 0 else {
            throw URLError(.networkConnectionLost)
        }

        struct ScanEnvelope: Decodable {
            struct Message: Decodable {
                struct Payload: Decodable {
                    let ip: String?
                    let device: String?
                    let sku: String?
                }

                let cmd: String
                let data: Payload
            }

            let msg: Message
        }

        var devicesByID: [String: GoveeDevice] = [:]
        let started = Date()

        while Date().timeIntervalSince(started) < 3 {
            var buffer = [UInt8](repeating: 0, count: 2048)
            var senderAddress = sockaddr_in()
            var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)

            let bytesRead = withUnsafeMutablePointer(to: &senderAddress) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    Darwin.recvfrom(socketFD, &buffer, buffer.count, 0, sockaddrPointer, &senderLength)
                }
            }

            if bytesRead <= 0 {
                continue
            }

            let packet = Data(buffer.prefix(bytesRead))
            guard let envelope = try? JSONDecoder().decode(ScanEnvelope.self, from: packet),
                  envelope.msg.cmd == "scan" else {
                continue
            }

            let fallbackIP = ipAddress(from: senderAddress)
            let ipAddress = envelope.msg.data.ip ?? fallbackIP
            guard let ipAddress, !ipAddress.isEmpty else { continue }

            let deviceID = envelope.msg.data.device ?? "lan-\(ipAddress)"
            let sku = envelope.msg.data.sku
            let name = sku.map { "Govee \($0)" } ?? "Govee @ \(ipAddress)"

            devicesByID[deviceID] = GoveeDevice(
                id: deviceID,
                name: name,
                model: sku,
                ipAddress: ipAddress,
                online: true,
                supportsBrightness: true,
                supportsColor: true,
                supportsColorTemperature: true,
                transports: [.lan],
                isOn: nil,
                brightness: nil,
                color: nil,
                colorTemperature: nil,
                dmxMapping: nil
            )
        }

        return devicesByID.values.sorted { $0.name < $1.name }
    }

    private func ipAddress(from socketAddress: sockaddr_in) -> String? {
        var address = socketAddress.sin_addr
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
            return nil
        }
        return String(cString: buffer)
    }
}

struct LANControl: DeviceControlProtocol {
    let deviceIP: String
    
    private func sendLANCommand(command: String, data: [String: Any]) async throws {
        let payload = try JSONSerialization.data(withJSONObject: [
            "msg": [
                "cmd": command,
                "data": data
            ]
        ])

        try await Task.detached(priority: .utility) {
            let socketFD = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard socketFD >= 0 else {
                throw URLError(.cannotOpenFile)
            }
            defer { Darwin.close(socketFD) }

            var destination = sockaddr_in()
            destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            destination.sin_family = sa_family_t(AF_INET)
            destination.sin_port = UInt16(4003).bigEndian
            inet_pton(AF_INET, deviceIP, &destination.sin_addr)

            let sent = payload.withUnsafeBytes { bytes in
                withUnsafePointer(to: &destination) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                        Darwin.sendto(socketFD, bytes.baseAddress, payload.count, 0, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }

            guard sent >= 0 else {
                throw URLError(.networkConnectionLost)
            }
        }.value
    }
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        try await sendLANCommand(command: "turn", data: ["value": on ? 1 : 0])
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        try await sendLANCommand(command: "brightness", data: ["value": min(max(value, 1), 100)])
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        try await sendLANCommand(command: "colorwc", data: [
            "color": ["r": color.r, "g": color.g, "b": color.b],
            "colorTemInKelvin": 0
        ])
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        try await sendLANCommand(command: "colorwc", data: [
            "color": ["r": 0, "g": 0, "b": 0],
            "colorTemInKelvin": min(max(value, 2000), 9000)
        ])
    }
}
