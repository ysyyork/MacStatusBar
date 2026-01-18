import Foundation
import Darwin
import Combine
import os.log

// MARK: - Data Models

struct ProcessCPUUsage: Identifiable {
    let id = UUID()
    let name: String
    let cpuUsage: Double
    let pid: Int32
}

// MARK: - CPU Monitor

final class CPUMonitor: ObservableObject {
    // MARK: - Published Properties

    @Published var userCPU: Double = 0
    @Published var systemCPU: Double = 0
    @Published var idleCPU: Double = 100
    @Published var cpuTemperature: Double = 0
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var topProcesses: [ProcessCPUUsage] = []
    @Published var loadAverage: (Double, Double, Double) = (0, 0, 0)
    @Published var loadHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var peakLoad: Double = 0
    @Published var uptime: TimeInterval = 0
    @Published var gpuUsage: Double = 0
    @Published var gpuMemoryUsage: Double = 0
    @Published var gpuMemoryBytes: UInt64 = 0
    @Published var gpuMemoryTotal: UInt64 = 0
    @Published var gpuName: String = "GPU"
    @Published var processorName: String = "—"
    @Published var fps: Double = 0
    @Published var memoryUsed: UInt64 = 0
    @Published var memoryTotal: UInt64 = 0
    @Published var swapUsed: UInt64 = 0
    @Published var swapTotal: UInt64 = 0

    // MARK: - Private Properties

    private var timer: DispatchSourceTimer?
    private var processTimer: DispatchSourceTimer?
    private var healthCheckTimer: DispatchSourceTimer?
    private var previousCPUInfo: host_cpu_load_info?
    private var cachedProcessorName: String?

    // Health check properties
    private var lastSuccessfulUpdate: Date?
    private let healthCheckInterval: TimeInterval = 30.0

    // Rate limiting
    private var lastUpdateTime: Date?
    private let minUpdateInterval: TimeInterval = 0.5

    // MARK: - Initialization

    init() {
        fetchProcessorNameAsync()
        startMonitoring()
        startProcessMonitoring()
        startHealthCheckTimer()
    }

    deinit {
        timer?.setEventHandler(handler: nil)
        timer?.cancel()
        timer = nil
        processTimer?.setEventHandler(handler: nil)
        processTimer?.cancel()
        processTimer = nil
        healthCheckTimer?.setEventHandler(handler: nil)
        healthCheckTimer?.cancel()
        healthCheckTimer = nil
    }

    // MARK: - Health Check

    private func startHealthCheckTimer() {
        let queue = DispatchQueue(label: "com.macstatusbar.cpu.health", qos: .utility)
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
            AppLogger.cpu.warning("CPU monitor stale, restarting...")
            restartMonitoring()
        }
    }

    private func restartMonitoring() {
        timer?.setEventHandler(handler: nil)
        timer?.cancel()
        timer = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startMonitoring()
        }
    }

    // MARK: - Rate Limiting

    private func shouldUpdate() -> Bool {
        guard let last = lastUpdateTime else { return true }
        return Date().timeIntervalSince(last) >= minUpdateInterval
    }

    // MARK: - Processor Name

    private func fetchProcessorNameAsync() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let name = self?.getProcessorName() ?? "Unknown"
            DispatchQueue.main.async {
                self?.processorName = name
            }
        }
    }

    private func getProcessorName() -> String {
        // Try Intel-style brand string first
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var name = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &name, &size, nil, 0)
            let fullName = String(cString: name)
            if !fullName.isEmpty {
                return fullName
            }
        }

        // For Apple Silicon
        return getAppleSiliconName()
    }

    private func getAppleSiliconName() -> String {
        let result = ProcessRunner.run(
            executable: "/usr/sbin/system_profiler",
            arguments: ["SPHardwareDataType", "-json"],
            timeout: 10.0
        )

        switch result {
        case .success(let output):
            if let data = output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let hardware = json["SPHardwareDataType"] as? [[String: Any]],
               let first = hardware.first,
               let chipType = first["chip_type"] as? String {
                return chipType
            }
        case .failure(let error):
            AppLogger.cpu.error("Failed to get processor name: \(error.localizedDescription)")
        }
        return "Apple Silicon"
    }

    // MARK: - Monitoring Control

    private func startMonitoring() {
        let queue = DispatchQueue(label: "com.macstatusbar.cpu", qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            self?.updateStats()
        }
        timer?.resume()
        lastSuccessfulUpdate = Date()
        AppLogger.cpu.debug("CPU monitoring started")
    }

    private func startProcessMonitoring() {
        let queue = DispatchQueue(label: "com.macstatusbar.cpu.process", qos: .utility)
        processTimer = DispatchSource.makeTimerSource(queue: queue)
        processTimer?.schedule(deadline: .now() + 1, repeating: 2.0)
        processTimer?.setEventHandler { [weak self] in
            self?.updateProcessStats()
        }
        processTimer?.resume()
    }

    // MARK: - Stats Update

    private func updateStats() {
        guard shouldUpdate() else { return }

        let cpuUsage = getCPUUsage()
        let temp = getCPUTemperature()
        let load = getLoadAverage()
        let uptimeVal = getUptime()
        let gpuStats = getGPUUsage()
        let memInfo = getMemoryInfo()
        let swapInfo = getSwapInfo()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.userCPU = cpuUsage.user
            self.systemCPU = cpuUsage.system
            self.idleCPU = cpuUsage.idle
            self.cpuTemperature = temp
            self.loadAverage = load
            self.uptime = uptimeVal
            self.gpuUsage = gpuStats.usage
            self.gpuMemoryUsage = gpuStats.memoryPercent
            self.gpuMemoryBytes = gpuStats.memoryBytes
            self.gpuMemoryTotal = gpuStats.memoryTotal
            self.gpuName = gpuStats.name
            self.memoryUsed = memInfo.used
            self.memoryTotal = memInfo.total
            self.swapUsed = swapInfo.used
            self.swapTotal = swapInfo.total

            // Update CPU history (total usage = user + system)
            let totalCPU = cpuUsage.user + cpuUsage.system
            self.cpuHistory.removeFirst()
            self.cpuHistory.append(totalCPU)

            // Update load history
            self.loadHistory.removeFirst()
            self.loadHistory.append(load.0)
            self.peakLoad = max(self.peakLoad, load.0)
        }

        lastUpdateTime = Date()
        lastSuccessfulUpdate = Date()
    }

    // MARK: - CPU Usage

    private func getCPUUsage() -> (user: Double, system: Double, idle: Double) {
        let hostPort = mach_host_self()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        var cpuLoadInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            AppLogger.cpu.error("Failed to get CPU load info: kern_return \(result)")
            return (0, 0, 100)
        }

        // Access cpu_ticks using tuple indices
        let user = cpuLoadInfo.cpu_ticks.0
        let system = cpuLoadInfo.cpu_ticks.1
        let idle = cpuLoadInfo.cpu_ticks.2
        let nice = cpuLoadInfo.cpu_ticks.3

        guard let previous = previousCPUInfo else {
            previousCPUInfo = cpuLoadInfo
            return (0, 0, 100)
        }

        let prevUser = previous.cpu_ticks.0
        let prevSystem = previous.cpu_ticks.1
        let prevIdle = previous.cpu_ticks.2
        let prevNice = previous.cpu_ticks.3

        // Handle counter wraparound
        let userDiff = user >= prevUser ? Double(user - prevUser) : Double(user)
        let systemDiff = system >= prevSystem ? Double(system - prevSystem) : Double(system)
        let idleDiff = idle >= prevIdle ? Double(idle - prevIdle) : Double(idle)
        let niceDiff = nice >= prevNice ? Double(nice - prevNice) : Double(nice)

        let totalDiff = userDiff + systemDiff + idleDiff + niceDiff

        previousCPUInfo = cpuLoadInfo

        guard totalDiff > 0 else {
            return (0, 0, 100)
        }

        // Calculate percentages and clamp to valid range
        let userPercent = min(100, max(0, (userDiff + niceDiff) / totalDiff * 100))
        let systemPercent = min(100, max(0, systemDiff / totalDiff * 100))
        let idlePercent = min(100, max(0, idleDiff / totalDiff * 100))

        return (userPercent, systemPercent, idlePercent)
    }

    // MARK: - CPU Temperature

    private func getCPUTemperature() -> Double {
        // Temperature requires elevated permissions or third-party tools
        // Return 0 if unavailable (UI will handle this gracefully)
        return getTemperatureViaThermalState()
    }

    private func getTemperatureViaThermalState() -> Double {
        // Use ProcessInfo thermal state as a rough indicator
        // This doesn't give exact temperature but indicates thermal pressure
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal: return 45
        case .fair: return 65
        case .serious: return 80
        case .critical: return 95
        @unknown default: return 0
        }
    }

    // MARK: - Load Average

    private func getLoadAverage() -> (Double, Double, Double) {
        var loadAvg = [Double](repeating: 0, count: 3)
        getloadavg(&loadAvg, 3)
        // Clamp to reasonable values (0-1000)
        let load1 = min(1000, max(0, loadAvg[0]))
        let load5 = min(1000, max(0, loadAvg[1]))
        let load15 = min(1000, max(0, loadAvg[2]))
        return (load1, load5, load15)
    }

    // MARK: - Uptime

    private func getUptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        if sysctl(&mib, 2, &boottime, &size, nil, 0) != -1 {
            let now = Date().timeIntervalSince1970
            let boot = Double(boottime.tv_sec)
            let uptime = now - boot
            // Validate: uptime should be positive and less than 10 years
            if uptime > 0 && uptime < 315_360_000 {
                return uptime
            }
        }
        AppLogger.cpu.debug("Failed to get uptime")
        return 0
    }

    // MARK: - GPU Usage

    private func getGPUUsage() -> (usage: Double, memoryPercent: Double, memoryBytes: UInt64, memoryTotal: UInt64, name: String) {
        // For Apple Silicon, GPU is integrated and stats require elevated permissions
        // We'll use a simplified approach based on process GPU usage
        return getGPUUsageViaIOKit()
    }

    private func getGPUUsageViaIOKit() -> (usage: Double, memoryPercent: Double, memoryBytes: UInt64, memoryTotal: UInt64, name: String) {
        let result = ProcessRunner.run(
            executable: "/usr/sbin/ioreg",
            arguments: ["-r", "-c", "IOAccelerator"],
            timeout: 5.0
        )

        switch result {
        case .success(let output):
            return parseGPUOutput(output)
        case .failure(let error):
            AppLogger.cpu.debug("Failed to get GPU stats: \(error.localizedDescription)")
            return (0, 0, 0, 0, "GPU")
        }
    }

    private func parseGPUOutput(_ output: String) -> (usage: Double, memoryPercent: Double, memoryBytes: UInt64, memoryTotal: UInt64, name: String) {
        var gpuUsage: Double = 0
        var gpuMemoryUsed: UInt64 = 0
        var gpuMemoryTotal: UInt64 = 0
        var gpuName = "GPU"

        // Try to get GPU name from "model" field (e.g., "Apple M3 Max")
        if let range = output.range(of: "\"model\" = \"") {
            let startIndex = range.upperBound
            if let endIndex = output[startIndex...].firstIndex(of: "\"") {
                gpuName = String(output[startIndex..<endIndex])
            }
        }
        // Fallback: try IOClass for discrete GPUs (e.g., AMD, NVIDIA)
        if gpuName == "GPU", let range = output.range(of: "\"IOClass\" = \"") {
            let startIndex = range.upperBound
            if let endIndex = output[startIndex...].firstIndex(of: "\"") {
                let ioClass = String(output[startIndex..<endIndex])
                if ioClass.contains("AMD") {
                    gpuName = "AMD GPU"
                } else if ioClass.contains("NVIDIA") || ioClass.contains("GeForce") {
                    gpuName = "NVIDIA GPU"
                } else if ioClass.contains("Intel") {
                    gpuName = "Intel GPU"
                }
            }
        }

        // Parse Device Utilization % from PerformanceStatistics
        if let range = output.range(of: "\"Device Utilization %\"=") {
            let startIndex = range.upperBound
            let remaining = output[startIndex...]
            var numStr = ""
            for char in remaining {
                if char.isNumber {
                    numStr.append(char)
                } else if !numStr.isEmpty {
                    break
                }
            }
            if let value = Double(numStr) {
                // Clamp to valid percentage
                gpuUsage = min(100, max(0, value))
            }
        }

        // Parse VRAM used (in bytes) - for discrete GPUs
        if let range = output.range(of: "\"VRAM,totalMB\" = ") {
            let startIndex = range.upperBound
            let endIndex = output[startIndex...].firstIndex(of: "\n") ?? output.endIndex
            let valueStr = String(output[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)
            if let value = UInt64(valueStr) {
                gpuMemoryTotal = value * 1024 * 1024
            }
        }

        if let range = output.range(of: "\"VRAM,freeMB\" = ") {
            let startIndex = range.upperBound
            let endIndex = output[startIndex...].firstIndex(of: "\n") ?? output.endIndex
            let valueStr = String(output[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)
            if let value = UInt64(valueStr) {
                let freeMemory = value * 1024 * 1024
                if gpuMemoryTotal > freeMemory {
                    gpuMemoryUsed = gpuMemoryTotal - freeMemory
                }
            }
        }

        // For Apple Silicon - parse "In use system memory" from PerformanceStatistics
        // This is the active GPU memory being used
        if let range = output.range(of: "\"In use system memory\"=") {
            let startIndex = range.upperBound
            let remaining = output[startIndex...]
            var numStr = ""
            for char in remaining {
                if char.isNumber {
                    numStr.append(char)
                } else if !numStr.isEmpty {
                    break
                }
            }
            if let memValue = UInt64(numStr) {
                gpuMemoryUsed = memValue
            }
        }

        // For Apple Silicon (no dedicated VRAM), use system RAM as reference
        if gpuMemoryTotal == 0 && gpuMemoryUsed > 0 {
            gpuMemoryTotal = ProcessInfo.processInfo.physicalMemory
        }

        // Calculate memory percentage and clamp to valid range
        var memPercent: Double = 0
        if gpuMemoryTotal > 0 {
            memPercent = min(100, max(0, Double(gpuMemoryUsed) / Double(gpuMemoryTotal) * 100))
        }

        return (gpuUsage, memPercent, gpuMemoryUsed, gpuMemoryTotal, gpuName)
    }

    // MARK: - Process Stats

    private func updateProcessStats() {
        let processes = getTopProcesses()

        DispatchQueue.main.async { [weak self] in
            self?.topProcesses = processes
        }
    }

    private func getTopProcesses() -> [ProcessCPUUsage] {
        var result: [ProcessCPUUsage] = []

        let runResult = ProcessRunner.run(
            executable: "/bin/ps",
            arguments: ["-Aceo", "pid,pcpu,comm", "-r"],
            timeout: 5.0
        )

        switch runResult {
        case .success(let output):
            let lines = output.components(separatedBy: "\n")
            var count = 0

            for line in lines {
                if count >= 5 { break }

                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("PID") { continue }

                let components = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                if components.count >= 3 {
                    if let pid = Int32(components[0]),
                       let cpu = Double(components[1]) {
                        let name = String(components[2])
                        let processName = (name as NSString).lastPathComponent

                        // Clamp CPU usage to valid range (0-800% for 8-core)
                        let clampedCPU = min(800, max(0, cpu))

                        if clampedCPU > 0 {
                            result.append(ProcessCPUUsage(
                                name: processName,
                                cpuUsage: clampedCPU,
                                pid: pid
                            ))
                            count += 1
                        }
                    }
                }
            }
        case .failure(let error):
            AppLogger.cpu.debug("Failed to get top processes: \(error.localizedDescription)")
        }

        return result
    }

    // MARK: - Memory Info

    private func getMemoryInfo() -> (used: UInt64, total: UInt64) {
        // Get total physical memory
        var totalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)

        // Get memory statistics using HOST_VM_INFO64
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            AppLogger.cpu.error("Failed to get memory info: kern_return \(result)")
            // Fallback: try HOST_VM_INFO (32-bit) for older systems
            return getMemoryInfoFallback(totalMemory: totalMemory)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        // Used memory = active + wired + compressed (excluding speculative/cached)
        var used = active + wired + compressed

        // Validate: used should not exceed total
        if used > totalMemory {
            AppLogger.cpu.warning("Memory used (\(used)) exceeds total (\(totalMemory)), clamping")
            used = totalMemory
        }

        return (used, totalMemory)
    }

    private func getMemoryInfoFallback(totalMemory: UInt64) -> (used: UInt64, total: UInt64) {
        // Fallback using 32-bit vm_statistics for older systems
        var stats = vm_statistics()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_VM_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            AppLogger.cpu.error("Failed to get memory info (fallback): kern_return \(result)")
            return (0, totalMemory)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize

        var used = active + wired

        // Validate: used should not exceed total
        if used > totalMemory {
            used = totalMemory
        }

        return (used, totalMemory)
    }

    // MARK: - Swap Info

    private func getSwapInfo() -> (used: UInt64, total: UInt64) {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size

        let result = sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)

        guard result == 0 else {
            AppLogger.cpu.debug("Failed to get swap info")
            return (0, 0)
        }

        // Validate: used should not exceed total
        let used = min(swapUsage.xsu_used, swapUsage.xsu_total)

        return (used, swapUsage.xsu_total)
    }
}
