import SwiftUI
import ServiceManagement

// MARK: - App Settings (Persisted with @AppStorage)

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - General Settings

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { updateLaunchAtLogin() }
    }

    @AppStorage("updateInterval") var updateInterval: Double = 1.0  // seconds

    // MARK: - Visibility Settings

    @AppStorage("showNetworkMonitor") var showNetworkMonitor: Bool = true
    @AppStorage("showCPUMonitor") var showCPUMonitor: Bool = true
    @AppStorage("showDiskMonitor") var showDiskMonitor: Bool = true

    // MARK: - Network Settings

    @AppStorage("networkShowUpload") var networkShowUpload: Bool = true
    @AppStorage("networkShowDownload") var networkShowDownload: Bool = true
    @AppStorage("networkSpeedUnit") var networkSpeedUnit: SpeedUnit = .auto
    @AppStorage("networkProcessCount") var networkProcessCount: Int = 5

    // MARK: - CPU Settings

    @AppStorage("cpuShowTemperature") var cpuShowTemperature: Bool = true
    @AppStorage("cpuShowGPU") var cpuShowGPU: Bool = true
    @AppStorage("cpuShowMemory") var cpuShowMemory: Bool = true
    @AppStorage("cpuShowLoadAverage") var cpuShowLoadAverage: Bool = true
    @AppStorage("cpuShowUptime") var cpuShowUptime: Bool = true
    @AppStorage("cpuProcessCount") var cpuProcessCount: Int = 5

    // MARK: - Disk Settings

    @AppStorage("diskShowNetworkDisks") var diskShowNetworkDisks: Bool = true
    @AppStorage("diskShowProcesses") var diskShowProcesses: Bool = true
    @AppStorage("diskProcessCount") var diskProcessCount: Int = 5

    // MARK: - Launch at Login

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }

    private init() {
        // Sync launch at login state on init
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Speed Unit Enum

enum SpeedUnit: String, CaseIterable {
    case auto = "Auto"
    case bytesPerSec = "B/s"
    case kilobytesPerSec = "KB/s"
    case megabytesPerSec = "MB/s"
}

// Make SpeedUnit compatible with @AppStorage
extension SpeedUnit: RawRepresentable {
    init?(rawValue: String) {
        switch rawValue {
        case "Auto": self = .auto
        case "B/s": self = .bytesPerSec
        case "KB/s": self = .kilobytesPerSec
        case "MB/s": self = .megabytesPerSec
        default: self = .auto
        }
    }
}
