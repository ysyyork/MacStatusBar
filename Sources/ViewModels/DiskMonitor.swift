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
    // totalReadSpeed/totalWriteSpeed cover the internal system disk only, so an
    // attached external drive doing heavy I/O doesn't make the menu bar icon
    // look like the internal disk is busy. Each external physical disk gets
    // its own entry in externalDiskSpeeds, keyed by whole-disk BSD name (e.g.
    // "disk11"); mounted disk images are excluded from both.
    @Published var totalReadSpeed: Double = 0
    @Published var totalWriteSpeed: Double = 0
    @Published var externalDiskSpeeds: [String: (read: Double, write: Double)] = [:]
    @Published var mountPointToWholeDiskID: [String: String] = [:]

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
                    // Refresh disk list after successful eject, bypassing rate limit
                    self?.updateDisks(force: true)
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
    private var diskIOTimer: DispatchSourceTimer?
    private var healthCheckTimer: DispatchSourceTimer?
    private var previousDiskStats: [String: (read: UInt64, write: UInt64)] = [:]
    private var previousProcessStats: [Int32: (read: UInt64, write: UInt64)] = [:]

    // Caches for classifying ioreg's whole-disk BSD IDs (internal vs. external
    // physical vs. disk image) and for mapping a mounted volume's mount point
    // to its underlying whole-disk BSD ID. Both are stable for as long as a
    // disk stays attached, so caching avoids a diskutil subprocess call per
    // poll — only the first sighting of a given disk pays that cost.
    private var wholeDiskClassificationCache: [String: (isInternal: Bool, isPhysical: Bool)] = [:]
    private var mountPointWholeDiskCache: [String: String] = [:]
    private var containerToPhysicalCache: [String: String] = [:]

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
        startDiskIOMonitoring()
        startHealthCheckTimer()
    }

    deinit {
        timer?.setEventHandler(handler: nil)
        timer?.cancel()
        timer = nil
        processTimer?.setEventHandler(handler: nil)
        processTimer?.cancel()
        processTimer = nil
        diskIOTimer?.setEventHandler(handler: nil)
        diskIOTimer?.cancel()
        diskIOTimer = nil
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
           Date().timeIntervalSince(lastUpdate) > 10.0 {
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

    private func startDiskIOMonitoring() {
        // ioreg-based I/O throughput is spawned as a subprocess, which is slower and
        // less predictable than the in-process FileManager calls used for disk usage.
        // Polling it on its own timer keeps a slow sample from delaying the disk
        // usage percentage shown in the menu bar.
        let queue = DispatchQueue(label: "com.macstatusbar.disk.io", qos: .utility)
        diskIOTimer = DispatchSource.makeTimerSource(queue: queue)
        diskIOTimer?.schedule(deadline: .now(), repeating: 2.0)
        diskIOTimer?.setEventHandler { [weak self] in
            self?.updateDiskIO()
        }
        diskIOTimer?.resume()
    }

    // MARK: - Disk Info

    private func updateDisks(force: Bool = false) {
        guard force || shouldUpdate() else { return }

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
        // Stats are keyed by whole-disk BSD name (e.g. "disk0", "disk11"),
        // one entry per physical/virtual block storage device ioreg reports.
        let stats = getDiskIOStats()

        var internalReadDelta: UInt64 = 0
        var internalWriteDelta: UInt64 = 0
        var externalDeltas: [String: (read: UInt64, write: UInt64)] = [:]

        for (wholeDiskID, current) in stats {
            guard let previous = previousDiskStats[wholeDiskID] else { continue }

            // Handle counter wraparound
            let readDelta = current.read >= previous.read ? current.read - previous.read : current.read
            let writeDelta = current.write >= previous.write ? current.write - previous.write : current.write

            let classification = classifyWholeDisk(wholeDiskID)
            if classification.isInternal {
                internalReadDelta += readDelta
                internalWriteDelta += writeDelta
            } else if classification.isPhysical {
                externalDeltas[wholeDiskID] = (readDelta, writeDelta)
            }
            // Anything else (a mounted disk image, an unresolvable device) is
            // neither the internal disk nor a real external drive, so it's
            // deliberately left out of both totals.
        }

        previousDiskStats = stats

        // Convert to bytes per second (we poll every 2 seconds)
        // Clamp to reasonable values (max 10 GB/s for NVMe)
        let maxSpeed: Double = 10_000_000_000
        let internalReadSpeed = min(maxSpeed, max(0, Double(internalReadDelta) / 2.0))
        let internalWriteSpeed = min(maxSpeed, max(0, Double(internalWriteDelta) / 2.0))
        let externalSpeeds = externalDeltas.mapValues { delta in
            (
                read: min(maxSpeed, max(0, Double(delta.read) / 2.0)),
                write: min(maxSpeed, max(0, Double(delta.write) / 2.0))
            )
        }

        // Resolve each currently-mounted non-root volume to the whole-disk ID
        // its speed should come from. Cheap: statfs is in-process, and the
        // one diskutil call needed for APFS-container volumes is cached per
        // disk after the first sighting.
        let externalMountPoints = disks.filter { $0.mountPoint != "/" }.map { $0.mountPoint }
        var mountPointMapping: [String: String] = [:]
        for mountPoint in externalMountPoints {
            if let wholeDiskID = resolveWholeDiskID(forMountPoint: mountPoint) {
                mountPointMapping[mountPoint] = wholeDiskID
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.totalReadSpeed = internalReadSpeed
            self?.totalWriteSpeed = internalWriteSpeed
            self?.externalDiskSpeeds = externalSpeeds
            self?.mountPointToWholeDiskID = mountPointMapping
        }
    }

    private func getDiskIOStats() -> [String: (read: UInt64, write: UInt64)] {
        return getDiskIOViaIOReg()
    }

    private func getDiskIOViaIOReg() -> [String: (read: UInt64, write: UInt64)] {
        var result: [String: (read: UInt64, write: UInt64)] = [:]

        let runResult = ProcessRunner.run(
            executable: "/usr/sbin/ioreg",
            arguments: ["-r", "-c", "IOBlockStorageDriver", "-d", "2", "-l"],
            timeout: 5.0
        )

        switch runResult {
        case .success(let output):
            // Each driver's own "Statistics" dict comes first, followed by its
            // direct child IOMedia (the whole raw disk, not a partition) which
            // carries "BSD Name". We accumulate both per block and commit once
            // we hit the next driver (or the end of output).
            var currentBytesRead: UInt64 = 0
            var currentBytesWritten: UInt64 = 0
            var currentBSDName: String?

            func commitCurrentEntry() {
                if let bsdName = currentBSDName, currentBytesRead > 0 || currentBytesWritten > 0 {
                    result[bsdName] = (currentBytesRead, currentBytesWritten)
                }
                currentBytesRead = 0
                currentBytesWritten = 0
                currentBSDName = nil
            }

            let lines = output.components(separatedBy: "\n")
            for line in lines {
                if line.contains("<class IOBlockStorageDriver") {
                    commitCurrentEntry()
                } else if line.contains("\"Statistics\"") {
                    currentBytesRead = Self.extractStatValue(from: line, key: "Bytes (Read)") ?? 0
                    currentBytesWritten = Self.extractStatValue(from: line, key: "Bytes (Write)") ?? 0
                } else if line.contains("\"BSD Name\""),
                          let range = line.range(of: "= \"") {
                    let remaining = line[range.upperBound...]
                    if let endIndex = remaining.firstIndex(of: "\"") {
                        currentBSDName = String(remaining[..<endIndex])
                    }
                }
            }
            commitCurrentEntry()
        case .failure(let error):
            AppLogger.disk.debug("ioreg failed: \(error.localizedDescription)")
        }

        return result
    }

    /// Classifies a whole-disk BSD ID (e.g. "disk0", "disk11") using diskutil,
    /// distinguishing the internal disk, real external physical disks, and
    /// mounted disk images (which report as external but virtual).
    private func classifyWholeDisk(_ wholeDiskID: String) -> (isInternal: Bool, isPhysical: Bool) {
        if let cached = wholeDiskClassificationCache[wholeDiskID] {
            return cached
        }

        var classification = (isInternal: false, isPhysical: false)
        let runResult = ProcessRunner.run(
            executable: "/usr/sbin/diskutil",
            arguments: ["info", "-plist", wholeDiskID],
            timeout: 5.0
        )
        if case .success(let output) = runResult, let data = output.data(using: .utf8) {
            classification = Self.parseClassification(fromDiskutilPlistData: data)
        }

        wholeDiskClassificationCache[wholeDiskID] = classification
        return classification
    }

    /// Extracts (isInternal, isPhysical) from `diskutil info -plist <disk>`
    /// output. isPhysical is true only for "VirtualOrPhysical" == "Physical",
    /// which excludes mounted disk images (reported as "Virtual").
    static func parseClassification(fromDiskutilPlistData data: Data) -> (isInternal: Bool, isPhysical: Bool) {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return (isInternal: false, isPhysical: false)
        }
        let isInternal = plist["Internal"] as? Bool ?? false
        let virtualOrPhysical = plist["VirtualOrPhysical"] as? String ?? "Unknown"
        return (isInternal: isInternal, isPhysical: virtualOrPhysical == "Physical")
    }

    /// Resolves a mounted volume's mount point to the whole-disk BSD ID its
    /// I/O stats should come from, hopping from an APFS container (e.g.
    /// "disk13") to its underlying physical store (e.g. "disk14") when needed.
    private func resolveWholeDiskID(forMountPoint mountPoint: String) -> String? {
        if let cached = mountPointWholeDiskCache[mountPoint] {
            return cached
        }

        var buf = statfs()
        guard statfs(mountPoint, &buf) == 0 else { return nil }

        let mntFromName = withUnsafeBytes(of: &buf.f_mntfromname) { rawBuffer -> String in
            let ptr = rawBuffer.baseAddress!.assumingMemoryBound(to: CChar.self)
            return String(cString: ptr)
        }

        guard mntFromName.hasPrefix("/dev/disk"),
              let wholeDiskPrefix = Self.wholeDiskPrefix(fromBSDPath: mntFromName) else { return nil }

        let resolved = resolvePhysicalWholeDisk(wholeDiskPrefix)
        mountPointWholeDiskCache[mountPoint] = resolved
        return resolved
    }

    /// Extracts the whole-disk prefix (e.g. "disk3") from a BSD device path
    /// or name that may include a partition/snapshot suffix, e.g.
    /// "/dev/disk3s1s1" or "disk11s2" both resolve to their leading "diskN".
    static func wholeDiskPrefix(fromBSDPath path: String) -> String? {
        let name = path.hasPrefix("/dev/") ? String(path.dropFirst("/dev/".count)) : path
        guard let match = name.range(of: "^disk[0-9]+", options: .regularExpression) else { return nil }
        return String(name[match])
    }

    private func resolvePhysicalWholeDisk(_ wholeDiskID: String) -> String {
        if let cached = containerToPhysicalCache[wholeDiskID] {
            return cached
        }

        var resolved = wholeDiskID
        let runResult = ProcessRunner.run(
            executable: "/usr/sbin/diskutil",
            arguments: ["info", "-plist", wholeDiskID],
            timeout: 5.0
        )
        if case .success(let output) = runResult,
           let data = output.data(using: .utf8),
           let physicalStoreWholeDisk = Self.parsePhysicalStoreWholeDisk(fromDiskutilPlistData: data) {
            resolved = physicalStoreWholeDisk
        }

        containerToPhysicalCache[wholeDiskID] = resolved
        return resolved
    }

    /// Extracts the whole-disk ID backing an APFS container's first physical
    /// store from `diskutil info -plist <container>` output, e.g. an
    /// "APFSPhysicalStore" of "disk0s2" resolves to "disk0". Returns nil if
    /// the disk isn't a synthesized APFS container (e.g. it's already a
    /// physical disk's own partition).
    static func parsePhysicalStoreWholeDisk(fromDiskutilPlistData data: Data) -> String? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let physicalStores = plist["APFSPhysicalStores"] as? [[String: Any]],
              let physicalStoreBSD = physicalStores.first?["APFSPhysicalStore"] as? String else {
            return nil
        }
        return wholeDiskPrefix(fromBSDPath: physicalStoreBSD)
    }

    /// Extracts a numeric value for `key` out of an inline dict line like
    /// `"Statistics" = {"Bytes (Read)"=1692324421632,"Bytes (Write)"=...}`.
    /// Naively splitting the whole line on "=" doesn't work since every key
    /// in the dict shares the same line.
    static func extractStatValue(from line: String, key: String) -> UInt64? {
        guard let range = line.range(of: "\"\(key)\"=") else { return nil }
        let remaining = line[range.upperBound...]
        var numStr = ""
        for char in remaining {
            if char.isNumber {
                numStr.append(char)
            } else if !numStr.isEmpty {
                break
            }
        }
        return UInt64(numStr)
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
