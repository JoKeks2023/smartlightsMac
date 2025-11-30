import WidgetKit
import SwiftUI

struct GoveeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoveeWidgetEntry {
        GoveeWidgetEntry(date: Date(), devices: [
            GoveeDevice(id: "1", name: "Living Room", model: "H6001", ipAddress: nil, online: true, 
                       supportsBrightness: true, supportsColor: true, supportsColorTemperature: false,
                       transports: [.cloud], isOn: true, brightness: 75, color: nil, colorTemperature: nil)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (GoveeWidgetEntry) -> ()) {
        loadDevices { devices in
            let entry = GoveeWidgetEntry(date: Date(), devices: devices)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        loadDevices { devices in
            let entry = GoveeWidgetEntry(date: Date(), devices: devices)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 5))) // Update every 5 minutes
            completion(timeline)
        }
    }
    
    private func loadDevices(completion: @escaping ([GoveeDevice]) -> Void) {
        // Load devices from shared container
        if let sharedDefaults = UserDefaults(suiteName: "group.com.govee.mac"),
           let data = sharedDefaults.data(forKey: "cachedDevices"),
           let devices = try? JSONDecoder().decode([GoveeDevice].self, from: data) {
            completion(devices)
        } else {
            completion([])
        }
    }
}

struct GoveeWidgetEntry: TimelineEntry {
    let date: Date
    let devices: [GoveeDevice]
}

struct GoveeWidgetEntryView : View {
    var entry: GoveeWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(devices: entry.devices)
        case .systemMedium:
            MediumWidgetView(devices: entry.devices)
        case .systemLarge:
            LargeWidgetView(devices: entry.devices)
        default:
            SmallWidgetView(devices: entry.devices)
        }
    }
}

struct SmallWidgetView: View {
    let devices: [GoveeDevice]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Govee")
                    .font(.headline)
                    .bold()
            }
            
            if let device = devices.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    HStack {
                        Circle()
                            .fill(device.isOn == true ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(device.isOn == true ? "On" : "Off")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let brightness = device.brightness {
                        Text("\(brightness)%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.05)], 
                          startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct MediumWidgetView: View {
    let devices: [GoveeDevice]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Govee Lights")
                    .font(.headline)
                    .bold()
                Spacer()
                Text("\(devices.count)")
                    .font(.caption)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            HStack(spacing: 12) {
                ForEach(devices.prefix(3)) { device in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.caption)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(device.isOn == true ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)
                            if let brightness = device.brightness {
                                Text("\(brightness)%")
                                    .font(.caption2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.05)], 
                          startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct LargeWidgetView: View {
    let devices: [GoveeDevice]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("Govee Control Center")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            Divider()
            
            ForEach(devices.prefix(6)) { device in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let model = device.model {
                            Text(model)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(device.isOn == true ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(device.isOn == true ? "On" : "Off")
                                .font(.caption)
                        }
                        if let brightness = device.brightness {
                            Text("\(brightness)%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.05)], 
                          startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

@main
struct GoveeWidget: Widget {
    let kind: String = "GoveeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoveeWidgetProvider()) { entry in
            GoveeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Govee Lights")
        .description("Quick view of your Govee lights status")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    GoveeWidget()
} timeline: {
    GoveeWidgetEntry(date: .now, devices: [
        GoveeDevice(id: "1", name: "Living Room", model: "H6001", ipAddress: nil, online: true, 
                   supportsBrightness: true, supportsColor: true, supportsColorTemperature: false,
                   transports: [.cloud], isOn: true, brightness: 75, color: nil, colorTemperature: nil)
    ])
}
