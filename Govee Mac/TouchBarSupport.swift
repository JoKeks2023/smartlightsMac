import SwiftUI
import AppKit

struct TouchBarBridge: NSViewRepresentable {
    @ObservedObject var deviceStore: DeviceStore
    @ObservedObject var controller: GoveeController

    func makeCoordinator() -> TouchBarCoordinator {
        TouchBarCoordinator(deviceStore: deviceStore, controller: controller)
    }

    func makeNSView(context: Context) -> TouchBarHostingView {
        let view = TouchBarHostingView()
        view.coordinator = context.coordinator
        context.coordinator.hostView = view
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: TouchBarHostingView, context: Context) {
        let shouldInvalidate = context.coordinator.syncState()
        if shouldInvalidate {
            nsView.touchBar = nil
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

final class TouchBarHostingView: NSView {
    weak var coordinator: TouchBarCoordinator?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func makeTouchBar() -> NSTouchBar? {
        coordinator?.makeTouchBar()
    }
}

@MainActor
final class TouchBarCoordinator: NSObject, NSTouchBarDelegate, NSScrubberDataSource, NSScrubberDelegate {
    weak var hostView: TouchBarHostingView?

    private let deviceStore: DeviceStore
    private let controller: GoveeController

    private var brightnessTask: Task<Void, Never>?
    private var colorTemperatureTask: Task<Void, Never>?
    private weak var deviceScrubber: NSScrubber?
    private weak var colorPresetScrubber: NSScrubber?
    private weak var colorPopoverItem: NSPopoverTouchBarItem?

    private enum TouchBarMode {
        case devices
        case device(String)
    }

    private enum DevicePreset: Int, CaseIterable {
        case sunset
        case ruby
        case mint
        case ocean
        case violet

        var title: String {
            switch self {
            case .sunset: return "Sunset"
            case .ruby: return "Ruby"
            case .mint: return "Mint"
            case .ocean: return "Ocean"
            case .violet: return "Violet"
            }
        }

        var color: DeviceColor {
            switch self {
            case .sunset: return DeviceColor(r: 255, g: 140, b: 82)
            case .ruby: return DeviceColor(r: 255, g: 59, b: 72)
            case .mint: return DeviceColor(r: 72, g: 220, b: 177)
            case .ocean: return DeviceColor(r: 40, g: 132, b: 255)
            case .violet: return DeviceColor(r: 151, g: 71, b: 255)
            }
        }
    }

    private enum Identifier {
        static let bar = NSTouchBar.CustomizationIdentifier("com.govee.mac.touchbar")
        static let devicePicker = NSTouchBarItem.Identifier("com.govee.mac.touchbar.devicePicker")
        static let back = NSTouchBarItem.Identifier("com.govee.mac.touchbar.back")
        static let power = NSTouchBarItem.Identifier("com.govee.mac.touchbar.power")
        static let brightnessPopover = NSTouchBarItem.Identifier("com.govee.mac.touchbar.brightnessPopover")
        static let brightnessSlider = NSTouchBarItem.Identifier("com.govee.mac.touchbar.brightnessSlider")
        static let colorTempPopover = NSTouchBarItem.Identifier("com.govee.mac.touchbar.colorTempPopover")
        static let colorTempSlider = NSTouchBarItem.Identifier("com.govee.mac.touchbar.colorTempSlider")
        static let colorPopover = NSTouchBarItem.Identifier("com.govee.mac.touchbar.colorPopover")
        static let colorPresetPicker = NSTouchBarItem.Identifier("com.govee.mac.touchbar.colorPresetPicker")
    }

    private var mode: TouchBarMode = .devices
    private var lastStructuralSignature = ""

    init(deviceStore: DeviceStore, controller: GoveeController) {
        self.deviceStore = deviceStore
        self.controller = controller
        super.init()
        _ = syncState()
    }

    @discardableResult
    func syncState() -> Bool {
        if let selectedDeviceID = deviceStore.selectedDeviceID,
           deviceStore.devices.contains(where: { $0.id == selectedDeviceID }) {
            mode = .device(selectedDeviceID)
        } else {
            mode = .devices
        }

        let signature = structuralSignature()
        let changed = signature != lastStructuralSignature
        lastStructuralSignature = signature
        return changed
    }

    func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = Identifier.bar

        switch mode {
        case .devices:
            touchBar.defaultItemIdentifiers = [.flexibleSpace, Identifier.devicePicker, .flexibleSpace]
            touchBar.customizationAllowedItemIdentifiers = [Identifier.devicePicker]
            touchBar.principalItemIdentifier = Identifier.devicePicker
        case .device(let deviceID):
            guard let device = currentDevice(id: deviceID) else {
                touchBar.defaultItemIdentifiers = [.flexibleSpace, Identifier.devicePicker, .flexibleSpace]
                touchBar.customizationAllowedItemIdentifiers = [Identifier.devicePicker]
                touchBar.principalItemIdentifier = Identifier.devicePicker
                return touchBar
            }

            var identifiers: [NSTouchBarItem.Identifier] = [Identifier.back, Identifier.power]
            if device.supportsBrightness {
                identifiers.append(Identifier.brightnessPopover)
            }
            if device.supportsColorTemperature {
                identifiers.append(Identifier.colorTempPopover)
            }
            if device.supportsColor {
                identifiers.append(Identifier.colorPopover)
            }

            touchBar.defaultItemIdentifiers = identifiers
            touchBar.customizationAllowedItemIdentifiers = identifiers
            touchBar.customizationRequiredItemIdentifiers = [Identifier.back, Identifier.power]
        }

        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case Identifier.devicePicker:
            return makeDevicePickerItem()
        case Identifier.back:
            return makeBackItem()
        case Identifier.power:
            return makePowerItem()
        case Identifier.brightnessPopover:
            return makeBrightnessPopoverItem()
        case Identifier.brightnessSlider:
            return makeBrightnessSliderItem()
        case Identifier.colorTempPopover:
            return makeColorTemperaturePopoverItem()
        case Identifier.colorTempSlider:
            return makeColorTemperatureSliderItem()
        case Identifier.colorPopover:
            return makeColorPopoverItem()
        case Identifier.colorPresetPicker:
            return makeColorPresetPickerItem()
        default:
            return nil
        }
    }

    private func currentDevice(id: String? = nil) -> GoveeDevice? {
        let targetID: String?
        if let id {
            targetID = id
        } else if case let .device(selectedID) = mode {
            targetID = selectedID
        } else {
            targetID = deviceStore.selectedDeviceID
        }

        guard let targetID else { return nil }
        return deviceStore.devices.first(where: { $0.id == targetID })
    }

    private func invalidateTouchBar() {
        _ = syncState()
        hostView?.touchBar = nil
        hostView?.window?.makeFirstResponder(hostView)
    }

    private func makeDevicePickerItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: Identifier.devicePicker)
        let scrubber = NSScrubber()
        scrubber.mode = .free
        scrubber.selectionBackgroundStyle = .roundedBackground
        scrubber.showsAdditionalContentIndicators = true
        scrubber.delegate = self
        scrubber.dataSource = self
        scrubber.register(NSScrubberTextItemView.self, forItemIdentifier: NSUserInterfaceItemIdentifier("DeviceTextItem"))

        let layout = NSScrubberFlowLayout()
        layout.itemSpacing = 20
        scrubber.scrubberLayout = layout
        scrubber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrubber.widthAnchor.constraint(equalToConstant: 420)
        ])

        if case let .device(selectedID) = mode,
           let index = deviceStore.devices.firstIndex(where: { $0.id == selectedID }) {
            scrubber.selectedIndex = index
        }

        deviceScrubber = scrubber
        item.view = scrubber
        item.customizationLabel = "Devices"
        item.visibilityPriority = .high
        return item
    }

    private func makeBackItem() -> NSTouchBarItem {
        let image = NSImage(named: NSImage.touchBarGoBackTemplateName) ?? NSImage()
        let item = NSButtonTouchBarItem(identifier: Identifier.back, image: image, target: self, action: #selector(goBack))
        item.customizationLabel = "Back"
        item.visibilityPriority = .high
        return item
    }

    private func makePowerItem() -> NSTouchBarItem {
        let turnOn = !(currentDevice()?.isOn ?? false)
        let item = NSButtonTouchBarItem(
            identifier: Identifier.power,
            title: turnOn ? "On" : "Off",
            image: NSImage(systemSymbolName: "power", accessibilityDescription: "Power") ?? NSImage(),
            target: self,
            action: #selector(togglePower)
        )
        item.customizationLabel = "Power"
        item.bezelColor = .controlColor
        item.visibilityPriority = .high
        return item
    }

    private func makeBrightnessPopoverItem() -> NSTouchBarItem {
        makeSliderPopoverItem(
            identifier: Identifier.brightnessPopover,
            label: "Brightness",
            image: NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Brightness"),
            sliderIdentifier: Identifier.brightnessSlider,
            allowPressAndHold: true
        )
    }

    private func makeColorTemperaturePopoverItem() -> NSTouchBarItem {
        makeSliderPopoverItem(
            identifier: Identifier.colorTempPopover,
            label: "Temp",
            image: NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: "Color Temperature"),
            sliderIdentifier: Identifier.colorTempSlider,
            allowPressAndHold: true
        )
    }

    private func makeSliderPopoverItem(
        identifier: NSTouchBarItem.Identifier,
        label: String,
        image: NSImage?,
        sliderIdentifier: NSTouchBarItem.Identifier,
        allowPressAndHold: Bool
    ) -> NSTouchBarItem {
        let item = NSPopoverTouchBarItem(identifier: identifier)
        item.collapsedRepresentationLabel = label
        item.collapsedRepresentationImage = image
        item.customizationLabel = label

        let popoverBar = NSTouchBar()
        popoverBar.delegate = self
        popoverBar.defaultItemIdentifiers = [sliderIdentifier]
        popoverBar.principalItemIdentifier = sliderIdentifier

        item.popoverTouchBar = popoverBar
        if allowPressAndHold {
            item.pressAndHoldTouchBar = popoverBar
        }

        return item
    }

    private func makeBrightnessSliderItem() -> NSTouchBarItem {
        let item = NSSliderTouchBarItem(identifier: Identifier.brightnessSlider)
        let brightness = currentDevice()?.brightness ?? 50
        item.target = self
        item.action = #selector(changeBrightness(_:))
        item.label = nil
        item.slider.minValue = 0
        item.slider.maxValue = 100
        item.slider.doubleValue = Double(brightness)
        item.minimumValueAccessory = NSSliderAccessory(image: NSImage(systemSymbolName: "sun.min.fill", accessibilityDescription: "Dimmer") ?? NSImage())
        item.maximumValueAccessory = NSSliderAccessory(image: NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Brighter") ?? NSImage())
        item.valueAccessoryWidth = .default
        item.customizationLabel = "Brightness"
        item.visibilityPriority = .high
        return item
    }

    private func makeColorTemperatureSliderItem() -> NSTouchBarItem {
        let item = NSSliderTouchBarItem(identifier: Identifier.colorTempSlider)
        let temperature = currentDevice()?.colorTemperature ?? 4000
        item.target = self
        item.action = #selector(changeColorTemperature(_:))
        item.label = "\(temperature)K"
        item.slider.minValue = 2000
        item.slider.maxValue = 9000
        item.slider.doubleValue = Double(temperature)
        item.minimumValueAccessory = NSSliderAccessory(image: NSImage(systemSymbolName: "thermometer.low", accessibilityDescription: "Warmer") ?? NSImage())
        item.maximumValueAccessory = NSSliderAccessory(image: NSImage(systemSymbolName: "thermometer.high", accessibilityDescription: "Cooler") ?? NSImage())
        item.valueAccessoryWidth = .wide
        item.customizationLabel = "Color Temperature"
        item.visibilityPriority = .high
        return item
    }

    private func makeColorPopoverItem() -> NSTouchBarItem {
        let item = NSPopoverTouchBarItem(identifier: Identifier.colorPopover)
        item.collapsedRepresentationLabel = "Color"
        item.collapsedRepresentationImage = NSImage(named: NSImage.touchBarColorPickerFillName) ?? NSImage(systemSymbolName: "paintpalette.fill", accessibilityDescription: "Color")
        item.customizationLabel = "Color"
        item.showsCloseButton = false

        let popoverBar = NSTouchBar()
        popoverBar.delegate = self
        popoverBar.defaultItemIdentifiers = [Identifier.colorPresetPicker]
        popoverBar.principalItemIdentifier = Identifier.colorPresetPicker

        item.popoverTouchBar = popoverBar
        colorPopoverItem = item
        return item
    }

    private func makeColorPresetPickerItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: Identifier.colorPresetPicker)
        let scrubber = NSScrubber()
        scrubber.mode = .fixed
        scrubber.selectionBackgroundStyle = .roundedBackground
        scrubber.showsAdditionalContentIndicators = true
        scrubber.delegate = self
        scrubber.dataSource = self
        scrubber.register(NSScrubberTextItemView.self, forItemIdentifier: NSUserInterfaceItemIdentifier("ColorPresetItem"))

        let layout = NSScrubberFlowLayout()
        layout.itemSpacing = 16
        scrubber.scrubberLayout = layout
        scrubber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrubber.widthAnchor.constraint(equalToConstant: 420)
        ])

        colorPresetScrubber = scrubber
        item.view = scrubber
        item.customizationLabel = "Color Presets"
        item.visibilityPriority = .high
        return item
    }

    @objc private func goBack() {
        deviceStore.selectedDeviceID = nil
        mode = .devices
        invalidateTouchBar()
    }

    @objc private func togglePower() {
        let nextValue = !(currentDevice()?.isOn ?? false)
        updateSelectedDevice(isOn: nextValue)
        Task { @MainActor in
            await controller.setPower(on: nextValue)
        }
    }

    @objc private func changeBrightness(_ sender: Any?) {
        let brightnessValue: Double
        if let sliderItem = sender as? NSSliderTouchBarItem {
            brightnessValue = sliderItem.slider.doubleValue
        } else if let slider = sender as? NSSlider {
            brightnessValue = slider.doubleValue
        } else {
            return
        }

        let brightness = Int(brightnessValue.rounded())
        updateSelectedDevice(brightness: brightness)

        brightnessTask?.cancel()
        brightnessTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }
            await controller.setBrightness(brightness)
        }
    }

    @objc private func changeColorTemperature(_ sender: Any?) {
        let temperatureValue: Double
        if let sliderItem = sender as? NSSliderTouchBarItem {
            temperatureValue = sliderItem.slider.doubleValue
        } else if let slider = sender as? NSSlider {
            temperatureValue = slider.doubleValue
        } else {
            return
        }

        let temperature = Int(temperatureValue.rounded())
        if let sliderItem = sender as? NSSliderTouchBarItem {
            sliderItem.label = "\(temperature)K"
        }
        updateSelectedDevice(colorTemperature: temperature)

        colorTemperatureTask?.cancel()
        colorTemperatureTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }
            await controller.setColorTemperature(temperature)
        }
    }

    private func selectDevice(at index: Int) {
        guard index >= 0, index < deviceStore.devices.count else { return }
        let device = deviceStore.devices[index]
        deviceStore.selectedDeviceID = device.id
        deviceStore.selectedGroupID = nil
        mode = .device(device.id)
        invalidateTouchBar()
    }

    private func selectColorPreset(at index: Int) {
        guard let preset = DevicePreset(rawValue: index) else { return }
        updateSelectedDevice(color: preset.color)
        Task { @MainActor in
            await controller.setColor(preset.color)
            colorPopoverItem?.dismissPopover(nil)
        }
    }

    private func structuralSignature() -> String {
        let selected = deviceStore.selectedDeviceID ?? "none"
        let ids = deviceStore.devices.map(\.id).joined(separator: "|")
        let capabilities = currentDevice().map {
            [
                $0.supportsBrightness ? "b" : "-",
                $0.supportsColorTemperature ? "t" : "-",
                $0.supportsColor ? "c" : "-"
            ].joined()
        } ?? "---"
        return "\(selected)#\(capabilities)#\(ids)"
    }

    private func updateSelectedDevice(
        isOn: Bool? = nil,
        brightness: Int? = nil,
        colorTemperature: Int? = nil,
        color: DeviceColor? = nil
    ) {
        guard let selectedID = deviceStore.selectedDeviceID,
              let index = deviceStore.devices.firstIndex(where: { $0.id == selectedID }) else { return }
        if let isOn {
            deviceStore.devices[index].isOn = isOn
        }
        if let brightness {
            deviceStore.devices[index].brightness = brightness
        }
        if let colorTemperature {
            deviceStore.devices[index].colorTemperature = colorTemperature
        }
        if let color {
            deviceStore.devices[index].color = color
        }
    }

    func numberOfItems(for scrubber: NSScrubber) -> Int {
        if scrubber === colorPresetScrubber {
            return DevicePreset.allCases.count
        }
        return deviceStore.devices.count
    }

    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
        if scrubber === colorPresetScrubber {
            let identifier = NSUserInterfaceItemIdentifier("ColorPresetItem")
            let itemView = scrubber.makeItem(withIdentifier: identifier, owner: self) as? NSScrubberTextItemView ?? NSScrubberTextItemView()
            let preset = DevicePreset.allCases[index]
            itemView.title = preset.title
            itemView.textField.alignment = .center
            return itemView
        }

        let identifier = NSUserInterfaceItemIdentifier("DeviceTextItem")
        let itemView = scrubber.makeItem(withIdentifier: identifier, owner: self) as? NSScrubberTextItemView ?? NSScrubberTextItemView()
        let device = deviceStore.devices[index]
        itemView.title = device.name
        itemView.textField.alignment = .center
        itemView.textField.lineBreakMode = .byTruncatingTail
        return itemView
    }

    func scrubber(_ scrubber: NSScrubber, didSelectItemAt selectedIndex: Int) {
        if scrubber === colorPresetScrubber {
            selectColorPreset(at: selectedIndex)
        } else if scrubber === deviceScrubber {
            selectDevice(at: selectedIndex)
        }
    }
}
