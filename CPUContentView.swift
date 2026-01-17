import SwiftUI

struct CPUMenuContentView: View {
    @ObservedObject var monitor: CPUMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // CPU Header
            SectionHeader(title: "CPU")

            // CPU Usage Graph
            CPUHistogramView(history: monitor.cpuHistory)
                .frame(height: 50)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            // CPU Usage breakdown
            VStack(spacing: 4) {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Text("User")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.userCPU))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }

                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("System")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.systemCPU))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }

                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text("Idle")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", monitor.idleCPU))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            // CPU Temperature
            if monitor.cpuTemperature > 0 {
                HStack {
                    Text("CPU Temperature")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f°", monitor.cpuTemperature))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            Divider()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            // PROCESSES Header
            SectionHeader(title: "PROCESSES")

            // Process list
            VStack(spacing: 4) {
                ForEach(monitor.topProcesses) { process in
                    HStack {
                        // Process icon
                        ProcessIconView(pid: process.pid, processName: process.name, size: 14)
                        Text(process.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.1f%%", process.cpuUsage))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                }

                if monitor.topProcesses.isEmpty {
                    Text("No active processes")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            Divider()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            // Processor Name Header
            SectionHeader(title: monitor.processorName.uppercased())

            // GPU/Processor bars
            VStack(spacing: 8) {
                // Memory usage bar
                HStack {
                    Text("Memory")
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    ProgressBarView(value: memoryUsageRatio, color: .blue)
                    Text(formatMemory(monitor.memoryUsed))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 55, alignment: .trailing)
                }

                // Processor usage bar
                HStack {
                    Text("Processor")
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    ProgressBarView(value: (monitor.userCPU + monitor.systemCPU) / 100, color: .blue)
                    Text(String(format: "%.0f%%", monitor.userCPU + monitor.systemCPU))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 55, alignment: .trailing)
                }

                // Swap usage (only show if swap is being used)
                if monitor.swapUsed > 0 || monitor.swapTotal > 0 {
                    HStack {
                        Text("Swap")
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)
                        ProgressBarView(value: swapUsageRatio, color: swapUsageRatio > 0.8 ? .orange : .green)
                        Text(formatMemory(monitor.swapUsed))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 55, alignment: .trailing)
                    }
                }
            }
            .font(.system(size: 11))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            Divider()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            // LOAD AVERAGE Header
            SectionHeader(title: "LOAD AVERAGE")

            // Load graph
            LoadHistogramView(
                history: monitor.loadHistory,
                peakLoad: monitor.peakLoad
            )
            .frame(height: 40)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            // Peak load
            HStack {
                Text("Peak Load:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.0f", monitor.peakLoad))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            // Load averages
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Text(String(format: "%.2f", monitor.loadAverage.0))
                        .font(.system(size: 11, design: .monospaced))
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(String(format: "%.2f", monitor.loadAverage.1))
                        .font(.system(size: 11, design: .monospaced))
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 8, height: 8)
                    Text(String(format: "%.2f", monitor.loadAverage.2))
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // UPTIME Header
            SectionHeader(title: "UPTIME")

            // Uptime value
            Text(formatUptime(monitor.uptime))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            Divider()
                .padding(.horizontal, 12)

            // Quit Button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Text("Quit")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\u{2318}Q")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .frame(width: 280)
        .padding(.vertical, 8)
    }

    private func formatUptime(_ interval: TimeInterval) -> String {
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

    // MARK: - Computed Properties

    private var memoryUsageRatio: Double {
        guard monitor.memoryTotal > 0 else { return 0 }
        return min(1.0, Double(monitor.memoryUsed) / Double(monitor.memoryTotal))
    }

    private var swapUsageRatio: Double {
        guard monitor.swapTotal > 0 else { return 0 }
        return min(1.0, Double(monitor.swapUsed) / Double(monitor.swapTotal))
    }

    // MARK: - Helper Functions

    private func formatMemory(_ bytes: UInt64) -> String {
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
}

// MARK: - CPU Histogram View

struct CPUHistogramView: View {
    let history: [Double]

    var body: some View {
        GeometryReader { geometry in
            let maxValue = max(history.max() ?? 0, 100)
            let barWidth = (geometry.size.width - 8) / CGFloat(history.count) - 1

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.05))

                // Bars
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(0..<history.count, id: \.self) { index in
                        let value = history[index]
                        let height = maxValue > 0 ? CGFloat(value / maxValue) * (geometry.size.height - 4) : 0

                        // Color based on CPU usage level
                        let barColor: Color = {
                            if value > 80 { return .red }
                            else if value > 50 { return .orange }
                            else { return .blue }
                        }()

                        RoundedRectangle(cornerRadius: 1)
                            .fill(barColor)
                            .frame(width: max(1, barWidth), height: max(0, height))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Load Histogram View

struct LoadHistogramView: View {
    let history: [Double]
    let peakLoad: Double

    var body: some View {
        GeometryReader { geometry in
            let maxValue = max(peakLoad, history.max() ?? 1, 1)
            let width = geometry.size.width - 8
            let height = geometry.size.height - 4

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.05))

                // Line graph
                Path { path in
                    guard history.count > 1 else { return }

                    let stepX = width / CGFloat(history.count - 1)

                    for (index, value) in history.enumerated() {
                        let x = 4 + CGFloat(index) * stepX
                        let y = height - (CGFloat(value / maxValue) * height) + 2

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 1.5)

                // Area fill
                Path { path in
                    guard history.count > 1 else { return }

                    let stepX = width / CGFloat(history.count - 1)

                    path.move(to: CGPoint(x: 4, y: height + 2))

                    for (index, value) in history.enumerated() {
                        let x = 4 + CGFloat(index) * stepX
                        let y = height - (CGFloat(value / maxValue) * height) + 2
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    path.addLine(to: CGPoint(x: 4 + width, y: height + 2))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}

// MARK: - Progress Bar View

struct ProgressBarView: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.1))

                // Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(0, geometry.size.width * min(1, value)))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Menu Bar CPU View

struct MenuBarCPUView: View {
    let cpuUsage: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(.system(size: 10))
            Text(String(format: "%.0f%%", cpuUsage))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }
}
