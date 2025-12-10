# DMX Control Setup Guide

This guide explains how to control your Govee smart lights using DMX lighting control software via ArtNet or sACN (streaming ACN/E1.31) protocols.

## Overview

The Govee Mac app can act as a **DMX receiver**, listening for incoming ArtNet or sACN packets on your network and translating DMX channel values into commands for your Govee lights. This allows you to control your Govee lights from professional lighting control software like:

- QLC+ (Free, cross-platform)
- LightKey (macOS)
- MagicQ (Free for small setups)
- GrandMA
- ETC Eos
- Any software supporting ArtNet or sACN output

## How It Works

1. **DMX Receiver**: The app listens on the network for DMX packets
2. **Channel Mapping**: You configure which DMX channels control each Govee device
3. **Translation**: DMX values (0-255) are translated to Govee commands
4. **Govee Control**: Commands are sent to your Govee lights via Cloud API or LAN

```
[Lighting Software] --ArtNet/sACN--> [Govee Mac App] --Cloud/LAN--> [Govee Lights]
     (DMX Sender)      (Network)      (DMX Receiver)    (Commands)     (Physical)
```

## Setup Instructions

### Step 1: Enable DMX Receiver

1. Open **Govee Mac** application
2. Go to **Settings** (⌘,)
3. Scroll to **DMX Control (ArtNet/sACN)** section
4. Toggle **Enable DMX Receiver** to ON
5. Select your protocol:
   - **ArtNet** - Port 6454, widely supported
   - **sACN (E1.31)** - Port 5568, modern standard

The app will start listening for DMX packets immediately.

### Step 2: Configure Your Lighting Software

Configure your DMX software to send ArtNet or sACN to your Mac:

#### Example: QLC+ Setup

1. Open QLC+
2. Go to **Inputs/Outputs** tab
3. Select **ArtNet** or **sACN** plugin
4. Configure output universe (e.g., Universe 0)
5. Set the target IP to your Mac's IP address or use broadcast (255.255.255.255)

#### Example: LightKey Setup

1. Open LightKey
2. Go to **Preferences → DMX Output**
3. Add new output: **ArtNet** or **sACN**
4. Set universe number
5. Configure the Mac's IP or use broadcast

### Step 3: Map Govee Devices to DMX Channels

For each Govee device you want to control via DMX:

1. In Govee Mac, **right-click** on a device in the device list
2. Select **Configure DMX**
3. Configure the following:

   - **Universe**: DMX universe number (0-32767)
   - **Start Channel**: First DMX channel (1-512)
   - **Channel Mode**: How channels are mapped

4. Click **Save**

### Channel Modes

Choose the mode that matches your lighting software's fixture profile:

#### Single Dimmer (1 channel)
- **Channel 1**: Dimmer/Brightness (0-255)
- Best for: Simple on/off and dimming control

#### RGB (3 channels)
- **Channel 1**: Red (0-255)
- **Channel 2**: Green (0-255)
- **Channel 3**: Blue (0-255)
- Best for: Color mixing without separate dimmer

#### RGBW (4 channels)
- **Channel 1**: Red (0-255)
- **Channel 2**: Green (0-255)
- **Channel 3**: Blue (0-255)
- **Channel 4**: White (0-255)
- Best for: RGBW fixtures with separate white

#### RGBA (4 channels)
- **Channel 1**: Red (0-255)
- **Channel 2**: Green (0-255)
- **Channel 3**: Blue (0-255)
- **Channel 4**: Amber (0-255)
- Best for: RGBA fixtures

#### RGB + Dimmer (4 channels)
- **Channel 1**: Dimmer (0-255)
- **Channel 2**: Red (0-255)
- **Channel 3**: Green (0-255)
- **Channel 4**: Blue (0-255)
- Best for: Standard RGB fixtures with master dimmer

#### Extended (6 channels)
- **Channel 1**: Dimmer (0-255)
- **Channel 2**: Red (0-255)
- **Channel 3**: Green (0-255)
- **Channel 4**: Blue (0-255)
- **Channel 5**: White (0-255)
- **Channel 6**: Amber (0-255)
- Best for: Advanced RGBWA fixtures

## Example Configurations

### Example 1: Simple RGB Strip

**Scenario**: Control a Govee RGB strip on Universe 0, Channels 1-3

```
Universe: 0
Start Channel: 1
Mode: RGB (3 channels)

Channel Layout:
- Ch1: Red
- Ch2: Green
- Ch3: Blue
```

In your lighting software:
- Patch an RGB fixture to Universe 0, Channel 1
- Control red, green, and blue individually

### Example 2: Multiple Lights with Dimmer

**Scenario**: Control 3 Govee lights, each with master dimmer + RGB

**Light 1**:
```
Universe: 0
Start Channel: 1
Mode: RGB + Dimmer (4 channels)
Channels: 1-4
```

**Light 2**:
```
Universe: 0
Start Channel: 5
Mode: RGB + Dimmer (4 channels)
Channels: 5-8
```

**Light 3**:
```
Universe: 0
Start Channel: 9
Mode: RGB + Dimmer (4 channels)
Channels: 9-12
```

### Example 3: Large Setup with Multiple Universes

**Scenario**: 15 lights across 2 universes

**Lights 1-10**: Universe 0, Channels 1-40 (4 channels each)
**Lights 11-15**: Universe 1, Channels 1-20 (4 channels each)

## Network Configuration

### Firewall Settings

Ensure your Mac's firewall allows incoming UDP packets:

1. **System Settings → Network → Firewall**
2. Allow incoming connections for **Govee Mac**

### Port Information

- **ArtNet**: UDP port 6454
- **sACN**: UDP port 5568

### Multicast (sACN)

sACN uses multicast addresses:
- Base: `239.255.0.0/24`
- Universe 1: `239.255.0.1`
- Universe 2: `239.255.0.2`
- etc.

## Troubleshooting

### No DMX Control

1. **Check DMX Receiver is Enabled**
   - Go to Settings, verify "Enable DMX Receiver" is ON

2. **Verify Network Connection**
   - Ensure lighting software and Govee Mac are on the same network
   - Check firewall settings

3. **Confirm Universe & Channels**
   - Double-check universe numbers match
   - Verify channel ranges don't overlap unintentionally

4. **Check Protocol Match**
   - If using ArtNet, both sender and receiver must use ArtNet
   - If using sACN, both must use sACN

5. **Test with Govee API First**
   - Ensure your Govee lights work with Cloud API or LAN control
   - DMX requires a working Govee connection

### Latency Issues

- **Use LAN Control**: Enable "Prefer LAN when available" in Settings
- **Reduce DMX Update Rate**: In your lighting software, reduce the update frequency
- **Check Network**: WiFi congestion can cause delays

### Lights Not Responding to Color Changes

1. Verify the device supports color (not all Govee devices do)
2. Check the channel mode matches your DMX fixture profile
3. Ensure DMX values are not all zero

## Technical Details

### ArtNet Packet Format

- **Port**: 6454 (UDP)
- **Header**: "Art-Net\0"
- **OpCode**: 0x5000 (ArtDMX)
- **Protocol Version**: 14
- **Universe**: 15-bit value
- **Data**: Up to 512 bytes

### sACN Packet Format

- **Port**: 5568 (UDP)
- **Root Layer**: ACN packet identifier
- **Framing Layer**: Universe, priority, sequence
- **DMP Layer**: DMX data (up to 512 slots)
- **START Code**: Always 0x00

### DMX to Govee Mapping

DMX values (0-255) are mapped to Govee controls:

- **Brightness**: `DMX_value / 255 * 100` (percentage)
- **Power**: ON if any DMX channel > 0, OFF if all channels = 0
- **RGB Color**: Direct 0-255 mapping to RGB values

## Performance Notes

- **Update Rate**: The receiver processes packets as fast as they arrive
- **Command Batching**: Multiple channel changes are sent as single commands when possible
- **Rate Limiting**: Govee Cloud API has rate limits (60 req/min)
- **LAN Recommended**: For best performance, use LAN control with compatible devices

## Advanced Usage

### DMX Universe Planning

Plan your universe layout carefully:

```
Universe 0:
  Channels 1-4:    Living Room Light 1 (RGBD)
  Channels 5-8:    Living Room Light 2 (RGBD)
  Channels 9-12:   Kitchen Light 1 (RGBD)
  ...

Universe 1:
  Channels 1-3:    Bedroom Strip 1 (RGB)
  Channels 4-6:    Bedroom Strip 2 (RGB)
  ...
```

### Integration with Other Systems

You can integrate Govee lights into larger lighting systems:

1. **Theater Productions**: Control Govee as part of stage lighting
2. **Architectural Lighting**: Integrate with building automation
3. **Live Events**: Sync with music and video
4. **Home Automation**: Combine with other DMX-controlled devices

## Limitations

- **Cloud API Rate Limits**: Limited to 60 requests/minute
- **Latency**: Cloud API has higher latency than LAN
- **Device Support**: Not all Govee devices support all features
- **One-Way Control**: DMX input only, no DMX output/feedback

## Support

For issues or questions:

- **GitHub Issues**: [Project Issues](https://github.com/yourusername/govee-mac/issues)
- **Govee API**: [developer.govee.com](https://developer.govee.com)

## Credits

DMX control implementation uses:
- **ArtNet**: Art-Net™ protocol by Artistic Licence
- **sACN (E1.31)**: ANSI E1.31 standard

---

**Note**: This is an unofficial integration. Govee does not officially support DMX control. This feature works by translating DMX signals into Govee API commands.
