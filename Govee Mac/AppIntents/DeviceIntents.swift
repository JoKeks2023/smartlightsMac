import AppIntents
import Foundation

// MARK: - Runtime

/// Shared execution path for Shortcuts/Siri intents. Runs independent of a
/// live `GoveeController` — Shortcuts can invoke these while the app isn't
/// in the foreground (or isn't running at all), so state is read from /
/// written back to the same persisted UserDefaults + Keychain-backed stores
/// the app itself uses (`DeviceStore`, `SettingsStore`).
enum DeviceIntentRuntime {
    enum IntentError: LocalizedError {
        case deviceNotFound
        case noControlAvailable

        var errorDescription: String? {
            switch self {
            case .deviceNotFound:
                return "That light could not be found. Open Govee Mac once to refresh your devices."
            case .noControlAvailable:
                return "That light isn't reachable right now (no LAN, Hue, Home Assistant, or Cloud connection available)."
            }
        }
    }

    @MainActor
    static func allDevices() -> [GoveeDevice] {
        DeviceStore().devices
    }

    @MainActor
    static func setPower(deviceID: String, on: Bool) async throws {
        let settings = SettingsStore()
        let store = DeviceStore()
        guard let device = store.devices.first(where: { $0.id == deviceID }) else {
            throw IntentError.deviceNotFound
        }
        guard let control = DeviceControlResolver.control(for: device, settings: settings) else {
            throw IntentError.noControlAvailable
        }
        try await control.setPower(device: device, on: on)
        if let idx = store.devices.firstIndex(where: { $0.id == deviceID }) {
            store.devices[idx].isOn = on
        }
    }

    @MainActor
    static func setBrightness(deviceID: String, percent: Int) async throws {
        let settings = SettingsStore()
        let store = DeviceStore()
        guard let device = store.devices.first(where: { $0.id == deviceID }) else {
            throw IntentError.deviceNotFound
        }
        guard let control = DeviceControlResolver.control(for: device, settings: settings) else {
            throw IntentError.noControlAvailable
        }
        let clamped = min(max(percent, 0), 100)
        try await control.setBrightness(device: device, value: clamped)
        if let idx = store.devices.firstIndex(where: { $0.id == deviceID }) {
            store.devices[idx].brightness = clamped
        }
    }
}

// MARK: - Entity

struct GoveeLightEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Light"
    static var defaultQuery = GoveeLightQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct GoveeLightQuery: EntityQuery {
    func entities(for identifiers: [GoveeLightEntity.ID]) async throws -> [GoveeLightEntity] {
        let devices = await DeviceIntentRuntime.allDevices()
        return devices.filter { identifiers.contains($0.id) }.map { GoveeLightEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [GoveeLightEntity] {
        let devices = await DeviceIntentRuntime.allDevices()
        return devices.map { GoveeLightEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - Intents

struct SetLightPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Light Power"
    static var description = IntentDescription("Turns a Govee Mac light on or off.")

    @Parameter(title: "Light")
    var device: GoveeLightEntity

    @Parameter(title: "Power", default: true)
    var isOn: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Turn \(\.$isOn) \(\.$device)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await DeviceIntentRuntime.setPower(deviceID: device.id, on: isOn)
        return .result()
    }
}

struct SetLightBrightnessIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Light Brightness"
    static var description = IntentDescription("Sets a Govee Mac light's brightness (0-100%).")

    @Parameter(title: "Light")
    var device: GoveeLightEntity

    @Parameter(title: "Brightness (0-100)", default: 100)
    var brightness: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$device) brightness to \(\.$brightness)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await DeviceIntentRuntime.setBrightness(deviceID: device.id, percent: brightness)
        return .result()
    }
}

// MARK: - Shortcuts

struct GoveeMacShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetLightPowerIntent(),
            phrases: [
                "Turn on \(\.$device) with \(.applicationName)",
                "Turn off \(\.$device) with \(.applicationName)"
            ],
            shortTitle: "Light Power",
            systemImageName: "lightbulb"
        )
        AppShortcut(
            intent: SetLightBrightnessIntent(),
            phrases: [
                "Set \(\.$device) brightness with \(.applicationName)"
            ],
            shortTitle: "Light Brightness",
            systemImageName: "sun.max"
        )
    }
}
