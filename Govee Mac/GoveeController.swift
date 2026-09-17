import SwiftUI
import Foundation
import Combine
#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Controller

@MainActor
class GoveeController: ObservableObject {
    let deviceStore: DeviceStore
    let profileStore: DMXProfileStore
    private let settings: SettingsStore
    private var pollingTask: Task<Void, Never>?
    private var dmxReceiver: DMXReceiver?
    private var isRefreshing = false
    // Remote control handler is implemented in the remote-control service.
    // To avoid build-time coupling issues this build omits direct initialization
    // of the macOS <-> iOS remote control handler. The feature can be
    // re-enabled when the remote control service is available.
    
    #if canImport(HomeKit)
    @available(macOS 10.15, *)
    private var homeKitManager: HomeKitManager?
    #endif
    
    init(deviceStore: DeviceStore, settings: SettingsStore, profileStore: DMXProfileStore) {
        self.deviceStore = deviceStore
        self.settings = settings
        self.profileStore = profileStore
        
        #if canImport(HomeKit)
        if #available(macOS 10.15, *), settings.homeKitEnabled {
            self.homeKitManager = HomeKitManager()
        }
        #endif
        
        if settings.dmxEnabled {
            let receiver = DMXReceiver(protocol: settings.dmxProtocol)
            receiver.controller = self
            self.dmxReceiver = receiver
            do {
                try receiver.start()
                print("DMX Receiver started on \(settings.dmxProtocol.rawValue)")
            } catch {
                print("Failed to start DMX receiver: \(error)")
            }
        }
        
        startPolling()
    }
    
    deinit {
        pollingTask?.cancel()
        dmxReceiver?.stop()
    }
    
    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await refresh()
            }
        }
    }

    private func discoverCloudDevices() async -> [GoveeDevice] {
        guard !settings.goveeApiKey.isEmpty else { return [] }
        let cloudDiscovery = CloudDiscovery(apiKey: settings.goveeApiKey)
        return (try? await cloudDiscovery.refreshDevices()) ?? []
    }

    private func discoverLANDevices() async -> [GoveeDevice] {
        guard settings.prefersLan else { return [] }
        let lanDiscovery = LANDiscovery()
        return (try? await lanDiscovery.refreshDevices()) ?? []
    }

    private func discoverHomeAssistantDevices() async -> [GoveeDevice] {
        guard let url = URL(string: settings.haBaseURL), !settings.haToken.isEmpty else { return [] }
        let haDiscovery = HomeAssistantDiscovery(baseURL: url, token: settings.haToken)
        return (try? await haDiscovery.refreshDevices()) ?? []
    }
    
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var merged: [String: GoveeDevice] = [:]
        for device in deviceStore.devices {
            merged[device.id] = device
        }

        async let cloudDevices = discoverCloudDevices()
        async let lanDevices = discoverLANDevices()
        async let homeAssistantDevices = discoverHomeAssistantDevices()

        for dev in await cloudDevices {
            merged[dev.id] = dev
        }

        for dev in await lanDevices {
            if var existing = merged[dev.id] {
                existing.transports.insert(.lan)
                existing.ipAddress = dev.ipAddress
                merged[dev.id] = existing
            } else {
                merged[dev.id] = dev
            }
        }
        
        // HomeKit
        #if canImport(HomeKit)
        if #available(macOS 10.15, *), settings.homeKitEnabled, let hkManager = homeKitManager {
            let devices = await hkManager.discoverDevices()
            for dev in devices {
                if var existing = merged[dev.id] {
                    existing.transports.insert(.homeKit)
                    merged[dev.id] = existing
                } else {
                    merged[dev.id] = dev
                }
            }
        }
        #endif

        for dev in await homeAssistantDevices {
            if var existing = merged[dev.id] {
                existing.transports.insert(.homeAssistant)
                existing.isOn = dev.isOn ?? existing.isOn
                existing.brightness = dev.brightness ?? existing.brightness
                merged[dev.id] = existing
            } else {
                merged[dev.id] = dev
            }
        }
        
        let devices = Array(merged.values).sorted { $0.name < $1.name }
        deviceStore.replaceAll(devices)
        
        if deviceStore.selectedDeviceID == nil {
            deviceStore.selectedDeviceID = devices.first?.id
        }
    }

    func refreshLANOnly() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let discoveredDevices = await discoverLANDevices()
        var merged: [String: GoveeDevice] = [:]

        for device in deviceStore.devices {
            if !(device.transports.contains(.lan) || device.transports.contains(.wled) || device.transports.contains(.lifx)) {
                merged[device.id] = device
            }
        }

        for device in discoveredDevices {
            merged[device.id] = device
        }

        let devices = Array(merged.values).sorted { $0.name < $1.name }
        deviceStore.replaceAll(devices)

        if deviceStore.selectedDeviceID == nil {
            deviceStore.selectedDeviceID = devices.first?.id
        }
    }
    
    private func getControl(for device: GoveeDevice) -> DeviceControlProtocol? {
        // DMX has highest priority for devices with DMX mapping
        // DMX devices are controlled via incoming DMX signals, not direct control
        // So we skip them here and fall through to other transports
        
        // WLED devices
        if device.transports.contains(.wled), let ip = device.ipAddress {
            return WLEDControl(deviceIP: ip)
        }
        
        // LIFX devices (LAN protocol)
        // Note: LIFX requires UDP binary protocol - not yet fully implemented
        if device.transports.contains(.lifx), device.ipAddress != nil {
            // return LIFXControl(deviceIP: ip)  // Uncomment when UDP protocol is implemented
        }
        
        // Philips Hue Bridge devices
        if device.transports.contains(.hue), let ip = device.ipAddress,
           let username = settings.hueBridgeCredentials[ip] {
            return HueBridgeControl(bridgeIP: ip, username: username)
        }
        
        if settings.prefersLan, device.transports.contains(.lan), let ip = device.ipAddress {
            return LANControl(deviceIP: ip)
        }
        
        #if canImport(HomeKit)
        if #available(macOS 10.15, *), device.transports.contains(.homeKit), let hkManager = homeKitManager {
            return HomeKitControl(homeManager: hkManager.homeManager)
        }
        #endif
        
        if device.transports.contains(.homeAssistant), let url = URL(string: settings.haBaseURL), !settings.haToken.isEmpty {
            return HomeAssistantControl(baseURL: url, token: settings.haToken)
        }
        
        if device.transports.contains(.cloud), !settings.goveeApiKey.isEmpty {
            return CloudControl(apiKey: settings.goveeApiKey)
        }
        
        return nil
    }
    
    private var selectedDevice: GoveeDevice? {
        deviceStore.devices.first { $0.id == deviceStore.selectedDeviceID }
    }
    
    // Public methods for DMX receiver to control specific devices
    func setDevicePower(device: GoveeDevice, on: Bool) async throws {
        // Don't use DMX control to avoid feedback loop
        var control: DeviceControlProtocol?
        
        if settings.prefersLan, device.transports.contains(.lan), let ip = device.ipAddress {
            control = LANControl(deviceIP: ip)
        } else if device.transports.contains(.cloud), !settings.goveeApiKey.isEmpty {
            control = CloudControl(apiKey: settings.goveeApiKey)
        }
        
        guard let ctrl = control else { return }
        try await ctrl.setPower(device: device, on: on)
        
        if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
            deviceStore.devices[idx].isOn = on
        }
    }
    
    func setDeviceBrightness(device: GoveeDevice, value: Int) async throws {
        var control: DeviceControlProtocol?
        
        if settings.prefersLan, device.transports.contains(.lan), let ip = device.ipAddress {
            control = LANControl(deviceIP: ip)
        } else if device.transports.contains(.cloud), !settings.goveeApiKey.isEmpty {
            control = CloudControl(apiKey: settings.goveeApiKey)
        }
        
        guard let ctrl = control else { return }
        try await ctrl.setBrightness(device: device, value: value)
        
        if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
            deviceStore.devices[idx].brightness = value
        }
    }
    
    func setDeviceColor(device: GoveeDevice, color: DeviceColor) async throws {
        var control: DeviceControlProtocol?
        
        if settings.prefersLan, device.transports.contains(.lan), let ip = device.ipAddress {
            control = LANControl(deviceIP: ip)
        } else if device.transports.contains(.cloud), !settings.goveeApiKey.isEmpty {
            control = CloudControl(apiKey: settings.goveeApiKey)
        }
        
        guard let ctrl = control else { return }
        try await ctrl.setColor(device: device, color: color)
        
        if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
            deviceStore.devices[idx].color = color
        }
    }
    
    func setPower(on: Bool) async {
        guard let device = selectedDevice, let control = getControl(for: device) else { return }
        do {
            try await control.setPower(device: device, on: on)
            if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
                deviceStore.devices[idx].isOn = on
            }
        } catch {
            print("Power error: \(error)")
        }
    }
    
    func setBrightness(_ value: Int) async {
        guard let device = selectedDevice, let control = getControl(for: device) else { return }
        do {
            try await control.setBrightness(device: device, value: value)
            if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
                deviceStore.devices[idx].brightness = value
            }
        } catch {
            print("Brightness error: \(error)")
        }
    }
    
    func setColor(_ color: DeviceColor) async {
        guard let device = selectedDevice, let control = getControl(for: device) else { return }
        do {
            try await control.setColor(device: device, color: color)
            if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
                deviceStore.devices[idx].color = color
            }
        } catch {
            print("Color error: \(error)")
        }
    }
    
    func setColorTemperature(_ value: Int) async {
        guard let device = selectedDevice, let control = getControl(for: device) else { return }
        do {
            try await control.setColorTemperature(device: device, value: value)
            if let idx = deviceStore.devices.firstIndex(where: { $0.id == device.id }) {
                deviceStore.devices[idx].colorTemperature = value
            }
        } catch {
            print("CT error: \(error)")
        }
    }
    
    func setGroupPower(groupID: String, on: Bool) async {
        let members = deviceStore.devices.filter { deviceStore.groups.first(where: { $0.id == groupID })?.memberIDs.contains($0.id) == true }
        for device in members {
            if let control = getControl(for: device) {
                try? await control.setPower(device: device, on: on)
            }
        }
    }
    
    func setGroupBrightness(groupID: String, value: Int) async {
        let members = deviceStore.devices.filter { deviceStore.groups.first(where: { $0.id == groupID })?.memberIDs.contains($0.id) == true }
        for device in members {
            if let control = getControl(for: device) {
                try? await control.setBrightness(device: device, value: value)
            }
        }
    }
    
    func setGroupColor(groupID: String, color: DeviceColor) async {
        let members = deviceStore.devices.filter { deviceStore.groups.first(where: { $0.id == groupID })?.memberIDs.contains($0.id) == true }
        for device in members where device.supportsColor {
            if let control = getControl(for: device) {
                try? await control.setColor(device: device, color: color)
            }
        }
    }
}
