import Foundation

// MARK: - Philips Hue Bridge Implementation

/// A Hue bridge found via discovery, before pairing.
struct HueBridgeCandidate: Identifiable, Hashable {
    var id: String { bridgeID }
    let ip: String
    let bridgeID: String
}

enum HueBridgeError: LocalizedError {
    case linkButtonNotPressed
    case pairingTimedOut
    case bridgeUnreachable

    var errorDescription: String? {
        switch self {
        case .linkButtonNotPressed:
            return "Press the link button on the Hue Bridge, then try again."
        case .pairingTimedOut:
            return "Timed out waiting for the Hue Bridge link button."
        case .bridgeUnreachable:
            return "Could not reach the Hue Bridge on the network."
        }
    }
}

struct HueBridgeDiscovery: DeviceDiscoveryProtocol {
    /// bridge IP -> paired username (SettingsStore.hueBridgeCredentials)
    let credentials: [String: String]

    init(credentials: [String: String] = [:]) {
        self.credentials = credentials
    }

    func refreshDevices() async throws -> [GoveeDevice] {
        // Only fetch lights from bridges we already have a paired username for.
        // Un-paired bridges are surfaced separately via discoverCandidateBridges()
        // + Self.pair(bridgeIP:) so the UI can drive the link-button flow.
        var devices: [GoveeDevice] = []
        for (ip, username) in credentials {
            let lights = (try? await Self.fetchLights(bridgeIP: ip, username: username)) ?? []
            devices.append(contentsOf: lights)
        }
        return devices
    }

    /// Finds Hue bridges on the network via the official cloud discovery
    /// endpoint (N-UPnP). Does not require pairing.
    static func discoverCandidateBridges() async -> [HueBridgeCandidate] {
        guard let url = URL(string: "https://discovery.meethue.com/") else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return json.compactMap { entry in
            guard let ip = entry["internalipaddress"] as? String, let id = entry["id"] as? String else { return nil }
            return HueBridgeCandidate(ip: ip, bridgeID: id)
        }
    }

    /// Performs the Hue "press link button" pairing flow against a single
    /// bridge: polls every second for up to `timeout` seconds, registering
    /// an application username once the button is pressed. Returns the
    /// username to persist (e.g. in SettingsStore.hueBridgeCredentials).
    static func pair(bridgeIP: String, timeout: TimeInterval = 30) async throws -> String {
        guard let url = URL(string: "http://\(bridgeIP)/api") else { throw HueBridgeError.bridgeUnreachable }
        let deviceType = "govee_mac#\(Host.current().localizedName ?? "mac")"
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 3
            request.httpBody = try JSONSerialization.data(withJSONObject: ["devicetype": deviceType])

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw HueBridgeError.bridgeUnreachable
            }

            if let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for result in results {
                    if let success = result["success"] as? [String: Any], let username = success["username"] as? String {
                        return username
                    }
                    if let failure = result["error"] as? [String: Any], let type = failure["type"] as? Int, type == 101 {
                        // 101 = link button not pressed yet; keep polling.
                    }
                }
            }

            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        throw HueBridgeError.pairingTimedOut
    }

    private static func fetchLights(bridgeIP: String, username: String) async throws -> [GoveeDevice] {
        guard let url = URL(string: "http://\(bridgeIP)/api/\(username)/lights") else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return [] }

        return json.compactMap { lightID, light -> GoveeDevice? in
            guard let name = light["name"] as? String else { return nil }
            let state = light["state"] as? [String: Any]
            let modelID = light["modelid"] as? String
            let isOn = state?["on"] as? Bool
            let bri = state?["bri"] as? Int
            let brightnessPercent = bri.map { Int(Double($0) / 254.0 * 100.0) }
            let capabilities = (light["type"] as? String)?.lowercased() ?? ""

            return GoveeDevice(
                id: "hue-\(bridgeIP)-\(lightID)",
                name: name,
                model: modelID,
                ipAddress: bridgeIP,
                online: state?["reachable"] as? Bool ?? true,
                supportsBrightness: true,
                supportsColor: capabilities.contains("color") && !capabilities.contains("temperature"),
                supportsColorTemperature: capabilities.contains("color temperature") || capabilities.contains("color"),
                transports: [.hue],
                isOn: isOn,
                brightness: brightnessPercent,
                color: nil,
                colorTemperature: nil
            )
        }
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
