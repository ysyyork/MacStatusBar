import SwiftUI

// MARK: - Disk Menu Content View (MVVM - View Layer)

struct DiskMenuContentView: View {
    @ObservedObject var monitor: DiskMonitor
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // DISKS Header
            SectionHeader(title: "DISKS")

            // Local Disks
            VStack(spacing: 8) {
                ForEach(monitor.disks) { disk in
                    DiskItemView(disk: disk, readSpeed: monitor.totalReadSpeed, writeSpeed: monitor.totalWriteSpeed)
                }

                if monitor.disks.isEmpty {
                    Text("No disks found")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // NETWORK DISKS Header (only show if there are network disks)
            if !monitor.networkDisks.isEmpty {
                Divider()
                    .padding(.horizontal, 12)

                SectionHeader(title: "NETWORK DISKS")

                VStack(spacing: 8) {
                    ForEach(monitor.networkDisks) { disk in
                        NetworkDiskItemView(disk: disk)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // PROCESSES Header (only show if there are active processes)
            if !monitor.topProcesses.isEmpty {
                Divider()
                    .padding(.horizontal, 12)

                SectionHeader(title: "PROCESSES")

                // Process list
                VStack(spacing: 4) {
                    // Header row
                    HStack {
                        Text("Name")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("R")
                            .foregroundColor(.cyan)
                            .frame(width: 65, alignment: .trailing)
                        Text("W")
                            .foregroundColor(.orange)
                            .frame(width: 65, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                    ForEach(monitor.topProcesses) { process in
                        HStack {
                            // Process icon
                            ProcessIconView(pid: process.pid, processName: process.name, size: 14)
                            Text(process.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(formatDiskSpeed(process.readSpeed))
                                .frame(width: 65, alignment: .trailing)
                            Text(formatDiskSpeed(process.writeSpeed))
                                .frame(width: 65, alignment: .trailing)
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            Divider()
                .padding(.horizontal, 12)

            // Settings and Quit Buttons
            MenuFooterButtons()
        }
        .frame(width: 300)
        .padding(.vertical, 8)
    }

    private func formatDiskSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond <= 0 {
            return "—"
        }
        return ByteFormatter.compactSpeed(bytesPerSecond)
    }
}

// MARK: - Disk Item View

struct DiskItemView: View {
    let disk: DiskInfo
    let readSpeed: Double
    let writeSpeed: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Disk name and icon
            HStack(spacing: 6) {
                Image(systemName: disk.isRemovable ? "externaldrive.fill" : "internaldrive.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(disk.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }

            // Free space / Total space
            Text("\(formatBytes(disk.freeSpace)) free of \(formatBytes(disk.totalSpace))")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Usage bar with R/W indicators
            HStack(spacing: 8) {
                // Usage bar
                DiskUsageBar(usage: disk.usagePercentage)

                // R/W activity indicators
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Text("R")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        Circle()
                            .fill(readSpeed > 0 ? Color.cyan : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }

                    HStack(spacing: 3) {
                        Text("W")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        Circle()
                            .fill(writeSpeed > 0 ? Color.orange : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1000 && unitIndex < units.count - 1 {
            value /= 1000
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else {
            return String(format: "%.1f %@", value, units[unitIndex])
        }
    }
}

// MARK: - Network Disk Item View

struct NetworkDiskItemView: View {
    let disk: DiskInfo

    var body: some View {
        HStack(spacing: 8) {
            // Network disk icon
            Image(systemName: "server.rack")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(disk.name)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Small usage bar
            DiskUsageBar(usage: disk.usagePercentage)
                .frame(width: 80)
        }
    }
}

// MARK: - Disk Usage Bar

struct DiskUsageBar: View {
    let usage: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.1))

                // Used space fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(usageColor)
                    .frame(width: max(0, geometry.size.width * min(1, usage)))
            }
        }
        .frame(height: 8)
    }

    private var usageColor: Color {
        if usage > 0.9 {
            return .red
        } else if usage > 0.75 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Menu Bar Disk View

struct DiskMenuBarView: View {
    let diskUsage: Double  // 0.0 to 1.0

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 11))
            Text(String(format: "%.0f%%", diskUsage * 100))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundColor(.primary)  // Adapts to light/dark menu bar
    }
}

// MARK: - Disk Usage Icon (for dropdown content)

struct DiskUsageIcon: View {
    let usage: Double  // 0.0 to 1.0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let cornerRadius: CGFloat = 2
            let borderWidth: CGFloat = 1.5
            let fillPadding: CGFloat = 2

            ZStack(alignment: .leading) {
                // Outer border (disk shape)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary, lineWidth: borderWidth)

                // Fill level
                RoundedRectangle(cornerRadius: cornerRadius - 1)
                    .fill(fillColor)
                    .frame(width: max(0, (width - fillPadding * 2) * min(1, usage)))
                    .padding(fillPadding)
            }
        }
    }

    private var fillColor: Color {
        if usage > 0.9 {
            return .red
        } else if usage > 0.75 {
            return .orange
        } else {
            return .blue
        }
    }
}

// Keep the old signature for compatibility but unused
struct DiskMenuBarViewLegacy: View {
    let readSpeed: Double
    let writeSpeed: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 11))

            if readSpeed > 0 || writeSpeed > 0 {
                Text(formatSpeed(max(readSpeed, writeSpeed)))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
        }
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond <= 0 {
            return "—"
        }

        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var unitIndex = 0

        while value >= 1000 && unitIndex < units.count - 1 {
            value /= 1000
            unitIndex += 1
        }

        if value >= 100 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else if value >= 10 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else {
            return String(format: "%.1f %@", value, units[unitIndex])
        }
    }
}
