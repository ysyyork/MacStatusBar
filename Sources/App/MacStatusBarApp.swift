import SwiftUI
import AppKit
import CoreText

// MARK: - Menu Bar Coordinator

/// Coordinates multiple MenuBarExtra windows to ensure only one is open at a time
final class MenuBarCoordinator: ObservableObject {
    static let shared = MenuBarCoordinator()

    private var observation: NSObjectProtocol?
    private var lastActiveWindow: NSWindow?

    private init() {
        setupWindowObserver()
    }

    private func setupWindowObserver() {
        // Monitor when any window becomes visible/key
        observation = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self?.handleWindowBecameKey(window)
        }
    }

    private func handleWindowBecameKey(_ window: NSWindow) {
        // Check if this is a MenuBarExtra window (they are NSPanel with specific characteristics)
        guard window is NSPanel,
              window.styleMask.contains(.nonactivatingPanel),
              window.level == .popUpMenu || window.level == .floating else {
            return
        }

        // Close other MenuBarExtra windows
        for otherWindow in NSApp.windows {
            guard otherWindow !== window,
                  otherWindow is NSPanel,
                  otherWindow.styleMask.contains(.nonactivatingPanel),
                  otherWindow.level == .popUpMenu || otherWindow.level == .floating,
                  otherWindow.isVisible else {
                continue
            }
            otherWindow.close()
        }

        lastActiveWindow = window
    }

    deinit {
        if let observation = observation {
            NotificationCenter.default.removeObserver(observation)
        }
    }
}

// MARK: - App Entry Point

@main
struct MacStatusBarApp: App {
    // MARK: - ViewModels (MVVM Pattern)
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var cpuMonitor = CPUMonitor()
    @StateObject private var diskMonitor = DiskMonitor()

    // Use ObservedObject for the shared singleton to avoid state conflicts
    @ObservedObject private var settings = AppSettings.shared

    // Initialize the coordinator to start monitoring
    private let coordinator = MenuBarCoordinator.shared

    var body: some Scene {
        // Settings Window
        Settings {
            SettingsView()
        }

        // Network Monitor Menu Bar Extra
        MenuBarExtra {
            NetworkMenuContentView(monitor: networkMonitor, settings: settings)
        } label: {
            NetworkMenuBarView(
                uploadSpeed: networkMonitor.uploadSpeed,
                downloadSpeed: networkMonitor.downloadSpeed,
                settings: settings
            )
        }
        .menuBarExtraStyle(.window)

        // CPU/GPU Monitor Menu Bar Extra
        MenuBarExtra {
            CPUMenuContentView(monitor: cpuMonitor, settings: settings)
        } label: {
            CPUMenuBarView(
                cpuUsage: cpuMonitor.userCPU + cpuMonitor.systemCPU
            )
        }
        .menuBarExtraStyle(.window)

        // Disk Monitor Menu Bar Extra
        MenuBarExtra {
            DiskMenuContentView(monitor: diskMonitor, settings: settings)
        } label: {
            DiskMenuBarView(diskUsage: diskMonitor.mainDiskUsage)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Network Menu Bar View

struct NetworkMenuBarView: View {
    let uploadSpeed: Double
    let downloadSpeed: Double
    @ObservedObject var settings: AppSettings

    var body: some View {
        Image(nsImage: createSpeedImage())
    }

    private func createSpeedImage() -> NSImage {
        let showUpload = settings.networkShowUpload
        let showDownload = settings.networkShowDownload

        // Determine layout based on what's shown
        let bothShown = showUpload && showDownload
        let width: CGFloat = 70
        let height: CGFloat = bothShown ? 22 : 16

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        let textColor = NSColor.black

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        if bothShown {
            // Two lines: upload on top, download below
            let upText = "▲ \(ByteFormatter.menuBarSpeed(uploadSpeed))"
            let downText = "▼ \(ByteFormatter.menuBarSpeed(downloadSpeed))"

            let upString = NSAttributedString(string: upText, attributes: attrs)
            upString.draw(at: NSPoint(x: 0, y: height - 11))

            let downString = NSAttributedString(string: downText, attributes: attrs)
            downString.draw(at: NSPoint(x: 0, y: 0))
        } else if showUpload {
            let upText = "▲ \(ByteFormatter.menuBarSpeed(uploadSpeed))"
            let upString = NSAttributedString(string: upText, attributes: attrs)
            upString.draw(at: NSPoint(x: 0, y: 3))
        } else if showDownload {
            let downText = "▼ \(ByteFormatter.menuBarSpeed(downloadSpeed))"
            let downString = NSAttributedString(string: downText, attributes: attrs)
            downString.draw(at: NSPoint(x: 0, y: 3))
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
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
        .foregroundColor(.primary)  // Adapts to light/dark menu bar
    }
}
