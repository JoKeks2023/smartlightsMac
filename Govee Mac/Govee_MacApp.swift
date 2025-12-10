import SwiftUI

@main
struct Govee_MacApp: App {
    @StateObject private var settings: SettingsStore
    @StateObject private var deviceStore: DeviceStore
    @StateObject private var profileStore: DMXProfileStore
    @StateObject private var controller: GoveeController
    @StateObject private var menuBarController: MenuBarController

    @State private var showWelcome: Bool

    init() {
        let settingsStore = SettingsStore()
        let store = DeviceStore()
        let profiles = DMXProfileStore()
        let ctrl = GoveeController(deviceStore: store, settings: settingsStore, profileStore: profiles)
        let menuBar = MenuBarController(deviceStore: store, controller: ctrl)
        
        _settings = StateObject(wrappedValue: settingsStore)
        _deviceStore = StateObject(wrappedValue: store)
        _profileStore = StateObject(wrappedValue: profiles)
        _controller = StateObject(wrappedValue: ctrl)
        _menuBarController = StateObject(wrappedValue: menuBar)
        _showWelcome = State(initialValue: !UserDefaults.standard.bool(forKey: "hasCompletedWelcome"))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(deviceStore)
                .environmentObject(profileStore)
                .environmentObject(controller)
                .sheet(isPresented: $showWelcome) {
                    WelcomeView()
                        .environmentObject(settings)
                        .environmentObject(deviceStore)
                        .environmentObject(controller)
                }
                .task {
                    // Setup menu bar on the main actor after the window is ready
                    await MainActor.run {
                        menuBarController.setup()
                    }
                    await controller.refresh()
                }
                .onChange(of: deviceStore.devices) { _ in
                    menuBarController.updateMenu()
                }
                .onChange(of: deviceStore.groups) { _ in
                    menuBarController.updateMenu()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Govee Mac") {
                    NSApp.orderFrontStandardAboutPanel()
                }
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(deviceStore)
                .environmentObject(controller)
        }
    }
}
