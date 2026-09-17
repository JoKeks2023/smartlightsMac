import Foundation

// MARK: - WLED Implementation

struct WLEDDiscovery: DeviceDiscoveryProtocol {
    func refreshDevices() async throws -> [GoveeDevice] {
        // WLED devices are discovered via mDNS (_wled._tcp.)
        // This is handled by LANDiscovery, but we need to identify them
        // For now, return empty as LANDiscovery will pick them up
        return []
    }
}

struct WLEDControl: DeviceControlProtocol {
    let deviceIP: String
    
    private func sendCommand(_ state: [String: Any]) async throws {
        guard let url = URL(string: "http://\(deviceIP)/json/state") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: state)
        request.timeoutInterval = 3
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        try await sendCommand(["on": on])
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        // WLED uses 0-255 for brightness
        let wledBrightness = Int(Double(value) / 100.0 * 255.0)
        try await sendCommand(["bri": wledBrightness])
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        // WLED accepts RGB as array [r, g, b]
        try await sendCommand(["seg": [["col": [[color.r, color.g, color.b]]]]])
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        // WLED doesn't directly support color temperature control
        // Could be approximated with RGB conversion, but not implemented
        throw SmartLightError.featureNotSupported("WLED color temperature control")
    }
}
