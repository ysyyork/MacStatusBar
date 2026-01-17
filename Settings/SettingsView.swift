import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            NetworkSettingsView(settings: settings)
                .tabItem {
                    Label("Network", systemImage: "network")
                }

            CPUSettingsView(settings: settings)
                .tabItem {
                    Label("CPU", systemImage: "cpu")
                }

            DiskSettingsView(settings: settings)
                .tabItem {
                    Label("Disk", systemImage: "internaldrive")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)

                Picker("Update Interval", selection: $settings.updateInterval) {
                    Text("0.5 seconds").tag(0.5)
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                }
            }

            Section("Menu Bar Icons") {
                Toggle("Show Network Monitor", isOn: $settings.showNetworkMonitor)
                Toggle("Show CPU Monitor", isOn: $settings.showCPUMonitor)
                Toggle("Show Disk Monitor", isOn: $settings.showDiskMonitor)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Network Settings

struct NetworkSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Menu Bar Display") {
                Toggle("Show Upload Speed", isOn: $settings.networkShowUpload)
                Toggle("Show Download Speed", isOn: $settings.networkShowDownload)

                Picker("Speed Unit", selection: $settings.networkSpeedUnit) {
                    ForEach(SpeedUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
            }

            Section("Dropdown") {
                Stepper("Show \(settings.networkProcessCount) processes",
                        value: $settings.networkProcessCount, in: 1...10)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - CPU Settings

struct CPUSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Dropdown Sections") {
                Toggle("Show Temperature", isOn: $settings.cpuShowTemperature)
                Toggle("Show GPU Stats", isOn: $settings.cpuShowGPU)
                Toggle("Show Memory Usage", isOn: $settings.cpuShowMemory)
                Toggle("Show Load Average", isOn: $settings.cpuShowLoadAverage)
                Toggle("Show Uptime", isOn: $settings.cpuShowUptime)
            }

            Section("Processes") {
                Stepper("Show \(settings.cpuProcessCount) processes",
                        value: $settings.cpuProcessCount, in: 1...10)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Disk Settings

struct DiskSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Dropdown Sections") {
                Toggle("Show Network Disks", isOn: $settings.diskShowNetworkDisks)
                Toggle("Show Process Activity", isOn: $settings.diskShowProcesses)
            }

            Section("Processes") {
                Stepper("Show \(settings.diskProcessCount) processes",
                        value: $settings.diskProcessCount, in: 1...10)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
