import Foundation

// MARK: - Protocols

protocol DeviceDiscoveryProtocol {
    func refreshDevices() async throws -> [GoveeDevice]
}

protocol DeviceControlProtocol {
    func setPower(device: GoveeDevice, on: Bool) async throws
    func setBrightness(device: GoveeDevice, value: Int) async throws
    func setColor(device: GoveeDevice, color: DeviceColor) async throws
    func setColorTemperature(device: GoveeDevice, value: Int) async throws
}
