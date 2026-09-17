import Foundation

// MARK: - Cloud Implementation

struct CloudDiscovery: DeviceDiscoveryProtocol {
    let apiKey: String
    
    func refreshDevices() async throws -> [GoveeDevice] {
        guard !apiKey.isEmpty else { return [] }
        
        var request = URLRequest(url: URL(string: "https://developer-api.govee.com/v1/devices")!)
        request.timeoutInterval = 5
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
