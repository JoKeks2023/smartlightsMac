// Services/GoveeController.swift
// Clean helpers-only file; UI moved to ContentView.swift, controller in GoveeModels.swift

import Foundation

// Minimal HA service caller kept for reuse
struct HAServiceCaller {
    let baseURL: URL
    let token: String
    
    func call(domain: String, service: String, data: [String: Any]) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/services/\(domain)/\(service)"))
        req.httpMethod = "POST"
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: data)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
