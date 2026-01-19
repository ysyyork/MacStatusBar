import Foundation
import Darwin
import Combine
import Network
import os.log

struct ProcessNetworkUsage: Identifiable {
    let id = UUID()
    let name: String
    let uploadSpeed: Double
    let downloadSpeed: Double
    let pid: Int32
}

final class NetworkMonitor: ObservableObject {
    @Published var uploadSpeed: Double = 0
    @Published var downloadSpeed: Double = 0
    @Published var totalUploaded: UInt64 = 0
    @Published var totalDownloaded: UInt64 = 0
    @Published var uploadHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var downloadHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var lanIP: String = "—"
    @Published var wanIP: String = "—"
    @Published var topProcesses: [ProcessNetworkUsage] = []
    @Published var isNetworkAvailable: Bool = true

    private var ipRefreshTimer: DispatchSourceTimer?
    private var processTimer: DispatchSourceTimer?
    private var healthCheckTimer: DispatchSourceTimer?

    // For tracking per-process deltas
    private var previousProcessBytes: [String: (bytesIn: UInt64, bytesOut: UInt64, pid: Int32)] = [:]

    // Network reachability
    private var pathMonitor: NWPathMonitor?
    private let pathMonitorQueue = DispatchQueue(label: "com.macstatusbar.network.path")

    // Health check properties
    private var lastSuccessfulUpdate: Date?
    private let healthCheckInterval: TimeInterval = 30.0

    // WAN IP fallback services
    private let wanIPServices = [
        "https://api.ipify.org",
        "https://ipinfo.io/ip",
        "https://icanhazip.com"
    ]
    private var currentWANIPServiceIndex = 0
    private var wanIPRetryCount = 0
    private let maxWANIPRetries = 3

    init() {
        setupNetworkPathMonitor()
        refreshIPAddresses()
        startIPRefreshTimer()
        startProcessMonitoring()
        startHealthCheckTimer()
    }

    deinit {
        ipRefreshTimer?.setEventHandler(handler: nil)
        ipRefreshTimer?.cancel()
        ipRefreshTimer = nil
        processTimer?.setEventHandler(handler: nil)
        processTimer?.cancel()
        processTimer = nil
        healthCheckTimer?.setEventHandler(handler: nil)
        healthCheckTimer?.cancel()
        healthCheckTimer = nil
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    // MARK: - Network Reachability

    private func setupNetworkPathMonitor() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            DispatchQueue.main.async {
                self?.isNetworkAvailable = isAvailable
            }
            if isAvailable {
                AppLogger.network.debug("Network is available")
            } else {
                AppLogger.network.warning("Network is unavailable")
            }
        }
        pathMonitor?.start(queue: pathMonitorQueue)
    }

    // MARK: - Health Check

    private func startHealthCheckTimer() {
        let queue = DispatchQueue(label: "com.macstatusbar.network.health", qos: .utility)
        healthCheckTimer = DispatchSource.makeTimerSource(queue: queue)
        healthCheckTimer?.schedule(deadline: .now() + healthCheckInterval, repeating: healthCheckInterval)
        healthCheckTimer?.setEventHandler { [weak self] in
            self?.checkHealth()
        }
        healthCheckTimer?.resume()
    }

    private func checkHealth() {
        if let lastUpdate = lastSuccessfulUpdate,
           Date().timeIntervalSince(lastUpdate) > healthCheckInterval {
            AppLogger.network.warning("Network monitor stale, restarting...")
            restartMonitoring()
        }
    }

    private func restartMonitoring() {
        // Stop process timer
        processTimer?.setEventHandler(handler: nil)
        processTimer?.cancel()
        processTimer = nil

        // Restart after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startProcessMonitoring()
        }
    }

    private func startProcessMonitoring() {
        // Update process stats every 2 seconds
        let queue = DispatchQueue(label: "com.networkutils.process", qos: .utility)
        processTimer = DispatchSource.makeTimerSource(queue: queue)
        processTimer?.schedule(deadline: .now() + 1, repeating: 2.0)
        processTimer?.setEventHandler { [weak self] in
            self?.updateProcessStats()
        }
        processTimer?.resume()
    }

    private func updateProcessStats() {
        let processBytes = getProcessNetworkBytes()
        var processUsages: [ProcessNetworkUsage] = []
        var totalDownload: Double = 0
        var totalUpload: Double = 0

        for (name, bytes) in processBytes {
            // Only calculate speed if we have a previous reading for this process
            // This prevents showing inflated speeds for newly appeared processes
            guard let prev = previousProcessBytes[name] else {
                continue
            }

            // Handle counter wraparound
            let downloadDelta = bytes.bytesIn >= prev.bytesIn ? bytes.bytesIn - prev.bytesIn : bytes.bytesIn
            let uploadDelta = bytes.bytesOut >= prev.bytesOut ? bytes.bytesOut - prev.bytesOut : bytes.bytesOut

            // Speed per second (we poll every 2 seconds)
            let downloadSpeed = Double(downloadDelta) / 2.0
            let uploadSpeed = Double(uploadDelta) / 2.0

            // Sanity check: skip if speed is unreasonably high (> 10 Gbps)
            let maxSpeed: Double = 10_000_000_000
            if downloadSpeed > maxSpeed || uploadSpeed > maxSpeed {
                continue
            }

            // Add to totals
            totalDownload += downloadSpeed
            totalUpload += uploadSpeed

            // Only include in process list if there's activity
            if downloadSpeed > 0 || uploadSpeed > 0 {
                processUsages.append(ProcessNetworkUsage(
                    name: name,
                    uploadSpeed: uploadSpeed,
                    downloadSpeed: downloadSpeed,
                    pid: bytes.pid
                ))
            }
        }

        // Sort by total activity, take top 5
        let sorted = processUsages.sorted {
            ($0.uploadSpeed + $0.downloadSpeed) > ($1.uploadSpeed + $1.downloadSpeed)
        }.prefix(5)

        previousProcessBytes = processBytes
        lastSuccessfulUpdate = Date()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.topProcesses = Array(sorted)

            // Update total speeds from nettop data (more reliable than ifi_ibytes/ifi_obytes)
            self.downloadSpeed = totalDownload
            self.uploadSpeed = totalUpload

            // Update session totals (accumulate bytes transferred)
            // Speed is bytes/sec, we poll every 2 seconds
            self.totalDownloaded += UInt64(totalDownload * 2)
            self.totalUploaded += UInt64(totalUpload * 2)

            // Update history
            self.downloadHistory.removeFirst()
            self.downloadHistory.append(totalDownload)
            self.uploadHistory.removeFirst()
            self.uploadHistory.append(totalUpload)
        }
    }

    private func getProcessNetworkBytes() -> [String: (bytesIn: UInt64, bytesOut: UInt64, pid: Int32)] {
        var result: [String: (bytesIn: UInt64, bytesOut: UInt64, pid: Int32)] = [:]

        let runResult = ProcessRunner.run(
            executable: "/usr/bin/nettop",
            arguments: ["-P", "-L", "1", "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch", "-t", "wifi", "-t", "wired"],
            timeout: 10.0
        )

        switch runResult {
        case .success(let output):
            result = parseNettopOutput(output)
        case .failure(let error):
            AppLogger.network.debug("nettop failed: \(error.localizedDescription)")
        }

        return result
    }

    private func parseNettopOutput(_ output: String) -> [String: (bytesIn: UInt64, bytesOut: UInt64, pid: Int32)] {
        var result: [String: (bytesIn: UInt64, bytesOut: UInt64, pid: Int32)] = [:]
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            // Skip header and empty lines
            if line.isEmpty || line.hasPrefix("time") || line.contains("state") { continue }

            let components = line.components(separatedBy: ",")
            if components.count >= 3 {
                // Format: process_name.pid, bytes_in, bytes_out
                let processInfo = components[0].trimmingCharacters(in: .whitespaces)
                // Extract process name and PID (remove .pid suffix)
                var processName = processInfo
                var pid: Int32 = 0
                if let dotRange = processInfo.range(of: ".", options: .backwards) {
                    processName = String(processInfo[..<dotRange.lowerBound])
                    let pidStr = String(processInfo[dotRange.upperBound...])
                    pid = Int32(pidStr) ?? 0
                }

                // Skip system processes we don't care about
                if processName.isEmpty || processName == "kernel_task" { continue }

                // nettop columns: process.pid, bytes_in, bytes_out
                // Standard convention (from process perspective):
                // - bytes_in (col 1) = data received by process = DOWNLOAD
                // - bytes_out (col 2) = data sent by process = UPLOAD
                let bytesIn = UInt64(components[1].trimmingCharacters(in: .whitespaces)) ?? 0   // download
                let bytesOut = UInt64(components[2].trimmingCharacters(in: .whitespaces)) ?? 0  // upload

                // Aggregate by process name (keep first PID we see)
                if let existing = result[processName] {
                    result[processName] = (existing.bytesIn + bytesIn, existing.bytesOut + bytesOut, existing.pid)
                } else {
                    result[processName] = (bytesIn, bytesOut, pid)
                }
            }
        }

        return result
    }

    private func startIPRefreshTimer() {
        let queue = DispatchQueue(label: "com.networkutils.iprefresh", qos: .utility)
        ipRefreshTimer = DispatchSource.makeTimerSource(queue: queue)
        ipRefreshTimer?.schedule(deadline: .now() + 60, repeating: 60.0)
        ipRefreshTimer?.setEventHandler { [weak self] in
            self?.refreshIPAddresses()
        }
        ipRefreshTimer?.resume()
    }

    func refreshIPAddresses() {
        // Get LAN IP
        let lanAddress = getLANIPAddress()

        // Get WAN IP with retry logic
        fetchWANIPWithRetry { wanAddress in
            DispatchQueue.main.async { [weak self] in
                self?.lanIP = lanAddress ?? "—"
                self?.wanIP = wanAddress ?? "—"
            }
        }
    }

    private func getLANIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else {
            AppLogger.network.error("Failed to get network interfaces")
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family

            // Check for IPv4
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                // Prefer en0 (Wi-Fi) or en1, skip loopback
                if name.hasPrefix("en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        address = String(cString: hostname)
                        // Prefer en0
                        if name == "en0" { break }
                    }
                }
            }
        }
        return address
    }

    // MARK: - WAN IP with Retry and Fallback

    private func fetchWANIPWithRetry(completion: @escaping (String?) -> Void) {
        // Check network availability first
        guard isNetworkAvailable else {
            AppLogger.network.debug("Skipping WAN IP fetch - network unavailable")
            completion(nil)
            return
        }

        wanIPRetryCount = 0
        currentWANIPServiceIndex = 0
        attemptWANIPFetch(completion: completion)
    }

    private func attemptWANIPFetch(completion: @escaping (String?) -> Void) {
        guard currentWANIPServiceIndex < wanIPServices.count else {
            AppLogger.network.warning("All WAN IP services failed")
            completion(nil)
            return
        }

        let urlString = wanIPServices[currentWANIPServiceIndex]
        guard let url = URL(string: urlString) else {
            currentWANIPServiceIndex += 1
            attemptWANIPFetch(completion: completion)
            return
        }

        // Create session with explicit timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        let session = URLSession(configuration: config)

        session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                AppLogger.network.debug("WAN IP fetch failed from \(urlString): \(error.localizedDescription)")
                self.handleWANIPFailure(completion: completion)
                return
            }

            guard let data = data,
                  let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  self.isValidIPAddress(ip) else {
                AppLogger.network.debug("Invalid response from \(urlString)")
                self.handleWANIPFailure(completion: completion)
                return
            }

            AppLogger.network.debug("WAN IP fetched successfully: \(ip)")
            completion(ip)
        }.resume()
    }

    private func handleWANIPFailure(completion: @escaping (String?) -> Void) {
        self.wanIPRetryCount += 1

        if self.wanIPRetryCount < self.maxWANIPRetries {
            // Exponential backoff: 1s, 2s, 4s
            let delay = pow(2.0, Double(self.wanIPRetryCount - 1))
            AppLogger.network.debug("Retrying WAN IP fetch in \(delay)s (attempt \(self.wanIPRetryCount + 1)/\(self.maxWANIPRetries))")

            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.attemptWANIPFetch(completion: completion)
            }
        } else {
            // Move to next service
            self.wanIPRetryCount = 0
            self.currentWANIPServiceIndex += 1
            AppLogger.network.debug("Trying fallback IP service \(self.currentWANIPServiceIndex + 1)/\(self.wanIPServices.count)")
            self.attemptWANIPFetch(completion: completion)
        }
    }

    private func isValidIPAddress(_ ip: String) -> Bool {
        // Basic validation for IPv4 or IPv6
        let ipv4Pattern = #"^(\d{1,3}\.){3}\d{1,3}$"#
        let ipv6Pattern = #"^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$"#

        if ip.range(of: ipv4Pattern, options: .regularExpression) != nil {
            // Validate each octet is 0-255
            let octets = ip.split(separator: ".").compactMap { Int($0) }
            return octets.count == 4 && octets.allSatisfy { $0 >= 0 && $0 <= 255 }
        }

        return ip.range(of: ipv6Pattern, options: .regularExpression) != nil
    }

}
