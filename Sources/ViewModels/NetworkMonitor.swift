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

    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousTimestamp: Date?
    private var initialBytesIn: UInt64 = 0
    private var initialBytesOut: UInt64 = 0
    private var isInitialized = false

    private var timer: DispatchSourceTimer?
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

    // Rate limiting
    private var lastUpdateTime: Date?
    private let minUpdateInterval: TimeInterval = 0.5

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
        startMonitoring()
        refreshIPAddresses()
        startIPRefreshTimer()
        startProcessMonitoring()
        startHealthCheckTimer()
    }

    deinit {
        stopMonitoring()
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
        stopMonitoring()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startMonitoring()
        }
    }

    // MARK: - Rate Limiting

    private func shouldUpdate() -> Bool {
        guard let last = lastUpdateTime else { return true }
        return Date().timeIntervalSince(last) >= minUpdateInterval
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
            // This catches counter resets or measurement errors
            let maxSpeed: Double = 10_000_000_000
            if downloadSpeed > maxSpeed || uploadSpeed > maxSpeed {
                continue
            }

            // Only include if there's activity
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

        DispatchQueue.main.async { [weak self] in
            self?.topProcesses = Array(sorted)
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

                let bytesIn = UInt64(components[1].trimmingCharacters(in: .whitespaces)) ?? 0
                let bytesOut = UInt64(components[2].trimmingCharacters(in: .whitespaces)) ?? 0

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

    func startMonitoring() {
        // Get initial reading
        let (bytesIn, bytesOut) = getNetworkBytes()
        previousBytesIn = bytesIn
        previousBytesOut = bytesOut
        initialBytesIn = bytesIn
        initialBytesOut = bytesOut
        previousTimestamp = Date()
        isInitialized = true
        lastSuccessfulUpdate = Date()

        // Create timer for 1-second polling
        let queue = DispatchQueue(label: "com.networkutils.monitor", qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now() + 1, repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            self?.updateStats()
        }
        timer?.resume()
        AppLogger.network.debug("Network monitoring started")
    }

    func stopMonitoring() {
        timer?.setEventHandler(handler: nil)
        timer?.cancel()
        timer = nil
        AppLogger.network.debug("Network monitoring stopped")
    }

    private func updateStats() {
        guard shouldUpdate() else { return }

        let now = Date()
        let (bytesIn, bytesOut) = getNetworkBytes()

        guard let prevTimestamp = previousTimestamp else {
            previousBytesIn = bytesIn
            previousBytesOut = bytesOut
            previousTimestamp = now
            return
        }

        let timeDelta = now.timeIntervalSince(prevTimestamp)
        guard timeDelta > 0 else { return }

        // Calculate speeds (bytes per second) with counter wraparound handling
        let deltaIn = bytesIn >= previousBytesIn ? bytesIn - previousBytesIn : bytesIn
        let deltaOut = bytesOut >= previousBytesOut ? bytesOut - previousBytesOut : bytesOut

        // Validate and clamp speeds to reasonable values (max 10 Gbps)
        let maxSpeed: Double = 10_000_000_000
        let newDownloadSpeed = min(maxSpeed, max(0, Double(deltaIn) / timeDelta))
        let newUploadSpeed = min(maxSpeed, max(0, Double(deltaOut) / timeDelta))

        // Calculate session totals with wraparound handling
        let sessionDownloaded = bytesIn >= initialBytesIn ? bytesIn - initialBytesIn : bytesIn
        let sessionUploaded = bytesOut >= initialBytesOut ? bytesOut - initialBytesOut : bytesOut

        // Update on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.downloadSpeed = newDownloadSpeed
            self.uploadSpeed = newUploadSpeed
            self.totalDownloaded = sessionDownloaded
            self.totalUploaded = sessionUploaded

            // Update history (shift left, append new value)
            self.downloadHistory.removeFirst()
            self.downloadHistory.append(newDownloadSpeed)
            self.uploadHistory.removeFirst()
            self.uploadHistory.append(newUploadSpeed)
        }

        // Store for next iteration
        previousBytesIn = bytesIn
        previousBytesOut = bytesOut
        previousTimestamp = now
        lastUpdateTime = now
        lastSuccessfulUpdate = now
    }

    private func getNetworkBytes() -> (bytesIn: UInt64, bytesOut: UInt64) {
        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {
            AppLogger.network.error("Failed to get network interface addresses")
            return (0, 0)
        }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }

            // Only count AF_LINK (link layer) addresses which have the stats
            guard interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) else { continue }

            // Get interface name
            let name = String(cString: interface.ifa_name)

            // Skip loopback interface
            guard !name.hasPrefix("lo") else { continue }

            // Get interface data
            guard let data = interface.ifa_data else { continue }
            let networkData = data.assumingMemoryBound(to: if_data.self).pointee

            totalBytesIn += UInt64(networkData.ifi_ibytes)   // ibytes = input (download)
            totalBytesOut += UInt64(networkData.ifi_obytes)  // obytes = output (upload)
        }

        return (totalBytesIn, totalBytesOut)
    }
}
