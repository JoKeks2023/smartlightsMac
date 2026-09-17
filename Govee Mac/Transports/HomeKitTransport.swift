import Foundation
import Combine
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - HomeKit Implementation

#if canImport(HomeKit)
@available(macOS 10.15, *)
@MainActor
class HomeKitManager: NSObject, ObservableObject, HMHomeManagerDelegate {
    let homeManager = HMHomeManager()
    @Published var accessories: [HMAccessory] = []
    
    override init() {
        super.init()
        homeManager.delegate = self
    }
    
    func discoverDevices() async -> [GoveeDevice] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard let home = homeManager.primaryHome else { return [] }
        // Discover ALL HomeKit accessories with light services, not just Govee
        // This enables support for Philips Hue, LIFX, Nanoleaf, and other HomeKit lights
        let lightAccessories = home.accessories.filter { acc in
            acc.services.contains { $0.serviceType == HMServiceTypeLightbulb }
        }
        
        return lightAccessories.compactMap { accessory in
            guard let lightService = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb }) else { return nil }
            
            let supportsBrightness = lightService.characteristics.contains { $0.characteristicType == HMCharacteristicTypeBrightness }
            let supportsColor = lightService.characteristics.contains { $0.characteristicType == HMCharacteristicTypeHue }
            let supportsCT = lightService.characteristics.contains { $0.characteristicType == HMCharacteristicTypeColorTemperature }
            
            return GoveeDevice(
                id: "homekit-\(accessory.uniqueIdentifier.uuidString)",
                name: accessory.name,
                model: accessory.model,
                ipAddress: nil,
                online: accessory.isReachable,
                supportsBrightness: supportsBrightness,
                supportsColor: supportsColor,
                supportsColorTemperature: supportsCT,
                transports: [.homeKit],
                isOn: nil,
                brightness: nil,
                color: nil,
                colorTemperature: nil
            )
        }
    }
    
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor [weak self] in
            if let home = manager.primaryHome {
                self?.accessories = home.accessories
            }
        }
    }
}

struct HomeKitControl: DeviceControlProtocol {
    let homeManager: HMHomeManager
    
    private func getAccessory(for device: GoveeDevice) -> HMAccessory? {
        let idString = device.id.replacingOccurrences(of: "homekit-", with: "")
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return homeManager.primaryHome?.accessories.first { $0.uniqueIdentifier == uuid }
    }
    
    private func getLightService(_ accessory: HMAccessory) -> HMService? {
        accessory.services.first { $0.serviceType == HMServiceTypeLightbulb }
    }
    
    func setPower(device: GoveeDevice, on: Bool) async throws {
        guard let accessory = getAccessory(for: device),
              let service = getLightService(accessory),
              let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) else { return }
        try await characteristic.writeValue(on)
    }
    
    func setBrightness(device: GoveeDevice, value: Int) async throws {
        guard let accessory = getAccessory(for: device),
              let service = getLightService(accessory),
              let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeBrightness }) else { return }
        try await characteristic.writeValue(value)
    }
    
    func setColor(device: GoveeDevice, color: DeviceColor) async throws {
        guard let accessory = getAccessory(for: device),
              let service = getLightService(accessory) else { return }
        
        let r = Double(color.r) / 255.0
        let g = Double(color.g) / 255.0
        let b = Double(color.b) / 255.0
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        var hue: Double = 0
        if delta != 0 {
            if maxC == r {
                hue = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxC == g {
                hue = 60 * (((b - r) / delta) + 2)
            } else {
                hue = 60 * (((r - g) / delta) + 4)
            }
        }
        if hue < 0 { hue += 360 }
        let saturation = maxC == 0 ? 0 : (delta / maxC) * 100
        
        if let hueChar = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeHue }) {
            try await hueChar.writeValue(hue)
        }
        if let satChar = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeSaturation }) {
            try await satChar.writeValue(saturation)
        }
    }
    
    func setColorTemperature(device: GoveeDevice, value: Int) async throws {
        guard let accessory = getAccessory(for: device),
              let service = getLightService(accessory),
              let characteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeColorTemperature }) else { return }
        let mireds = Int(1_000_000 / Double(value))
        try await characteristic.writeValue(mireds)
    }
}
#endif
