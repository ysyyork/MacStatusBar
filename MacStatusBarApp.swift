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

    // Initialize the coordinator to start monitoring
    private let coordinator = MenuBarCoordinator.shared

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
            DiskMenuBarView(diskUsage: diskMonitor.mainDiskUsage)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Network Menu Bar View

struct NetworkMenuBarView: View {
    let uploadSpeed: Double
    let downloadSpeed: Double

    var body: some View {
        Image(nsImage: createSpeedImage())
    }

    private func createSpeedImage() -> NSImage {
        let width: CGFloat = 70
        let height: CGFloat = 22

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        let upText = "▲ \(ByteFormatter.menuBarSpeed(uploadSpeed))"
        let downText = "▼ \(ByteFormatter.menuBarSpeed(downloadSpeed))"

        // Use black for template image - macOS will invert automatically
        let textColor = NSColor.black

        let upAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let downAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        // Draw upload (top line)
        let upString = NSAttributedString(string: upText, attributes: upAttrs)
        upString.draw(at: NSPoint(x: 0, y: height - 11))

        // Draw download (bottom line)
        let downString = NSAttributedString(string: downText, attributes: downAttrs)
        downString.draw(at: NSPoint(x: 0, y: 0))

        image.unlockFocus()
        image.isTemplate = true  // Enables automatic color adaptation
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
