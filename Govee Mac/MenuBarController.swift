import SwiftUI
import AppKit

@MainActor
class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private let deviceStore: DeviceStore
    private let controller: GoveeController
    
    init(deviceStore: DeviceStore, controller: GoveeController) {
        self.deviceStore = deviceStore
        self.controller = controller
        // Don't call setupMenuBar in init - defer bto after initialization
    }
    
    func setup() {
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.setupMenuBar()
            }
            return
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: "Govee Lights")
            button.image?.isTemplate = true
        }
        
        updateMenu()
    }
    
    func updateMenu() {
        let menu = NSMenu()
        
        // Quick devices section
        if !deviceStore.devices.isEmpty {
            menu.addItem(NSMenuItem(title: "Quick Controls", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            
            for device in deviceStore.devices.prefix(5) {
                let deviceItem = NSMenuItem(title: device.name, action: nil, keyEquivalent: "")
                let submenu = NSMenu()
                
                let powerItem = NSMenuItem(title: device.isOn == true ? "Turn Off" : "Turn On",
                                          action: #selector(togglePower(_:)),
                                          keyEquivalent: "")
                powerItem.target = self
                powerItem.representedObject = device.id
                submenu.addItem(powerItem)
                
                if device.supportsBrightness {
                    submenu.addItem(NSMenuItem.separator())
                    submenu.addItem(NSMenuItem(title: "Brightness: \(device.brightness ?? 50)%", action: nil, keyEquivalent: ""))
                }
                
                deviceItem.submenu = submenu
                menu.addItem(deviceItem)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Groups section
        if !deviceStore.groups.isEmpty {
            for group in deviceStore.groups {
                let groupItem = NSMenuItem(title: "📁 \(group.name)", action: nil, keyEquivalent: "")
                let submenu = NSMenu()
                
                let allOnItem = NSMenuItem(title: "All On", action: #selector(groupAllOn(_:)), keyEquivalent: "")
                allOnItem.target = self
                allOnItem.representedObject = group.id
                submenu.addItem(allOnItem)
                
                let allOffItem = NSMenuItem(title: "All Off", action: #selector(groupAllOff(_:)), keyEquivalent: "")
                allOffItem.target = self
                allOffItem.representedObject = group.id
                submenu.addItem(allOffItem)
                
                groupItem.submenu = submenu
                menu.addItem(groupItem)
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        // Refresh
        let refreshItem = NSMenuItem(title: "Refresh Devices", action: #selector(refreshDevices), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Open main window
        let openItem = NSMenuItem(title: "Open Govee Mac", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        
        // Quit
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func togglePower(_ sender: NSMenuItem) {
        guard let deviceId = sender.representedObject as? String else { return }
        Task {
            if let device = deviceStore.devices.first(where: { $0.id == deviceId }) {
                let newState = !(device.isOn ?? false)
                deviceStore.selectedDeviceID = deviceId
                await controller.setPower(on: newState)
                updateMenu()
            }
        }
    }
    
    @objc private func groupAllOn(_ sender: NSMenuItem) {
        guard let groupId = sender.representedObject as? String else { return }
        Task {
            await controller.setGroupPower(groupID: groupId, on: true)
            updateMenu()
        }
    }
    
    @objc private func groupAllOff(_ sender: NSMenuItem) {
        guard let groupId = sender.representedObject as? String else { return }
        Task {
            await controller.setGroupPower(groupID: groupId, on: false)
            updateMenu()
        }
    }
    
    @objc private func refreshDevices() {
        Task {
            await controller.refresh()
            updateMenu()
        }
    }
    
    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        // Check if any window is already open. If so, bring it to the front.
        if let window = NSApp.windows.first(where: { $0.isMiniaturized == false && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        // If no window is visible, try to un-miniaturize one.
        if let miniaturizedWindow = NSApp.windows.first(where: { $0.isMiniaturized }) {
            miniaturizedWindow.deminiaturize(nil)
            return
        }

        // If the window was closed, we need to open a new one.
        // Note: newWindowForTab: may also be private API in some macOS versions.
        // For SwiftUI lifecycle apps, window recreation is best handled by the system.
        // This is a best-effort approach that works in most cases.
        if #available(macOS 13.0, *) {
            NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
        } else {
            // Fallback for older macOS versions - try to find and open the main window
            for window in NSApp.windows {
                if window.title.contains("Govee") || window.title.isEmpty {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }
        }
    }
}
