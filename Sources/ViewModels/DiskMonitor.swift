import Foundation
import Darwin
import os.log

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

    // Computed property for system disk usage (the disk mounted at "/")
    var mainDiskUsage: Double {
        // Always show the system disk (root partition), not the largest disk
        if let systemDisk = disks.first(where: { $0.mountPoint == "/" }) {
            return systemDisk.usagePercentage
        }
        // Fallback to first disk if no root partition found
        return disks.first?.usagePercentage ?? 0
    }

    // MARK: - Disk Eject

    func ejectDisk(mountPoint: String, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let runResult = ProcessRunner.run(
                executable: "/usr/sbin/diskutil",
                arguments: ["eject", mountPoint],
                timeout: 30.0
            )

            DispatchQueue.main.async { [weak self] in
                switch runResult {
                case .success(let output):
                    AppLogger.disk.info("Ejected disk at \(mountPoint): \(output)")
                    // Refresh disk list after successful eject
                    self?.updateDisks()
                    completion(true, nil)
                case .failure(let error):
                    AppLogger.disk.error("Failed to eject disk at \(mountPoint): \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Private Properties

    private var timer: DispatchSourceTimer?
    private var processTimer: DispatchSourceTimer?
    private var healthCheckTimer: DispatchSourceTimer?
    private var previousDiskStats: [String: (read: UInt64, write: UInt64)] = [:]
    private var previousProcessStats: [Int32: (read: UInt64, write: UInt64)] = [:]

    // Track recently active processes to show even when current activity is 0
    private var recentProcessActivity: [Int32: RecentProcessActivity] = [:]
    private let recentActivityTimeout: TimeInterval = 15.0  // Keep showing for 15 seconds after last activity

    // Health check properties
    private var lastSuccessfulUpdate: Date?
    private let healthCheckInterval: TimeInterval = 30.0

    // Rate limiting
    private var lastUpdateTime: Date?
    private let minUpdateInterval: TimeInterval = 0.5

    // MARK: - Initialization

    init() {
        updateDisks()
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
        let queue = DispatchQueue(label: "com.macstatusbar.disk.health", qos: .utility)
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
            AppLogger.disk.warning("Disk monitor stale, restarting...")
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
        lastSuccessfulUpdate = Date()
        AppLogger.disk.debug("Disk monitoring started")
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
        guard shouldUpdate() else { return }

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
        ) else {
            AppLogger.disk.debug("Failed to get mounted volumes")
            return
        }

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

                // Validate capacity values
                let validTotal = UInt64(max(0, totalCapacity))
                let validAvailable = UInt64(max(0, min(availableCapacity, totalCapacity)))

                let diskInfo = DiskInfo(
                    name: name,
                    mountPoint: volumeURL.path,
                    totalSpace: validTotal,
                    freeSpace: validAvailable,
                    isNetworkDisk: !isLocal,
                    isRemovable: isRemovable
                )

                if isLocal {
                    localDisks.append(diskInfo)
                } else {
                    netDisks.append(diskInfo)
                }
            } catch {
                AppLogger.disk.debug("Failed to get resource values for \(volumeURL.path): \(error.localizedDescription)")
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

        lastUpdateTime = Date()
        lastSuccessfulUpdate = Date()
    }

    // MARK: - Disk I/O

    private func updateDiskIO() {
        let stats = getDiskIOStats()

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        for (disk, current) in stats {
            if let previous = previousDiskStats[disk] {
                // Handle counter wraparound
                let readDelta = current.read >= previous.read ? current.read - previous.read : current.read
                let writeDelta = current.write >= previous.write ? current.write - previous.write : current.write
                totalRead += readDelta
                totalWrite += writeDelta
            }
        }

        previousDiskStats = stats

        // Convert to bytes per second (we poll every 2 seconds)
        // Clamp to reasonable values (max 10 GB/s for NVMe)
        let maxSpeed: Double = 10_000_000_000
        let readSpeed = min(maxSpeed, max(0, Double(totalRead) / 2.0))
        let writeSpeed = min(maxSpeed, max(0, Double(totalWrite) / 2.0))

        DispatchQueue.main.async { [weak self] in
            self?.totalReadSpeed = readSpeed
            self?.totalWriteSpeed = writeSpeed
        }
    }

    private func getDiskIOStats() -> [String: (read: UInt64, write: UInt64)] {
        var result: [String: (read: UInt64, write: UInt64)] = [:]

        // Use iostat to get disk I/O statistics
        let runResult = ProcessRunner.run(
            executable: "/usr/sbin/iostat",
            arguments: ["-d", "-c", "1"],
            timeout: 5.0
        )

        switch runResult {
        case .success(let output):
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
        case .failure(let error):
            AppLogger.disk.debug("iostat failed: \(error.localizedDescription)")
        }

        // Alternative: use ioreg for disk statistics
        return getDiskIOViaIOReg()
    }

    private func getDiskIOViaIOReg() -> [String: (read: UInt64, write: UInt64)] {
        var result: [String: (read: UInt64, write: UInt64)] = [:]

        let runResult = ProcessRunner.run(
            executable: "/usr/sbin/ioreg",
            arguments: ["-r", "-c", "IOBlockStorageDriver", "-d", "1"],
            timeout: 5.0
        )

        switch runResult {
        case .success(let output):
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
        case .failure(let error):
            AppLogger.disk.debug("ioreg failed: \(error.localizedDescription)")
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

        // Get process list with all processes (no limit)
        let runResult = ProcessRunner.run(
            executable: "/bin/ps",
            arguments: ["-Aceo", "pid,comm"],
            timeout: 5.0
        )

        switch runResult {
        case .success(let output):
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

            // Get I/O stats for ALL processes (removed the .prefix(100) limit)
            for (pid, name) in processes {
                if let ioStats = getProcessIOStats(pid: pid) {
                    let prev = previousProcessStats[pid]
                    previousProcessStats[pid] = ioStats

                    // Skip first measurement for new processes to avoid inflated values
                    // proc_pid_rusage returns cumulative stats since process start,
                    // so the first reading would treat the entire history as a 2-second delta
                    guard let prevStats = prev else {
                        continue
                    }

                    // Handle counter wraparound
                    let readDelta = ioStats.read >= prevStats.read ? ioStats.read - prevStats.read : ioStats.read
                    let writeDelta = ioStats.write >= prevStats.write ? ioStats.write - prevStats.write : ioStats.write

                    // Calculate speed (poll every 2s)
                    // Clamp to reasonable values (max 5 GB/s per process)
                    let maxProcessSpeed: Double = 5_000_000_000
                    let readSpeed = min(maxProcessSpeed, max(0, Double(readDelta) / 2.0))
                    let writeSpeed = min(maxProcessSpeed, max(0, Double(writeDelta) / 2.0))
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

            // Clean up previousProcessStats for processes that no longer exist
            previousProcessStats = previousProcessStats.filter { currentPids.contains($0.key) }

            // Remove entries for processes that no longer exist or have timed out
            recentProcessActivity = recentProcessActivity.filter { (pid, activity) in
                // Keep if process still exists and hasn't timed out
                let isStillRunning = currentPids.contains(pid)
                let isRecent = now.timeIntervalSince(activity.lastActiveTime) < recentActivityTimeout
                return isStillRunning && isRecent
            }

        case .failure(let error):
            AppLogger.disk.debug("Failed to get process list: \(error.localizedDescription)")
        }

        // Build result from recent activity, sorted by current speed (most active first)
        // Only include processes with current activity
        let result = recentProcessActivity.values
            .filter { $0.currentReadSpeed > 0 || $0.currentWriteSpeed > 0 }
            .sorted { ($0.currentReadSpeed + $0.currentWriteSpeed) > ($1.currentReadSpeed + $1.currentWriteSpeed) }
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

        // Use both disk I/O and logical writes for more accurate tracking
        // ri_diskio_bytesread/written tracks physical disk I/O
        // ri_logical_writes tracks logical writes which may be more accurate for buffered I/O
        let readBytes = rusageInfo.ri_diskio_bytesread
        let writeBytes = max(rusageInfo.ri_diskio_byteswritten, rusageInfo.ri_logical_writes)

        return (readBytes, writeBytes)
    }
}
