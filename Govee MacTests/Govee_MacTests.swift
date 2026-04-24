import Foundation
import Testing
@testable import Govee_Mac

struct GoveeMacTests {
    private func makeDefaults(testName: String = #function) -> UserDefaults {
        let suiteName = "GoveeMacTests.\(testName)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create UserDefaults suite \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeDevice(
        id: String = "cloud-device-1",
        name: String = "Desk Lamp",
        brightness: Int? = 42
    ) -> GoveeDevice {
        GoveeDevice(
            id: id,
            name: name,
            model: "H6001",
            ipAddress: "192.168.1.20",
            online: true,
            supportsBrightness: true,
            supportsColor: true,
            supportsColorTemperature: true,
            transports: [.cloud, .lan],
            isOn: true,
            brightness: brightness,
            color: DeviceColor(r: 255, g: 180, b: 120),
            colorTemperature: 4000,
            dmxMapping: nil
        )
    }

    @Test
    @MainActor
    func deviceStoreRestoresCachedDevicesAndGroups() {
        let defaults = makeDefaults()
        let device = makeDevice()
        let group = DeviceGroup(name: "Office", memberIDs: [device.id])

        let store = DeviceStore(userDefaults: defaults)
        store.upsert(device)
        store.groups = [group]

        let restored = DeviceStore(userDefaults: defaults)
        #expect(restored.devices == [device])
        #expect(restored.groups == [group])
    }

    @Test
    @MainActor
    func deviceStorePersistsUpdatesForExistingDevice() {
        let defaults = makeDefaults()
        let original = makeDevice()
        var updated = original
        updated.brightness = 87
        updated.isOn = false

        let store = DeviceStore(userDefaults: defaults)
        store.upsert(original)
        store.upsert(updated)

        let restored = DeviceStore(userDefaults: defaults)
        #expect(restored.devices == [updated])
    }

    @Test
    @MainActor
    func replaceAllOverwritesCachedDeviceSnapshot() {
        let defaults = makeDefaults()
        let first = makeDevice(id: "first-device")
        let second = makeDevice(id: "second-device", name: "Floor Lamp", brightness: 12)

        let store = DeviceStore(userDefaults: defaults)
        store.upsert(first)
        store.replaceAll([second])

        let restored = DeviceStore(userDefaults: defaults)
        #expect(restored.devices == [second])
    }

    @Test
    func settingsStoreUsesInjectedUserDefaultsForNonSecretPreferences() {
        let defaults = makeDefaults()
        let settings = SettingsStore(userDefaults: defaults)

        settings.prefersLan = false
        settings.homeKitEnabled = true
        settings.haBaseURL = "https://homeassistant.local:8123"
        settings.dmxEnabled = true
        settings.dmxProtocol = .sacn
        settings.hueBridgeCredentials = ["192.168.1.10": "bridge-user"]

        let restored = SettingsStore(userDefaults: defaults)
        #expect(restored.prefersLan == false)
        #expect(restored.homeKitEnabled == true)
        #expect(restored.haBaseURL == "https://homeassistant.local:8123")
        #expect(restored.dmxEnabled == true)
        #expect(restored.dmxProtocol == .sacn)
        #expect(restored.hueBridgeCredentials == ["192.168.1.10": "bridge-user"])
    }
}
