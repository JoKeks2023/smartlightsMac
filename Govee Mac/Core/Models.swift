import Foundation

// MARK: - Models

enum TransportKind: String, Codable, Hashable {
    case cloud, lan, homeKit, homeAssistant, dmx, hue, wled, lifx
}

enum DMXProtocolType: String, Codable, Hashable {
    case artnet = "ArtNet"
    case sacn = "sACN"
}

struct DeviceColor: Codable, Hashable {
    var r: Int
    var g: Int
    var b: Int
}

struct SavedColorPreset: Codable, Hashable, Identifiable {
    let id: String
    var color: DeviceColor

    init(id: String = UUID().uuidString, color: DeviceColor) {
        self.id = id
        self.color = color
    }
}

enum DMXChannelFunction: String, Codable, CaseIterable {
    case dimmer = "Dimmer"
    case red = "Red"
    case green = "Green"
    case blue = "Blue"
    case white = "White"
    case amber = "Amber"
    case strobe = "Strobe"
    case unused = "Unused"
}

struct DMXCustomChannel: Codable, Hashable, Identifiable {
    let id: UUID
    var channelNumber: Int // Relative to start (0-based offset)
    var function: DMXChannelFunction
    
    init(id: UUID = UUID(), channelNumber: Int, function: DMXChannelFunction) {
        self.id = id
        self.channelNumber = channelNumber
        self.function = function
    }
}

struct DMXProfile: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var channels: [DMXCustomChannel]
    var isBuiltIn: Bool
    
    init(id: String = UUID().uuidString, name: String, channels: [DMXCustomChannel], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.channels = channels
        self.isBuiltIn = isBuiltIn
    }
    
    var channelCount: Int {
        channels.isEmpty ? 1 : (channels.map { $0.channelNumber }.max() ?? 0) + 1
    }
    
    // Built-in profiles
    static var builtInProfiles: [DMXProfile] {
        [
            DMXProfile(
                id: "builtin_single",
                name: "Single Dimmer (1 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .dimmer)
                ],
                isBuiltIn: true
            ),
            DMXProfile(
                id: "builtin_rgb",
                name: "RGB (3 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .red),
                    DMXCustomChannel(channelNumber: 1, function: .green),
                    DMXCustomChannel(channelNumber: 2, function: .blue)
                ],
                isBuiltIn: true
            ),
            DMXProfile(
                id: "builtin_rgbw",
                name: "RGBW (4 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .red),
                    DMXCustomChannel(channelNumber: 1, function: .green),
                    DMXCustomChannel(channelNumber: 2, function: .blue),
                    DMXCustomChannel(channelNumber: 3, function: .white)
                ],
                isBuiltIn: true
            ),
            DMXProfile(
                id: "builtin_rgba",
                name: "RGBA (4 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .red),
                    DMXCustomChannel(channelNumber: 1, function: .green),
                    DMXCustomChannel(channelNumber: 2, function: .blue),
                    DMXCustomChannel(channelNumber: 3, function: .amber)
                ],
                isBuiltIn: true
            ),
            DMXProfile(
                id: "builtin_rgbDimmer",
                name: "RGB + Dimmer (4 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .dimmer),
                    DMXCustomChannel(channelNumber: 1, function: .red),
                    DMXCustomChannel(channelNumber: 2, function: .green),
                    DMXCustomChannel(channelNumber: 3, function: .blue)
                ],
                isBuiltIn: true
            ),
            DMXProfile(
                id: "builtin_extended",
                name: "Extended RGBWA (6 ch)",
                channels: [
                    DMXCustomChannel(channelNumber: 0, function: .dimmer),
                    DMXCustomChannel(channelNumber: 1, function: .red),
                    DMXCustomChannel(channelNumber: 2, function: .green),
                    DMXCustomChannel(channelNumber: 3, function: .blue),
                    DMXCustomChannel(channelNumber: 4, function: .white),
                    DMXCustomChannel(channelNumber: 5, function: .amber)
                ],
                isBuiltIn: true
            )
        ]
    }
}

struct DMXChannelMapping: Codable, Hashable {
    var universe: Int
    var startChannel: Int // 1-512
    var profileID: String // Reference to DMXProfile
    
    // Legacy support - will be converted to custom profiles
    var channelMode: DMXChannelMode?
    
    enum DMXChannelMode: String, Codable {
        case single      // Single channel dimmer (1 channel)
        case rgb         // RGB (3 channels: R, G, B)
        case rgbw        // RGBW (4 channels: R, G, B, W)
        case rgba        // RGBA (4 channels: R, G, B, Amber)
        case rgbDimmer   // RGB + Dimmer (4 channels: Dimmer, R, G, B)
        case extended    // Extended mode (Dimmer, R, G, B, W, Amber, etc.)
    }
    
    init(universe: Int, startChannel: Int, profileID: String) {
        self.universe = universe
        self.startChannel = startChannel
        self.profileID = profileID
        self.channelMode = nil
    }
    
    // Legacy initializer
    init(universe: Int, startChannel: Int, channelMode: DMXChannelMode) {
        self.universe = universe
        self.startChannel = startChannel
        self.channelMode = channelMode
        // Map to built-in profile
        switch channelMode {
        case .single: self.profileID = "builtin_single"
        case .rgb: self.profileID = "builtin_rgb"
        case .rgbw: self.profileID = "builtin_rgbw"
        case .rgba: self.profileID = "builtin_rgba"
        case .rgbDimmer: self.profileID = "builtin_rgbDimmer"
        case .extended: self.profileID = "builtin_extended"
        }
    }
}

struct GoveeDevice: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var model: String?
    var ipAddress: String?
    var online: Bool
    var supportsBrightness: Bool
    var supportsColor: Bool
    var supportsColorTemperature: Bool
    var transports: Set<TransportKind>
    var primaryTransport: TransportKind { transports.first ?? .cloud }
    var isOn: Bool?
    var brightness: Int?
    var color: DeviceColor?
    var colorTemperature: Int?
    var dmxMapping: DMXChannelMapping?
}

struct DeviceGroup: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var memberIDs: [String]
    
    init(id: String = UUID().uuidString, name: String, memberIDs: [String]) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
    }
}

// MARK: - Protocol Errors

enum SmartLightError: LocalizedError {
    case featureNotSupported(String)
    case notImplemented(String)
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .featureNotSupported(let detail):
            return "Feature not supported: \(detail)"
        case .notImplemented(let detail):
            return "Not yet implemented: \(detail)"
        case .authenticationRequired:
            return "Authentication required. Please configure device credentials."
        }
    }
}
