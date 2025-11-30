// filepath: /Users/jorisconrad/Documents/Govee Mac Swift/Govee Mac/Govee Mac/Services/StubServices.swift
import Foundation

struct StubDiscovery: DeviceDiscoveryProtocol {
    func refreshDevices() async throws -> [GoveeDevice] {
        return [
            .init(id: "demo-1", name: "Demo Lamp", model: "H6001", ipAddress: "192.168.1.50", online: true, supportsBrightness: true, supportsColor: true)
        ]
    }
}

struct StubControl: DeviceControlProtocol {
    func setPower(device: GoveeDevice, on: Bool) async throws { print("Stub power \(on) for \(device.name)") }
    func setBrightness(device: GoveeDevice, value: Int) async throws { print("Stub brightness \(value) for \(device.name)") }
}
