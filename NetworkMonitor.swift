import Foundation
import Darwin
import Combine
import Network

struct ProcessNetworkUsage: Identifiable {
    let id = UUID()
    let name: String
    let uploadSpeed: Double
    let downloadSpeed: Double
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

    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousTimestamp: Date?
    private var initialBytesIn: UInt64 = 0
    private var initialBytesOut: UInt64 = 0
    private var isInitialized = false

    private var timer: DispatchSourceTimer?
    private var ipRefreshTimer: DispatchSourceTimer?
    private var processTimer: DispatchSourceTimer?

    // For tracking per-process deltas
    private var previousProcessBytes: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]

    init() {
        startMonitoring()
        refreshIPAddresses()
        startIPRefreshTimer()
        startProcessMonitoring()
    }

    deinit {
        stopMonitoring()
        ipRefreshTimer?.cancel()
        ipRefreshTimer = nil
        processTimer?.cancel()
        processTimer = nil
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
            let prev = previousProcessBytes[name] ?? (0, 0)
            let downloadDelta = bytes.bytesIn >= prev.bytesIn ? bytes.bytesIn - prev.bytesIn : 0
            let uploadDelta = bytes.bytesOut >= prev.bytesOut ? bytes.bytesOut - prev.bytesOut : 0

            // Speed per second (we poll every 2 seconds)
            let downloadSpeed = Double(downloadDelta) / 2.0
            let uploadSpeed = Double(uploadDelta) / 2.0

            // Only include if there's activity
            if downloadSpeed > 0 || uploadSpeed > 0 {
                processUsages.append(ProcessNetworkUsage(
                    name: name,
                    uploadSpeed: uploadSpeed,
                    downloadSpeed: downloadSpeed
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

    private func getProcessNetworkBytes() -> [String: (bytesIn: UInt64, bytesOut: UInt64)] {
        var result: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-L", "1", "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch", "-t", "wifi", "-t", "wired"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                result = parseNettopOutput(output)
            }
        } catch {
            // Silently fail - nettop might not be available
        }

        return result
    }

    private func parseNettopOutput(_ output: String) -> [String: (bytesIn: UInt64, bytesOut: UInt64)] {
        var result: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            // Skip header and empty lines
            if line.isEmpty || line.hasPrefix("time") || line.contains("state") { continue }

            let components = line.components(separatedBy: ",")
            if components.count >= 3 {
                // Format: process_name.pid, bytes_in, bytes_out
                let processInfo = components[0].trimmingCharacters(in: .whitespaces)
                // Extract process name (remove .pid suffix)
                var processName = processInfo
                if let dotRange = processInfo.range(of: ".", options: .backwards) {
                    processName = String(processInfo[..<dotRange.lowerBound])
                }

                // Skip system processes we don't care about
                if processName.isEmpty || processName == "kernel_task" { continue }

                let bytesIn = UInt64(components[1].trimmingCharacters(in: .whitespaces)) ?? 0
                let bytesOut = UInt64(components[2].trimmingCharacters(in: .whitespaces)) ?? 0

                // Aggregate by process name
                if let existing = result[processName] {
                    result[processName] = (existing.bytesIn + bytesIn, existing.bytesOut + bytesOut)
                } else {
                    result[processName] = (bytesIn, bytesOut)
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

        // Get WAN IP
        fetchWANIP { wanAddress in
            DispatchQueue.main.async { [weak self] in
                self?.lanIP = lanAddress ?? "—"
                self?.wanIP = wanAddress ?? "—"
            }
        }
    }

    private func getLANIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
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

    private func fetchWANIP(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.ipify.org") else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data, let ip = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            completion(ip.trimmingCharacters(in: .whitespacesAndNewlines))
        }.resume()
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

        // Create timer for 1-second polling
        let queue = DispatchQueue(label: "com.networkutils.monitor", qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now() + 1, repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            self?.updateStats()
        }
        timer?.resume()
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }

    private func updateStats() {
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

        // Calculate speeds (bytes per second)
        let deltaIn = bytesIn >= previousBytesIn ? bytesIn - previousBytesIn : 0
        let deltaOut = bytesOut >= previousBytesOut ? bytesOut - previousBytesOut : 0

        let newDownloadSpeed = Double(deltaIn) / timeDelta
        let newUploadSpeed = Double(deltaOut) / timeDelta

        // Calculate session totals
        let sessionDownloaded = bytesIn >= initialBytesIn ? bytesIn - initialBytesIn : 0
        let sessionUploaded = bytesOut >= initialBytesOut ? bytesOut - initialBytesOut : 0

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
    }

    private func getNetworkBytes() -> (bytesIn: UInt64, bytesOut: UInt64) {
        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {
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

            totalBytesIn += UInt64(networkData.ifi_obytes)
            totalBytesOut += UInt64(networkData.ifi_ibytes)
        }

        return (totalBytesIn, totalBytesOut)
    }
}
