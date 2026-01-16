import Foundation
import Darwin
import Combine

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
    @Published var processorName: String = "—"
    @Published var fps: Double = 0
    @Published var memoryUsed: UInt64 = 0
    @Published var memoryTotal: UInt64 = 0
    @Published var swapUsed: UInt64 = 0
    @Published var swapTotal: UInt64 = 0

    // MARK: - Private Properties

    private var timer: DispatchSourceTimer?
    private var processTimer: DispatchSourceTimer?
    private var previousCPUInfo: host_cpu_load_info?
    private var cachedProcessorName: String?

    // MARK: - Initialization

    init() {
        fetchProcessorNameAsync()
        startMonitoring()
        startProcessMonitoring()
    }

    deinit {
        timer?.cancel()
        timer = nil
        processTimer?.cancel()
        processTimer = nil
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
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPHardwareDataType", "-json"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let hardware = json["SPHardwareDataType"] as? [[String: Any]],
               let first = hardware.first,
               let chipType = first["chip_type"] as? String {
                return chipType
            }
        } catch {
            // Silently fail
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
        let cpuUsage = getCPUUsage()
        let temp = getCPUTemperature()
        let load = getLoadAverage()
        let uptimeVal = getUptime()
        let (gpu, gpuMem) = getGPUUsage()
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
            self.gpuUsage = gpu
            self.gpuMemoryUsage = gpuMem
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
    }

    // MARK: - CPU Usage

    private func getCPUUsage() -> (user: Double, system: Double, idle: Double) {
        var cpuInfo: host_cpu_load_info?
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)

        let hostPort = mach_host_self()
        var cpuLoadInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, 0, 100)
        }

        cpuInfo = cpuLoadInfo

        guard let current = cpuInfo, let previous = previousCPUInfo else {
            previousCPUInfo = cpuInfo
            return (0, 0, 100)
        }

        let userDiff = Double(current.cpu_ticks.0 - previous.cpu_ticks.0)
        let systemDiff = Double(current.cpu_ticks.1 - previous.cpu_ticks.1)
        let idleDiff = Double(current.cpu_ticks.2 - previous.cpu_ticks.2)
        let niceDiff = Double(current.cpu_ticks.3 - previous.cpu_ticks.3)

        let totalDiff = userDiff + systemDiff + idleDiff + niceDiff

        previousCPUInfo = cpuInfo

        guard totalDiff > 0 else {
            return (0, 0, 100)
        }

        let userPercent = (userDiff + niceDiff) / totalDiff * 100
        let systemPercent = systemDiff / totalDiff * 100
        let idlePercent = idleDiff / totalDiff * 100

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
        return (loadAvg[0], loadAvg[1], loadAvg[2])
    }

    // MARK: - Uptime

    private func getUptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        if sysctl(&mib, 2, &boottime, &size, nil, 0) != -1 {
            let now = Date().timeIntervalSince1970
            let boot = Double(boottime.tv_sec)
            return now - boot
        }
        return 0
    }

    // MARK: - GPU Usage

    private func getGPUUsage() -> (usage: Double, memory: Double) {
        // For Apple Silicon, GPU is integrated and stats require elevated permissions
        // We'll use a simplified approach based on process GPU usage
        return getGPUUsageViaIOKit()
    }

    private func getGPUUsageViaIOKit() -> (usage: Double, memory: Double) {
        // Try to get GPU stats from ioreg
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        task.arguments = ["-r", "-c", "IOAccelerator", "-d", "1"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var gpuUsage: Double = 0

                // Parse Device Utilization %
                if let range = output.range(of: "\"Device Utilization %\" = ") {
                    let startIndex = range.upperBound
                    let endIndex = output[startIndex...].firstIndex(of: "\n") ?? output.endIndex
                    let valueStr = String(output[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)
                    if let value = Double(valueStr) {
                        gpuUsage = value
                    }
                }

                return (gpuUsage, 0)
            }
        } catch {
            // Silently fail
        }

        return (0, 0)
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

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-Aceo", "pid,pcpu,comm", "-r"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
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

                            if cpu > 0 {
                                result.append(ProcessCPUUsage(
                                    name: processName,
                                    cpuUsage: cpu,
                                    pid: pid
                                ))
                                count += 1
                            }
                        }
                    }
                }
            }
        } catch {
            // Silently fail
        }

        return result
    }

    // MARK: - Memory Info

    private func getMemoryInfo() -> (used: UInt64, total: UInt64) {
        // Get total physical memory
        var totalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)

        // Get memory statistics
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, totalMemory)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let speculative = UInt64(stats.speculative_count) * pageSize

        // Used memory = active + wired + compressed (excluding speculative/cached)
        let used = active + wired + compressed

        return (used, totalMemory)
    }

    // MARK: - Swap Info

    private func getSwapInfo() -> (used: UInt64, total: UInt64) {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size

        let result = sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)

        guard result == 0 else {
            return (0, 0)
        }

        return (swapUsage.xsu_used, swapUsage.xsu_total)
    }
}
