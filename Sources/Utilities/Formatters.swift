import Foundation

// MARK: - Byte Formatter (Network Stats)

struct ByteFormatter {
    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 0 {
            return "—"
        }

        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
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

    static func formatBytes(_ bytes: UInt64) -> String {
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

    /// Compact speed format, returns "—" for zero or negative values
    static func compactSpeedOrDash(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond <= 0 {
            return "—"
        }
        return compactSpeed(bytesPerSecond)
    }

    static func compactSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 0 {
            return "—"
        }

        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var unitIndex = 0

        while value >= 1000 && unitIndex < units.count - 1 {
            value /= 1000
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else if value >= 100 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else if value >= 10 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else {
            return String(format: "%.1f %@", value, units[unitIndex])
        }
    }

    /// Ultra-compact speed format for menu bar (e.g., "13 KB/s" or "0 KB/s")
    static func menuBarSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 0 {
            return "  0 KB/s"
        }

        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var unitIndex = 0

        while value >= 1000 && unitIndex < units.count - 1 {
            value /= 1000
            unitIndex += 1
        }

        // Fixed width: 3 chars for number + space + 4 chars for unit = consistent width
        // Pad number to 3 characters for consistent menu bar width
        return String(format: "%3.0f %@", value, units[unitIndex])
    }
}

// MARK: - CPU/System Formatter

struct SystemFormatter {
    /// Format percentage value (0-100)
    static func formatPercentage(_ value: Double, decimals: Int = 0) -> String {
        if value < 0 {
            return "—"
        }
        return String(format: "%.\(decimals)f%%", value)
    }

    /// Format temperature in Celsius
    static func formatTemperature(_ celsius: Double) -> String {
        if celsius <= 0 {
            return "—"
        }
        return String(format: "%.0f°", celsius)
    }

    /// Format uptime duration
    static func formatUptime(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "—" }

        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if days > 0 {
            return "\(days) days, \(hours) hours, \(minutes) minutes"
        } else if hours > 0 {
            return "\(hours) hours, \(minutes) minutes"
        } else {
            return "\(minutes) minutes"
        }
    }

    /// Format load average (typically 0-10+ range)
    static func formatLoadAverage(_ value: Double) -> String {
        return String(format: "%.2f", value)
    }

    /// Format memory size in bytes to human readable (e.g., "28.9 GB")
    static func formatMemory(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else if value >= 10 {
            return String(format: "%.1f %@", value, units[unitIndex])
        } else {
            return String(format: "%.2f %@", value, units[unitIndex])
        }
    }

    /// Format memory as "used/total" (e.g., "28.9/32 GB")
    static func formatMemoryUsage(used: UInt64, total: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]

        // Use total to determine the unit
        var totalValue = Double(total)
        var unitIndex = 0

        while totalValue >= 1024 && unitIndex < units.count - 1 {
            totalValue /= 1024
            unitIndex += 1
        }

        // Convert used to the same unit
        var usedValue = Double(used)
        for _ in 0..<unitIndex {
            usedValue /= 1024
        }

        let usedStr: String
        let totalStr: String

        if unitIndex == 0 {
            usedStr = String(format: "%.0f", usedValue)
            totalStr = String(format: "%.0f", totalValue)
        } else if totalValue >= 10 {
            usedStr = String(format: "%.1f", usedValue)
            totalStr = String(format: "%.1f", totalValue)
        } else {
            usedStr = String(format: "%.2f", usedValue)
            totalStr = String(format: "%.2f", totalValue)
        }

        return "\(usedStr)/\(totalStr) \(units[unitIndex])"
    }

    /// Format disk space (uses 1000 divisor per macOS convention)
    static func formatDiskSpace(_ bytes: UInt64) -> String {
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

    /// Format disk space as "free of total" (e.g., "209.3 GB free of 500 GB")
    static func formatDiskUsage(free: UInt64, total: UInt64) -> String {
        return "\(formatDiskSpace(free)) free of \(formatDiskSpace(total))"
    }
}
