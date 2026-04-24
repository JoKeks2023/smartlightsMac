import SwiftUI
import AppKit

struct TouchBarBridge: NSViewRepresentable {
    @ObservedObject var deviceStore: DeviceStore
    @ObservedObject var controller: GoveeController
    @ObservedObject var settings: SettingsStore

    func makeCoordinator() -> TouchBarCoordinator {
        TouchBarCoordinator(deviceStore: deviceStore, controller: controller, settings: settings)
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
    private let settings: SettingsStore

    private var brightnessTask: Task<Void, Never>?
    private var colorTemperatureTask: Task<Void, Never>?
    private var colorTask: Task<Void, Never>?
    private weak var deviceScrubber: NSScrubber?
    private weak var colorPopoverItem: NSPopoverTouchBarItem?
    private weak var savedColorStripView: TouchBarSavedColorStripView?
    private var currentTouchBarColor = DeviceColor(r: 255, g: 140, b: 82)

    private let accentColor = NSColor.controlAccentColor

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
        static let colorSpectrum = NSTouchBarItem.Identifier("com.govee.mac.touchbar.colorSpectrum")
        static let colorSave = NSTouchBarItem.Identifier("com.govee.mac.touchbar.colorSave")
        static let savedColors = NSTouchBarItem.Identifier("com.govee.mac.touchbar.savedColors")
    }

    private var mode: TouchBarMode = .devices
    private var lastStructuralSignature = ""

    init(deviceStore: DeviceStore, controller: GoveeController, settings: SettingsStore) {
        self.deviceStore = deviceStore
        self.controller = controller
        self.settings = settings
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
        case Identifier.colorSpectrum:
            return makeColorSpectrumItem()
        case Identifier.colorSave:
            return makeSaveColorItem()
        case Identifier.savedColors:
            return makeSavedColorsItem()
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
        layout.itemSpacing = 28
        scrubber.scrubberLayout = layout
        scrubber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrubber.widthAnchor.constraint(equalToConstant: 620)
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
        let brightness = currentDevice()?.brightness ?? 50
        let item = NSCustomTouchBarItem(identifier: Identifier.brightnessSlider)
        let view = TouchBarValueSliderView(
            leadingSymbolName: "sun.min.fill",
            trailingSymbolName: "sun.max.fill",
            accentColor: accentColor,
            showsValueLabel: false,
            valueFormatter: { _ in "" }
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 360),
            view.heightAnchor.constraint(equalToConstant: 30)
        ])
        view.configure(minValue: 0, maxValue: 100, value: Double(brightness))
        view.onValueChanged = { [weak self] value in
            self?.handleBrightnessChange(value: value)
        }
        item.view = view
        item.customizationLabel = "Brightness"
        item.visibilityPriority = .high
        return item
    }

    private func makeColorTemperatureSliderItem() -> NSTouchBarItem {
        let temperature = currentDevice()?.colorTemperature ?? 4000
        let item = NSCustomTouchBarItem(identifier: Identifier.colorTempSlider)
        let view = TouchBarValueSliderView(
            leadingSymbolName: "thermometer.low",
            trailingSymbolName: "thermometer.high",
            accentColor: accentColor,
            showsValueLabel: true,
            valueFormatter: { "\(Int($0.rounded()))K" }
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 390),
            view.heightAnchor.constraint(equalToConstant: 30)
        ])
        view.configure(minValue: 2000, maxValue: 9000, value: Double(temperature))
        view.onValueChanged = { [weak self] value in
            self?.handleColorTemperatureChange(value: value)
        }
        item.view = view
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
        popoverBar.defaultItemIdentifiers = [Identifier.colorSpectrum, Identifier.colorSave, Identifier.savedColors]
        popoverBar.principalItemIdentifier = Identifier.colorSpectrum

        item.popoverTouchBar = popoverBar
        colorPopoverItem = item
        return item
    }

    private func makeColorSpectrumItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: Identifier.colorSpectrum)
        let initialColor = currentDevice()?.color ?? DeviceColor(r: 255, g: 140, b: 82)
        currentTouchBarColor = initialColor
        let hsv = HSVColor.from(rgb: initialColor)
        let view = TouchBarColorSpectrumView(initialHue: hsv.hue)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 420),
            view.heightAnchor.constraint(equalToConstant: 30)
        ])
        view.onHueChanged = { [weak self] hue in
            self?.handleColorChange(hue: hue)
        }
        item.view = view
        item.customizationLabel = "Color"
        item.visibilityPriority = .high
        return item
    }

    private func makeSaveColorItem() -> NSTouchBarItem {
        let item = NSButtonTouchBarItem(
            identifier: Identifier.colorSave,
            image: NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: "Save Color") ?? NSImage(),
            target: self,
            action: #selector(saveCurrentTouchBarColor)
        )
        item.customizationLabel = "Save Color"
        item.bezelColor = .controlColor
        item.visibilityPriority = .high
        return item
    }

    private func makeSavedColorsItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: Identifier.savedColors)
        let view = TouchBarSavedColorStripView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 220),
            view.heightAnchor.constraint(equalToConstant: 30)
        ])
        view.configure(presets: settings.savedColorPresets)
        view.onSelect = { [weak self] preset in
            self?.applySavedColorPreset(preset)
        }
        savedColorStripView = view
        item.view = view
        item.customizationLabel = "Saved Colors"
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

    private func handleBrightnessChange(value: Double) {
        let brightness = Int(value.rounded())
        updateSelectedDevice(brightness: brightness)

        brightnessTask?.cancel()
        brightnessTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }
            await controller.setBrightness(brightness)
        }
    }

    private func handleColorTemperatureChange(value: Double) {
        let temperature = Int(value.rounded())
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

    private func handleColorChange(hue: Double) {
        let rgb = HSVColor(hue: hue, saturation: 0.92, brightness: 1.0).rgb
        currentTouchBarColor = rgb
        updateSelectedDevice(color: rgb)
        colorTask?.cancel()
        colorTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 45_000_000)
            guard !Task.isCancelled else { return }
            await controller.setColor(rgb)
        }
    }

    @objc private func saveCurrentTouchBarColor() {
        settings.saveColorPreset(currentTouchBarColor)
        savedColorStripView?.configure(presets: settings.savedColorPresets)
    }

    private func applySavedColorPreset(_ preset: SavedColorPreset) {
        currentTouchBarColor = preset.color
        updateSelectedDevice(color: preset.color)
        colorTask?.cancel()
        colorTask = Task { @MainActor in
            await controller.setColor(preset.color)
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
        return deviceStore.devices.count
    }

    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
        let identifier = NSUserInterfaceItemIdentifier("DeviceTextItem")
        let itemView = scrubber.makeItem(withIdentifier: identifier, owner: self) as? NSScrubberTextItemView ?? NSScrubberTextItemView()
        let device = deviceStore.devices[index]
        itemView.title = device.name
        itemView.textField.alignment = .center
        itemView.textField.lineBreakMode = .byTruncatingTail
        itemView.textField.font = .systemFont(ofSize: 0, weight: .semibold)
        return itemView
    }

    func scrubber(_ scrubber: NSScrubber, didSelectItemAt selectedIndex: Int) {
        if scrubber === deviceScrubber {
            selectDevice(at: selectedIndex)
        }
    }
}

final class TouchBarValueSliderView: NSView {
    var onValueChanged: ((Double) -> Void)?

    private let leadingImageView = NSImageView()
    private let trailingImageView = NSImageView()
    private let valueLabel = NSTextField(labelWithString: "")
    private let trackLayer = CALayer()
    private let fillLayer = CALayer()
    private let knobLayer = CALayer()

    private let accentColor: NSColor
    private let showsValueLabel: Bool
    private let valueFormatter: (Double) -> String

    private var minValue: Double = 0
    private var maxValue: Double = 100
    private var currentValue: Double = 50
    private var isDragging = false

    init(
        leadingSymbolName: String,
        trailingSymbolName: String,
        accentColor: NSColor,
        showsValueLabel: Bool,
        valueFormatter: @escaping (Double) -> String
    ) {
        self.accentColor = accentColor
        self.showsValueLabel = showsValueLabel
        self.valueFormatter = valueFormatter
        super.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = false
        allowedTouchTypes = [.direct]

        configureImageView(leadingImageView, symbolName: leadingSymbolName)
        configureImageView(trailingImageView, symbolName: trailingSymbolName)

        valueLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.isHidden = !showsValueLabel
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        [leadingImageView, trailingImageView, valueLabel].forEach(addSubview)
        [leadingImageView, trailingImageView, valueLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        trackLayer.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        trackLayer.cornerRadius = 7
        fillLayer.backgroundColor = accentColor.cgColor
        fillLayer.cornerRadius = 7
        knobLayer.backgroundColor = NSColor.white.withAlphaComponent(0.96).cgColor
        knobLayer.cornerRadius = 9
        knobLayer.shadowColor = NSColor.black.withAlphaComponent(0.25).cgColor
        knobLayer.shadowOpacity = 1
        knobLayer.shadowRadius = 3
        knobLayer.shadowOffset = CGSize(width: 0, height: 1)

        layer?.addSublayer(trackLayer)
        layer?.addSublayer(fillLayer)
        layer?.addSublayer(knobLayer)

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        clickGesture.allowedTouchTypes = [.direct]
        panGesture.allowedTouchTypes = [.direct]
        panGesture.buttonMask = 0
        addGestureRecognizer(clickGesture)
        addGestureRecognizer(panGesture)

        NSLayoutConstraint.activate([
            leadingImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            leadingImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            leadingImageView.widthAnchor.constraint(equalToConstant: 16),
            leadingImageView.heightAnchor.constraint(equalToConstant: 16),

            trailingImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            trailingImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailingImageView.widthAnchor.constraint(equalToConstant: 16),
            trailingImageView.heightAnchor.constraint(equalToConstant: 16),

            valueLabel.trailingAnchor.constraint(equalTo: trailingImageView.leadingAnchor, constant: -10),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: showsValueLabel ? 52 : 0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: showsValueLabel ? 390 : 360, height: 30)
    }

    func configure(minValue: Double, maxValue: Double, value: Double) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.currentValue = max(minValue, min(maxValue, value))
        updateLayers(animated: false)
    }

    override func layout() {
        super.layout()
        updateLayers(animated: false)
    }

    private func configureImageView(_ imageView: NSImageView, symbolName: String) {
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        imageView.contentTintColor = .secondaryLabelColor
    }

    private var trackRect: CGRect {
        let leftInset: CGFloat = 30
        let rightInset: CGFloat = showsValueLabel ? 78 : 30
        return CGRect(x: leftInset, y: bounds.midY - 7, width: max(80, bounds.width - leftInset - rightInset), height: 14)
    }

    private var progress: CGFloat {
        guard maxValue > minValue else { return 0 }
        return CGFloat((currentValue - minValue) / (maxValue - minValue))
    }

    private func updateLayers(animated: Bool) {
        guard bounds.width > 0 else { return }
        let track = trackRect
        let knobSize = CGSize(width: 18, height: 18)
        let knobX = track.minX + progress * track.width - knobSize.width / 2
        let knobFrame = CGRect(x: knobX, y: bounds.midY - knobSize.height / 2, width: knobSize.width, height: knobSize.height)
        let fillFrame = CGRect(x: track.minX, y: track.minY, width: max(14, knobFrame.midX - track.minX), height: track.height)

        valueLabel.stringValue = valueFormatter(currentValue)

        let applyFrames = {
            self.trackLayer.frame = track
            self.fillLayer.frame = fillFrame
            self.knobLayer.frame = knobFrame
        }

        if animated && !isDragging {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.trackLayer.frame = track
                self.fillLayer.frame = fillFrame
                self.knobLayer.frame = knobFrame
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            applyFrames()
            CATransaction.commit()
        }
    }

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        setValue(for: gesture.location(in: self), animated: true, notify: true)
    }

    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isDragging = true
            setValue(for: gesture.location(in: self), animated: false, notify: true)
        case .changed:
            setValue(for: gesture.location(in: self), animated: false, notify: true)
        default:
            isDragging = false
            setValue(for: gesture.location(in: self), animated: true, notify: true)
        }
    }

    private func setValue(for location: CGPoint, animated: Bool, notify: Bool) {
        let track = trackRect
        guard track.width > 0 else { return }
        let clampedX = min(max(location.x, track.minX), track.maxX)
        let normalized = (clampedX - track.minX) / track.width
        let value = minValue + Double(normalized) * (maxValue - minValue)
        currentValue = value
        updateLayers(animated: animated)
        if notify {
            onValueChanged?(value)
        }
    }
}

final class TouchBarColorSpectrumView: NSView {
    var onHueChanged: ((Double) -> Void)?

    private let trackLayer = CALayer()
    private let knobLayer = CALayer()
    private let gradientLayer = CAGradientLayer()
    private var hue: Double

    init(initialHue: Double) {
        self.hue = initialHue
        super.init(frame: .zero)

        wantsLayer = true
        allowedTouchTypes = [.direct]
        layer?.cornerRadius = 15
        layer?.masksToBounds = false

        gradientLayer.colors = stride(from: 0.0, through: 1.0, by: 0.125).map {
            let rgb = HSVColor(hue: $0, saturation: 1, brightness: 1).rgb
            return NSColor(
                red: CGFloat(rgb.r) / 255.0,
                green: CGFloat(rgb.g) / 255.0,
                blue: CGFloat(rgb.b) / 255.0,
                alpha: 1
            ).cgColor
        }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = 12

        trackLayer.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        trackLayer.cornerRadius = 12
        knobLayer.backgroundColor = NSColor.white.cgColor
        knobLayer.cornerRadius = 10
        knobLayer.shadowColor = NSColor.black.withAlphaComponent(0.24).cgColor
        knobLayer.shadowOpacity = 1
        knobLayer.shadowRadius = 3
        knobLayer.shadowOffset = CGSize(width: 0, height: 1)

        layer?.addSublayer(trackLayer)
        layer?.addSublayer(gradientLayer)
        layer?.addSublayer(knobLayer)

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        clickGesture.allowedTouchTypes = [.direct]
        panGesture.allowedTouchTypes = [.direct]
        panGesture.buttonMask = 0
        addGestureRecognizer(clickGesture)
        addGestureRecognizer(panGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 420, height: 30)
    }

    override func layout() {
        super.layout()
        let frame = CGRect(x: 6, y: bounds.midY - 12, width: bounds.width - 12, height: 24)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = frame
        gradientLayer.frame = frame
        knobLayer.frame = knobFrame(in: frame)
        CATransaction.commit()
    }

    private func knobFrame(in track: CGRect) -> CGRect {
        let x = track.minX + CGFloat(hue) * track.width - 10
        return CGRect(x: x, y: bounds.midY - 10, width: 20, height: 20)
    }

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        updateHue(at: gesture.location(in: self))
    }

    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        updateHue(at: gesture.location(in: self))
    }

    private func updateHue(at location: CGPoint) {
        let track = trackLayer.frame
        guard track.width > 0 else { return }
        let clampedX = min(max(location.x, track.minX), track.maxX)
        hue = Double((clampedX - track.minX) / track.width)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        knobLayer.frame = knobFrame(in: track)
        CATransaction.commit()
        onHueChanged?(hue)
    }
}

final class TouchBarSavedColorStripView: NSView {
    var onSelect: ((SavedColorPreset) -> Void)?

    private var presets: [SavedColorPreset] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 220, height: 30)
    }

    func configure(presets: [SavedColorPreset]) {
        self.presets = Array(presets.prefix(6))
        subviews.forEach { $0.removeFromSuperview() }

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        for preset in self.presets {
            let button = NSButton(title: "", target: self, action: #selector(selectPreset(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(preset.id)
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 10
            button.layer?.backgroundColor = NSColor(
                red: CGFloat(preset.color.r) / 255.0,
                green: CGFloat(preset.color.g) / 255.0,
                blue: CGFloat(preset.color.b) / 255.0,
                alpha: 1
            ).cgColor
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 20),
                button.heightAnchor.constraint(equalToConstant: 20)
            ])
            stack.addArrangedSubview(button)
        }

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @objc private func selectPreset(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let preset = presets.first(where: { $0.id == id }) else { return }
        onSelect?(preset)
    }
}
