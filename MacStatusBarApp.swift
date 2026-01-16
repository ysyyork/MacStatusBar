import SwiftUI
import AppKit

// MARK: - App Entry Point

@main
struct MacStatusBarApp: App {
    // MARK: - ViewModels (MVVM Pattern)
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var cpuMonitor = CPUMonitor()
    @StateObject private var diskMonitor = DiskMonitor()

    var body: some Scene {
        // Network Monitor Menu Bar Extra
        MenuBarExtra {
            NetworkMenuContentView(monitor: networkMonitor)
        } label: {
            NetworkMenuBarView(
                uploadSpeed: networkMonitor.uploadSpeed,
                downloadSpeed: networkMonitor.downloadSpeed
            )
        }
        .menuBarExtraStyle(.window)

        // CPU/GPU Monitor Menu Bar Extra
        MenuBarExtra {
            CPUMenuContentView(monitor: cpuMonitor)
        } label: {
            CPUMenuBarView(
                cpuUsage: cpuMonitor.userCPU + cpuMonitor.systemCPU
            )
        }
        .menuBarExtraStyle(.window)

        // Disk Monitor Menu Bar Extra
        MenuBarExtra {
            DiskMenuContentView(monitor: diskMonitor)
        } label: {
            DiskMenuBarView(
                readSpeed: diskMonitor.totalReadSpeed,
                writeSpeed: diskMonitor.totalWriteSpeed
            )
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Network Menu Bar View

struct NetworkMenuBarView: View {
    let uploadSpeed: Double
    let downloadSpeed: Double

    var body: some View {
        Text("↑ \(ByteFormatter.compactSpeed(uploadSpeed))  ↓ \(ByteFormatter.compactSpeed(downloadSpeed))")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
    }
}

// Keep old name as alias for backward compatibility
typealias MenuBarView = NetworkMenuBarView

// MARK: - CPU Menu Bar View

struct CPUMenuBarView: View {
    let cpuUsage: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(.system(size: 11))
            Text(String(format: "%.0f%%", cpuUsage))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }
}
