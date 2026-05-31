import SwiftUI
import Combine

@main
struct InternetSpeedMeterApp: App {
    @StateObject private var speedMonitor: SpeedMonitor
    
    init() {
        // Create a single SpeedMonitor instance and start monitoring immediately
        let monitor = SpeedMonitor()
        monitor.startMonitoring()
        _speedMonitor = StateObject(wrappedValue: monitor)
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                Text("Internet Speed Meter")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Speed")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                        GridRow {
                            Text("↑ Upload:")
                                .gridColumnAlignment(.leading)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 100, alignment: .leading)
                            Text(speedMonitor.uploadSpeed)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .gridColumnAlignment(.leading)
                        }
                        GridRow {
                            Text("↓ Download:")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 100, alignment: .leading)
                            Text(speedMonitor.downloadSpeed)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Data Usage")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                        GridRow {
                            Text("↑ Uploaded:")
                                .gridColumnAlignment(.leading)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 100, alignment: .leading)
                            Text(speedMonitor.totalUploaded)
                                .fontWeight(.medium)
                                .gridColumnAlignment(.leading)
                        }
                        GridRow {
                            Text("↓ Downloaded:")
                                .foregroundColor(.secondary)
                                .frame(minWidth: 100, alignment: .leading)
                            Text(speedMonitor.totalDownloaded)
                                .fontWeight(.medium)
                        }
                    }
                }

                Divider()

                Button(action: { speedMonitor.resetTotalUsage() }) {
                    Text("Reset Stats")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity)
            }
            .padding(12)
            .frame(width: 240)
        } label: {
            Text("↑ \(speedMonitor.uploadSpeed)  ↓ \(speedMonitor.downloadSpeed)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .menuBarExtraStyle(.window)
    }
}
