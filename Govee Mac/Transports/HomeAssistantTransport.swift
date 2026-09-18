import Foundation

// MARK: - Home Assistant Implementation

struct HomeAssistantDiscovery: DeviceDiscoveryProtocol {
    let baseURL: URL
    let token: String
    
    func refreshDevices() async throws -> [GoveeDevice] {
        guard !token.isEmpty else { return [] }
        
        var req = URLRequest(url: baseURL.appendingPathComponent("api/states"))
        req.timeoutInterval = 5
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
        req.timeoutInterval = 5
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
