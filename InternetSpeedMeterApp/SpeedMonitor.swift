import Foundation
import Combine
import Network
import Darwin

class SpeedMonitor: ObservableObject {
    @Published var downloadSpeed: String = "0 KB/s"
    @Published var uploadSpeed: String = "0 KB/s"
    @Published var totalDownloaded: String = "0 MB"
    @Published var totalUploaded: String = "0 MB"

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)
    private var timer: Timer?

    private var previousRx: UInt64 = 0
    private var previousTx: UInt64 = 0
    private var sessionStartRx: UInt64 = 0
    private var sessionStartTx: UInt64 = 0
    
    // UserDefaults keys
    private let totalDownloadedKey = "totalDownloadedBytes"
    private let totalUploadedKey = "totalUploadedBytes"
    
    deinit {
        stopMonitoring()
    }
    
    init() {
        // Load saved totals from UserDefaults
        let savedDownloaded = UInt64(UserDefaults.standard.integer(forKey: totalDownloadedKey))
        let savedUploaded = UInt64(UserDefaults.standard.integer(forKey: totalUploadedKey))
        
        if savedDownloaded > 0 {
            totalDownloaded = formatBytes(savedDownloaded)
        }
        if savedUploaded > 0 {
            totalUploaded = formatBytes(savedUploaded)
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        monitor.cancel()
    }

    func startMonitoring() {
        // Monitor network path changes (VPN connect/disconnect, etc.)
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // Reset counters when network topology changes
            DispatchQueue.main.async {
                self.resetCountersOnNetworkChange()
            }
        }
        monitor.start(queue: queue)

        // Start timer loop for speed polling on main run loop
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNetworkUsage()
        }
    }
    
    private func resetCountersOnNetworkChange() {
        // Reset to current values to avoid negative calculations
        let (rx, tx) = getNetworkBytes()
        previousRx = rx
        previousTx = tx
        sessionStartRx = rx
        sessionStartTx = tx
    }

    private func updateNetworkUsage() {
        let (rx, tx) = self.getNetworkBytes()

        if previousRx > 0 && previousTx > 0 {
            // Protect against negative values when interfaces disappear (VPN disconnect)
            // If current values are less than previous, network topology changed
            guard rx >= previousRx && tx >= previousTx else {
                // Reset counters on unexpected decrease
                previousRx = rx
                previousTx = tx
                sessionStartRx = rx
                sessionStartTx = tx
                
                DispatchQueue.main.async {
                    self.downloadSpeed = "0 KB/s"
                    self.uploadSpeed = "0 KB/s"
                }
                return
            }
            
            let dl = Int(rx - previousRx)
            let ul = Int(tx - previousTx)

            DispatchQueue.main.async {
                self.downloadSpeed = self.formatSpeed(dl)
                self.uploadSpeed   = self.formatSpeed(ul)
                
                // Update total usage
                if self.sessionStartRx == 0 {
                    self.sessionStartRx = rx
                    self.sessionStartTx = tx
                }
                
                // Protect against underflow in session calculations
                guard rx >= self.sessionStartRx && tx >= self.sessionStartTx else {
                    self.sessionStartRx = rx
                    self.sessionStartTx = tx
                    return
                }
                
                let currentDownloaded = rx - self.sessionStartRx
                let currentUploaded = tx - self.sessionStartTx
                
                // Add to saved totals
                let savedDownloaded = UInt64(UserDefaults.standard.integer(forKey: self.totalDownloadedKey))
                let savedUploaded = UInt64(UserDefaults.standard.integer(forKey: self.totalUploadedKey))
                
                let totalDown = savedDownloaded + currentDownloaded
                let totalUp = savedUploaded + currentUploaded
                
                self.totalDownloaded = self.formatBytes(totalDown)
                self.totalUploaded = self.formatBytes(totalUp)
                
                // Save periodically (every update)
                UserDefaults.standard.set(Int(totalDown), forKey: self.totalDownloadedKey)
                UserDefaults.standard.set(Int(totalUp), forKey: self.totalUploadedKey)
            }
        } else {
            // Initialize session start values
            sessionStartRx = rx
            sessionStartTx = tx
        }

        previousRx = rx
        previousTx = tx
    }

    private func getNetworkBytes() -> (UInt64, UInt64) {
        var rx: UInt64 = 0
        var tx: UInt64 = 0

        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0 else {
            // Failed to get interface addresses
            return (rx, tx)
        }
        
        defer {
            if let addrs = addrs {
                freeifaddrs(addrs)
            }
        }
        
        guard let firstAddr = addrs else {
            return (rx, tx)
        }
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr

        while let current = ptr {
            // Safely access interface data
            if let dataPtr = current.pointee.ifa_data {
                let ifdata = dataPtr.assumingMemoryBound(to: if_data.self).pointee
                rx += UInt64(ifdata.ifi_ibytes)
                tx += UInt64(ifdata.ifi_obytes)
            }
            ptr = current.pointee.ifa_next
        }

        return (rx, tx)
    }

    /// Formats a Double with up to 2 decimal places, stripping unnecessary trailing zeros.
    /// e.g. 1.00 → "1", 1.10 → "1.1", 1.23 → "1.23"
    private func smartFormat(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func formatSpeed(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024

        if mb >= 1 {
            return "\(smartFormat(mb)) MB/s"
        }
        return "\(smartFormat(kb)) KB/s"
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 {
            return "\(smartFormat(gb)) GB"
        } else if mb >= 1 {
            return "\(smartFormat(mb)) MB"
        } else {
            return "\(smartFormat(kb)) KB"
        }
    }
    
    func resetTotalUsage() {
        UserDefaults.standard.set(0, forKey: totalDownloadedKey)
        UserDefaults.standard.set(0, forKey: totalUploadedKey)
        
        DispatchQueue.main.async {
            self.totalDownloaded = "0 MB"
            self.totalUploaded = "0 MB"
        }
        
        // Reset session counters
        sessionStartRx = previousRx
        sessionStartTx = previousTx
    }
}
