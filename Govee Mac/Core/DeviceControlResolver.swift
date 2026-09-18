import Foundation

/// Picks the right `DeviceControlProtocol` for a device given the app's
/// current settings, in transport-priority order (LAN/WLED/Hue fastest and
/// most direct, Home Assistant/Cloud as fallbacks).
///
/// Used by the Shortcuts/App Intents entry points
/// (`AppIntents/DeviceIntents.swift`), which run without a live
/// `GoveeController` instance and so need a self-contained way to resolve a
/// control. Deliberately NOT used by `GoveeController.getControl(for:)` —
/// that method also handles HomeKit (needs a live `HMHomeManager`) and has
/// its own transport-priority ordering; duplicating this logic here was a
/// pragmatic choice to avoid risking a behavior change in the app's live
/// control path while adding Shortcuts support. If the two ever need to
/// diverge further, that's fine — they serve different callers.
/// DMX is excluded from both: DMX devices are driven by incoming DMX
/// signals, not commanded directly.
enum DeviceControlResolver {
    static func control(for device: GoveeDevice, settings: SettingsStore) -> DeviceControlProtocol? {
        if device.transports.contains(.wled), let ip = device.ipAddress {
            return WLEDControl(deviceIP: ip)
        }

        // Philips Hue Bridge devices — device.ipAddress holds the bridge IP.
        if device.transports.contains(.hue), let bridgeIP = device.ipAddress,
           let username = settings.hueBridgeCredentials[bridgeIP] {
            return HueBridgeControl(bridgeIP: bridgeIP, username: username)
        }

        if settings.prefersLan, device.transports.contains(.lan), let ip = device.ipAddress {
            return LANControl(deviceIP: ip)
        }

        if device.transports.contains(.homeAssistant), let url = URL(string: settings.haBaseURL), !settings.haToken.isEmpty {
            return HomeAssistantControl(baseURL: url, token: settings.haToken)
        }

        if device.transports.contains(.cloud), !settings.goveeApiKey.isEmpty {
            return CloudControl(apiKey: settings.goveeApiKey)
        }

        return nil
    }
}
