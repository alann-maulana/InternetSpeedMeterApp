# AGENTS.md

## Project Type
macOS menu bar app (Swift/SwiftUI). No web frontend, no package.json, no npm scripts.

## Build & Run
```bash
# Open project
open InternetSpeedMeterApp.xcodeproj

# Build and run in Xcode: ⌘+R
# No CLI build commands configured
```

## Project Structure
```
InternetSpeedMeterApp/
├── InternetSpeedMeterAppApp.swift  # App entry point, MenuBarExtra UI
├── SpeedMonitor.swift              # Core logic: network monitoring via getifaddrs()
└── Assets.xcassets/                # App icon and accent color
```

## Key Technical Details

### Architecture
- **MenuBarExtra app**: Lives in macOS menu bar, no dock icon
- **Network monitoring**: Uses Darwin `getifaddrs()` to read interface byte counters (`if_data.ifi_ibytes`, `ifi_obytes`)
- **Polling**: 1-second timer on main run loop
- **Persistence**: Total usage stored in UserDefaults (`totalDownloadedBytes`, `totalUploadedBytes`)

### Network Topology Handling
SpeedMonitor has defensive logic for VPN connect/disconnect and interface changes:
- Resets counters when `rx/tx` values decrease unexpectedly (SpeedMonitor.swift:81)
- `NWPathMonitor` detects network path changes and triggers counter reset (SpeedMonitor.swift:50)
- UserDefaults stores Int, not UInt64 - casting required (SpeedMonitor.swift:129-130)

### State Management
- Single `SpeedMonitor` instance created at app launch (InternetSpeedMeterAppApp.swift:10-11)
- Monitoring starts immediately in `init()`
- Published properties: `downloadSpeed`, `uploadSpeed`, `totalDownloaded`, `totalUploaded`

## Xcode Configuration
- **Bundle ID**: `sherukoda.InternetSpeedMeterApp`
- **Swift Version**: 5.0
- **Target**: macOS (MenuBarExtra requires macOS 13+)
- **Concurrency**: Swift 6 approachable concurrency enabled, MainActor isolation

## No Dependencies
No CocoaPods, SPM packages, or Carthage. Pure Swift + Foundation + SwiftUI.

## Common Pitfalls
1. **Don't add package.json or npm scripts** - this is not a web project
2. **Network byte counters can decrease** - happens on VPN disconnect or interface removal; code already handles this (SpeedMonitor.swift:81)
3. **UserDefaults stores Int, not UInt64** - casting required (SpeedMonitor.swift:129-130)
4. **Timer must run on main run loop** - `Timer.scheduledTimer` used, not DispatchQueue timer

## Testing
No test target configured. Manual testing via Xcode required.

## Release
Pre-built app available in `release/` directory. Build from source via Xcode for development.
