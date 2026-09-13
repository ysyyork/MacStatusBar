import SwiftUI
import ServiceManagement

// MARK: - App Settings
//
// Most settings below are declared with @UserDefault (or @UserDefaultRaw for the one enum
// setting), which reads/writes UserDefaults.standard directly and publishes changes through
// objectWillChange — the same reactivity @Published gives, in one line per setting instead
// of a stored property + didSet + a matching init-time hydration line. See
// Sources/Utilities/UserDefault.swift.
//
// launchAtLogin is the one exception: it stays @Published + didSet because toggling it has
// a side effect (registering/unregistering with SMAppService) beyond just persisting the value.

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - General Settings

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    @UserDefault("updateInterval", default: 1.0) var updateInterval: Double

    // MARK: - Visibility Settings

    @UserDefault("showNetworkMonitor", default: true) var showNetworkMonitor: Bool
    @UserDefault("showCPUMonitor", default: true) var showCPUMonitor: Bool
    @UserDefault("showDiskMonitor", default: true) var showDiskMonitor: Bool

    // MARK: - Network Settings

    @UserDefault("networkShowUpload", default: true) var networkShowUpload: Bool
    @UserDefault("networkShowDownload", default: true) var networkShowDownload: Bool
    @UserDefaultRaw("networkSpeedUnit", default: .auto) var networkSpeedUnit: SpeedUnit
    @UserDefault("networkProcessCount", default: 5) var networkProcessCount: Int

    // MARK: - CPU Settings

    @UserDefault("cpuShowTemperature", default: true) var cpuShowTemperature: Bool
    @UserDefault("cpuShowGPU", default: true) var cpuShowGPU: Bool
    @UserDefault("cpuShowMemory", default: true) var cpuShowMemory: Bool
    @UserDefault("cpuShowLoadAverage", default: true) var cpuShowLoadAverage: Bool
    @UserDefault("cpuShowUptime", default: true) var cpuShowUptime: Bool
    @UserDefault("cpuProcessCount", default: 5) var cpuProcessCount: Int
    @UserDefault("memoryProcessCount", default: 5) var memoryProcessCount: Int

    // MARK: - Warning Thresholds

    @UserDefault("cpuWarningThreshold", default: 90.0) var cpuWarningThreshold: Double
    @UserDefault("memoryWarningThreshold", default: 90.0) var memoryWarningThreshold: Double
    @UserDefault("diskWarningThreshold", default: 90.0) var diskWarningThreshold: Double

    // MARK: - Disk Settings

    @UserDefault("diskShowNetworkDisks", default: true) var diskShowNetworkDisks: Bool
    @UserDefault("diskShowProcesses", default: true) var diskShowProcesses: Bool
    @UserDefault("diskProcessCount", default: 5) var diskProcessCount: Int

    // MARK: - Initialization

    private init() {
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")

        // Sync launch at login state after initialization
        syncLaunchAtLoginState()
    }

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

    private func syncLaunchAtLoginState() {
        let isEnabled = SMAppService.mainApp.status == .enabled
        if launchAtLogin != isEnabled {
            // Update without triggering didSet (set backing storage directly via defaults)
            defaults.set(isEnabled, forKey: "launchAtLogin")
            // Manually update the property without triggering didSet
            DispatchQueue.main.async { [weak self] in
                self?.launchAtLogin = isEnabled
            }
        }
    }
}

// MARK: - Speed Unit Enum

enum SpeedUnit: String, CaseIterable {
    case auto = "Auto"
    case bytesPerSec = "B/s"
    case kilobytesPerSec = "KB/s"
    case megabytesPerSec = "MB/s"
}

// Custom init?(rawValue:) to default invalid stored values to .auto instead of nil
extension SpeedUnit {
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
