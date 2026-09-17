import Foundation

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
            var request = URLRequest(url: url)
            request.timeoutInterval = 3
            let (data, response) = try await URLSession.shared.data(for: request)
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
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        let (_, response) = try await URLSession.shared.data(for: request)
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
