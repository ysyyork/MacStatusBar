import Foundation
import Darwin

// Required for proc_pid_rusage
@_silgen_name("proc_pid_rusage")
func proc_pid_rusage(_ pid: Int32, _ flavor: Int32, _ buffer: UnsafeMutablePointer<rusage_info_v4>) -> Int32

// MARK: - Data Models

struct DiskInfo: Identifiable {
    let id = UUID()
    let name: String
    let mountPoint: String
    let totalSpace: UInt64
    let freeSpace: UInt64
    let isNetworkDisk: Bool
    let isRemovable: Bool

    var usedSpace: UInt64 {
        totalSpace > freeSpace ? totalSpace - freeSpace : 0
    }

    var usagePercentage: Double {
        totalSpace > 0 ? Double(usedSpace) / Double(totalSpace) : 0
    }
}

struct ProcessDiskUsage: Identifiable {
    let id = UUID()
    let name: String
    let readSpeed: Double
    let writeSpeed: Double
    let pid: Int32
}

// Internal struct for tracking recent process activity
struct RecentProcessActivity {
    let name: String
    let pid: Int32
    var totalActivity: UInt64  // Cumulative read + write since tracking started
    var lastActiveTime: Date   // Last time this process had non-zero activity
    var currentReadSpeed: Double
    var currentWriteSpeed: Double
}

// MARK: - Disk Monitor (ViewModel)

final class DiskMonitor: ObservableObject {
    // MARK: - Published Properties

    @Published var disks: [DiskInfo] = []
    @Published var networkDisks: [DiskInfo] = []
    @Published var topProcesses: [ProcessDiskUsage] = []
    @Published var totalReadSpeed: Double = 0
    @Published var totalWriteSpeed: Double = 0

    // Computed property for main disk usage (first/largest local disk)
    var mainDiskUsage: Double {
        disks.first?.usagePercentage ?? 0
    }

    // MARK: - Private Properties

    private var timer: DispatchSourceTimer?
    private var processTimer: DispatchSourceTimer?
    private var previousDiskStats: [String: (read: UInt64, write: UInt64)] = [:]
    private var previousProcessStats: [Int32: (read: UInt64, write: UInt64)] = [:]

    // Track recently active processes to show even when current activity is 0
    private var recentProcessActivity: [Int32: RecentProcessActivity] = [:]
    private let recentActivityTimeout: TimeInterval = 15.0  // Keep showing for 15 seconds after last activity

    // MARK: - Initialization

    init() {
        updateDisks()
        startMonitoring()
        startProcessMonitoring()
    }

    deinit {
        timer?.cancel()
        timer = nil
        processTimer?.cancel()
        processTimer = nil
    }

    // MARK: - Monitoring Control

    private func startMonitoring() {
        let queue = DispatchQueue(label: "com.macstatusbar.disk", qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: 2.0)
        timer?.setEventHandler { [weak self] in
            self?.updateDisks()
            self?.updateDiskIO()
        }
        timer?.resume()
    }

    private func startProcessMonitoring() {
        let queue = DispatchQueue(label: "com.macstatusbar.disk.process", qos: .utility)
        processTimer = DispatchSource.makeTimerSource(queue: queue)
        processTimer?.schedule(deadline: .now() + 1, repeating: 2.0)
        processTimer?.setEventHandler { [weak self] in
            self?.updateProcessStats()
        }
        processTimer?.resume()
    }

    // MARK: - Disk Info

    private func updateDisks() {
        var localDisks: [DiskInfo] = []
        var netDisks: [DiskInfo] = []

        let fileManager = FileManager.default
        guard let mountedVolumes = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeIsRemovableKey,
                .volumeIsLocalKey
            ],
            options: [.skipHiddenVolumes]
        ) else { return }

        for volumeURL in mountedVolumes {
            do {
                let resourceValues = try volumeURL.resourceValues(forKeys: [
                    .volumeNameKey,
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityKey,
                    .volumeIsRemovableKey,
                    .volumeIsLocalKey
                ])

                guard let name = resourceValues.volumeName,
                      let totalCapacity = resourceValues.volumeTotalCapacity,
                      let availableCapacity = resourceValues.volumeAvailableCapacity else {
                    continue
                }

                let isLocal = resourceValues.volumeIsLocal ?? true
                let isRemovable = resourceValues.volumeIsRemovable ?? false

                // Skip system volumes and tiny partitions
                if totalCapacity < 1_000_000_000 { continue } // Skip < 1GB
                if name == "Recovery" || name == "Preboot" || name == "VM" { continue }

                let diskInfo = DiskInfo(
                    name: name,
                    mountPoint: volumeURL.path,
                    totalSpace: UInt64(totalCapacity),
                    freeSpace: UInt64(availableCapacity),
                    isNetworkDisk: !isLocal,
                    isRemovable: isRemovable
                )

                if isLocal {
                    localDisks.append(diskInfo)
                } else {
                    netDisks.append(diskInfo)
                }
            } catch {
                continue
            }
        }

        // Sort by size (largest first)
        localDisks.sort { $0.totalSpace > $1.totalSpace }
        netDisks.sort { $0.totalSpace > $1.totalSpace }

        DispatchQueue.main.async { [weak self] in
            self?.disks = localDisks
            self?.networkDisks = netDisks
        }
    }

    // MARK: - Disk I/O

    private func updateDiskIO() {
        let stats = getDiskIOStats()

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        for (disk, current) in stats {
            if let previous = previousDiskStats[disk] {
                let readDelta = current.read >= previous.read ? current.read - previous.read : 0
                let writeDelta = current.write >= previous.write ? current.write - previous.write : 0
                totalRead += readDelta
                totalWrite += writeDelta
            }
        }

        previousDiskStats = stats

        // Convert to bytes per second (we poll every 2 seconds)
        let readSpeed = Double(totalRead) / 2.0
        let writeSpeed = Double(totalWrite) / 2.0

        DispatchQueue.main.async { [weak self] in
            self?.totalReadSpeed = readSpeed
            self?.totalWriteSpeed = writeSpeed
        }
    }

    private func getDiskIOStats() -> [String: (read: UInt64, write: UInt64)] {
        var result: [String: (read: UInt64, write: UInt64)] = [:]

        // Use iostat to get disk I/O statistics
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/iostat")
        task.arguments = ["-d", "-c", "1"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("disk") || trimmed.isEmpty || trimmed.contains("KB/t") {
                        continue
                    }

                    let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
                    if components.count >= 3 {
                        // iostat output: KB/t tps MB/s
                        // We need cumulative bytes, so use activity monitor approach
                    }
                }
            }
        } catch {
            // Silently fail
        }

        // Alternative: use ioreg for disk statistics
        return getDiskIOViaIOReg()
    }

    private func getDiskIOViaIOReg() -> [String: (read: UInt64, write: UInt64)] {
        var result: [String: (read: UInt64, write: UInt64)] = [:]

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        task.arguments = ["-r", "-c", "IOBlockStorageDriver", "-d", "1"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var currentDisk = "disk"
                var bytesRead: UInt64 = 0
                var bytesWritten: UInt64 = 0

                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    if line.contains("\"Bytes (Read)\"") {
                        if let value = extractNumber(from: line) {
                            bytesRead = value
                        }
                    } else if line.contains("\"Bytes (Write)\"") {
                        if let value = extractNumber(from: line) {
                            bytesWritten = value
                        }
                    }
                }

                if bytesRead > 0 || bytesWritten > 0 {
                    result[currentDisk] = (bytesRead, bytesWritten)
                }
            }
        } catch {
            // Silently fail
        }

        return result
    }

    private func extractNumber(from line: String) -> UInt64? {
        let parts = line.components(separatedBy: "=")
        if parts.count > 1 {
            let numStr = parts[1].trimmingCharacters(in: .whitespaces)
            return UInt64(numStr)
        }
        return nil
    }

    // MARK: - Process Stats

    private func updateProcessStats() {
        let processes = getTopDiskProcesses()

        DispatchQueue.main.async { [weak self] in
            self?.topProcesses = processes
        }
    }

    private func getTopDiskProcesses() -> [ProcessDiskUsage] {
        let now = Date()

        // Use fs_usage or iotop equivalent
        // Since fs_usage requires root, we'll use a different approach
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-Aceo", "pid,comm"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var processes: [(pid: Int32, name: String)] = []

                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty || trimmed.hasPrefix("PID") { continue }

                    let components = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                    if components.count >= 2,
                       let pid = Int32(components[0]) {
                        let name = String(components[1])
                        let processName = (name as NSString).lastPathComponent
                        processes.append((pid, processName))
                    }
                }

                // Get current running PIDs for cleanup
                let currentPids = Set(processes.map { $0.pid })

                // Get I/O stats for each process using /proc equivalent on macOS
                for (pid, name) in processes.prefix(100) {
                    if let ioStats = getProcessIOStats(pid: pid) {
                        let prev = previousProcessStats[pid] ?? (0, 0)
                        let readDelta = ioStats.read >= prev.read ? ioStats.read - prev.read : 0
                        let writeDelta = ioStats.write >= prev.write ? ioStats.write - prev.write : 0

                        previousProcessStats[pid] = ioStats

                        // Calculate speed (poll every 2s)
                        let readSpeed = Double(readDelta) / 2.0
                        let writeSpeed = Double(writeDelta) / 2.0
                        let hasActivity = readSpeed > 0 || writeSpeed > 0

                        // Update or create recent activity entry
                        if hasActivity {
                            if var existing = recentProcessActivity[pid] {
                                existing.totalActivity += readDelta + writeDelta
                                existing.lastActiveTime = now
                                existing.currentReadSpeed = readSpeed
                                existing.currentWriteSpeed = writeSpeed
                                recentProcessActivity[pid] = existing
                            } else {
                                recentProcessActivity[pid] = RecentProcessActivity(
                                    name: name,
                                    pid: pid,
                                    totalActivity: readDelta + writeDelta,
                                    lastActiveTime: now,
                                    currentReadSpeed: readSpeed,
                                    currentWriteSpeed: writeSpeed
                                )
                            }
                        } else if var existing = recentProcessActivity[pid] {
                            // Process exists but no current activity - update speeds to 0
                            existing.currentReadSpeed = 0
                            existing.currentWriteSpeed = 0
                            recentProcessActivity[pid] = existing
                        }
                    }
                }

                // Remove entries for processes that no longer exist or have timed out
                recentProcessActivity = recentProcessActivity.filter { (pid, activity) in
                    // Keep if process still exists and hasn't timed out
                    let isStillRunning = currentPids.contains(pid)
                    let isRecent = now.timeIntervalSince(activity.lastActiveTime) < recentActivityTimeout
                    return isStillRunning && isRecent
                }
            }
        } catch {
            // Silently fail
        }

        // Build result from recent activity, sorted by total activity
        var result = recentProcessActivity.values
            .sorted { $0.totalActivity > $1.totalActivity }
            .prefix(5)
            .map { activity in
                ProcessDiskUsage(
                    name: activity.name,
                    readSpeed: activity.currentReadSpeed,
                    writeSpeed: activity.currentWriteSpeed,
                    pid: activity.pid
                )
            }

        return Array(result)
    }

    private func getProcessIOStats(pid: Int32) -> (read: UInt64, write: UInt64)? {
        var rusageInfo = rusage_info_v4()
        let result = proc_pid_rusage(pid, RUSAGE_INFO_V4, &rusageInfo)

        guard result == 0 else {
            return nil
        }

        // ri_diskio_bytesread and ri_diskio_byteswritten contain disk I/O
        return (rusageInfo.ri_diskio_bytesread, rusageInfo.ri_diskio_byteswritten)
    }
}
