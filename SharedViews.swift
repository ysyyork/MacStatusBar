import SwiftUI
import AppKit

// MARK: - Shared UI Components
// These components are reusable across multiple views in the app

// MARK: - Process Icon View

struct ProcessIconView: View {
    let pid: Int32
    let processName: String
    let size: CGFloat

    var body: some View {
        if let icon = getAppIcon() {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: size * 0.8))
                .foregroundColor(.secondary)
                .frame(width: size, height: size)
        }
    }

    private func getAppIcon() -> NSImage? {
        // Try to get icon from running application by PID
        if let app = NSRunningApplication(processIdentifier: pid) {
            if let icon = app.icon {
                return icon
            }
        }

        // Try to find app by name in /Applications
        let appPaths = [
            "/Applications/\(processName).app",
            "/Applications/\(processName.capitalized).app",
            "/System/Applications/\(processName).app",
            "/System/Applications/Utilities/\(processName).app"
        ]

        for path in appPaths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }

        // Try to find via bundle identifier patterns
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        // Match by localized name or bundle name
        for app in runningApps {
            if let localizedName = app.localizedName,
               localizedName.lowercased().contains(processName.lowercased()) {
                return app.icon
            }
            if let bundleName = app.bundleIdentifier?.components(separatedBy: ".").last,
               bundleName.lowercased().contains(processName.lowercased()) {
                return app.icon
            }
        }

        return nil
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.accentColor)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }
}

// MARK: - Quit Button

struct QuitButton: View {
    var body: some View {
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
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = .secondary

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(iconColor)
            }
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
        .font(.system(size: 12))
    }
}

// MARK: - Process List Header

struct ProcessListHeader: View {
    let columns: [(title: String, width: CGFloat?, color: Color?)]

    var body: some View {
        HStack {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                if let width = column.width {
                    Text(column.title)
                        .foregroundColor(column.color ?? .secondary)
                        .frame(width: width, alignment: .trailing)
                } else {
                    Text(column.title)
                        .foregroundColor(column.color ?? .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.secondary)
    }
}

// MARK: - Color Legend Item

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Menu Footer Buttons (Settings + Quit)

struct MenuFooterButtons: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            // Settings Button
            Button(action: {
                openSettingsWindow()
            }) {
                HStack {
                    Text("Settings...")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘,")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

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
                    Text("⌘Q")
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
    }

    private func openSettingsWindow() {
        // Close the menu panel first
        if let panel = NSApp.keyWindow as? NSPanel {
            panel.close()
        }

        // Use the SwiftUI openSettings environment action
        openSettings()

        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
    }
}
