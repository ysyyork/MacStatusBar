import SwiftUI
import ServiceManagement

// MARK: - App Settings (Using @Published with manual UserDefaults)

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

    @Published var updateInterval: Double {
        didSet { defaults.set(updateInterval, forKey: "updateInterval") }
    }

    // MARK: - Visibility Settings

    @Published var showNetworkMonitor: Bool {
        didSet { defaults.set(showNetworkMonitor, forKey: "showNetworkMonitor") }
    }

    @Published var showCPUMonitor: Bool {
        didSet { defaults.set(showCPUMonitor, forKey: "showCPUMonitor") }
    }

    @Published var showDiskMonitor: Bool {
        didSet { defaults.set(showDiskMonitor, forKey: "showDiskMonitor") }
    }

    // MARK: - Network Settings

    @Published var networkShowUpload: Bool {
        didSet { defaults.set(networkShowUpload, forKey: "networkShowUpload") }
    }

    @Published var networkShowDownload: Bool {
        didSet { defaults.set(networkShowDownload, forKey: "networkShowDownload") }
    }

    @Published var networkSpeedUnit: SpeedUnit {
        didSet { defaults.set(networkSpeedUnit.rawValue, forKey: "networkSpeedUnit") }
    }

    @Published var networkProcessCount: Int {
        didSet { defaults.set(networkProcessCount, forKey: "networkProcessCount") }
    }

    // MARK: - CPU Settings

    @Published var cpuShowTemperature: Bool {
        didSet { defaults.set(cpuShowTemperature, forKey: "cpuShowTemperature") }
    }

    @Published var cpuShowGPU: Bool {
        didSet { defaults.set(cpuShowGPU, forKey: "cpuShowGPU") }
    }

    @Published var cpuShowMemory: Bool {
        didSet { defaults.set(cpuShowMemory, forKey: "cpuShowMemory") }
    }

    @Published var cpuShowLoadAverage: Bool {
        didSet { defaults.set(cpuShowLoadAverage, forKey: "cpuShowLoadAverage") }
    }

    @Published var cpuShowUptime: Bool {
        didSet { defaults.set(cpuShowUptime, forKey: "cpuShowUptime") }
    }

    @Published var cpuProcessCount: Int {
        didSet { defaults.set(cpuProcessCount, forKey: "cpuProcessCount") }
    }

    // MARK: - Warning Thresholds

    @Published var cpuWarningThreshold: Double {
        didSet { defaults.set(cpuWarningThreshold, forKey: "cpuWarningThreshold") }
    }

    @Published var memoryWarningThreshold: Double {
        didSet { defaults.set(memoryWarningThreshold, forKey: "memoryWarningThreshold") }
    }

    @Published var diskWarningThreshold: Double {
        didSet { defaults.set(diskWarningThreshold, forKey: "diskWarningThreshold") }
    }

    // MARK: - Disk Settings

    @Published var diskShowNetworkDisks: Bool {
        didSet { defaults.set(diskShowNetworkDisks, forKey: "diskShowNetworkDisks") }
    }

    @Published var diskShowProcesses: Bool {
        didSet { defaults.set(diskShowProcesses, forKey: "diskShowProcesses") }
    }

    @Published var diskProcessCount: Int {
        didSet { defaults.set(diskProcessCount, forKey: "diskProcessCount") }
    }

    // MARK: - Initialization

    private init() {
        // Load all values from UserDefaults with defaults
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.updateInterval = defaults.object(forKey: "updateInterval") as? Double ?? 1.0

        self.showNetworkMonitor = defaults.object(forKey: "showNetworkMonitor") as? Bool ?? true
        self.showCPUMonitor = defaults.object(forKey: "showCPUMonitor") as? Bool ?? true
        self.showDiskMonitor = defaults.object(forKey: "showDiskMonitor") as? Bool ?? true

        self.networkShowUpload = defaults.object(forKey: "networkShowUpload") as? Bool ?? true
        self.networkShowDownload = defaults.object(forKey: "networkShowDownload") as? Bool ?? true
        self.networkSpeedUnit = SpeedUnit(rawValue: defaults.string(forKey: "networkSpeedUnit") ?? "Auto") ?? .auto
        self.networkProcessCount = defaults.object(forKey: "networkProcessCount") as? Int ?? 5

        self.cpuShowTemperature = defaults.object(forKey: "cpuShowTemperature") as? Bool ?? true
        self.cpuShowGPU = defaults.object(forKey: "cpuShowGPU") as? Bool ?? true
        self.cpuShowMemory = defaults.object(forKey: "cpuShowMemory") as? Bool ?? true
        self.cpuShowLoadAverage = defaults.object(forKey: "cpuShowLoadAverage") as? Bool ?? true
        self.cpuShowUptime = defaults.object(forKey: "cpuShowUptime") as? Bool ?? true
        self.cpuProcessCount = defaults.object(forKey: "cpuProcessCount") as? Int ?? 5

        self.cpuWarningThreshold = defaults.object(forKey: "cpuWarningThreshold") as? Double ?? 90.0
        self.memoryWarningThreshold = defaults.object(forKey: "memoryWarningThreshold") as? Double ?? 90.0
        self.diskWarningThreshold = defaults.object(forKey: "diskWarningThreshold") as? Double ?? 90.0

        self.diskShowNetworkDisks = defaults.object(forKey: "diskShowNetworkDisks") as? Bool ?? true
        self.diskShowProcesses = defaults.object(forKey: "diskShowProcesses") as? Bool ?? true
        self.diskProcessCount = defaults.object(forKey: "diskProcessCount") as? Int ?? 5

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

// Custom RawRepresentable to default invalid values to .auto
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
