import SwiftUI
import AppKit

// MARK: - Disk Menu Content View (MVVM - View Layer)

struct DiskMenuContentView: View {
    @ObservedObject var monitor: DiskMonitor
    @ObservedObject var settings: AppSettings
    @State private var ejectError: String?
    @State private var showingEjectError = false

    private func ejectDisk(_ disk: DiskInfo) {
        monitor.ejectDisk(mountPoint: disk.mountPoint) { success, error in
            if !success {
                ejectError = error ?? "Failed to eject \(disk.name)"
                showingEjectError = true
            }
        }
    }

    // The internal system disk uses the aggregate internal speed; any other
    // local disk (an attached external drive) gets its own speed looked up
    // by the whole-disk BSD ID it was resolved to. A disk with no resolvable
    // ID (e.g. a mounted disk image) simply shows no activity.
    private func speed(for disk: DiskInfo) -> (read: Double, write: Double) {
        if disk.mountPoint == "/" {
            return (monitor.totalReadSpeed, monitor.totalWriteSpeed)
        }
        if let wholeDiskID = monitor.mountPointToWholeDiskID[disk.mountPoint],
           let speed = monitor.externalDiskSpeeds[wholeDiskID] {
            return speed
        }
        return (0, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // DISKS Header
            SectionHeader(title: "DISKS")

            // Local Disks
            VStack(spacing: 8) {
                ForEach(monitor.disks) { disk in
                    // Show eject button for any disk that's not the root volume
                    let canEject = disk.mountPoint != "/"
                    let diskSpeed = speed(for: disk)
                    DiskItemView(disk: disk, readSpeed: diskSpeed.read, writeSpeed: diskSpeed.write, onEject: canEject ? { ejectDisk(disk) } : nil)
                }

                if monitor.disks.isEmpty {
                    Text("No disks found")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // NETWORK DISKS Header (only show if enabled and there are network disks)
            if settings.diskShowNetworkDisks && !monitor.networkDisks.isEmpty {
                Divider()
                    .padding(.horizontal, 12)

                SectionHeader(title: "NETWORK DISKS")

                VStack(spacing: 8) {
                    ForEach(monitor.networkDisks) { disk in
                        NetworkDiskItemView(disk: disk, onEject: { ejectDisk(disk) })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // PROCESSES Header (only show if enabled and there are active processes)
            if settings.diskShowProcesses && !monitor.topProcesses.isEmpty {
                Divider()
                    .padding(.horizontal, 12)

                SectionHeader(title: "PROCESSES")

                // Process list
                VStack(spacing: 4) {
                    // Header row
                    HStack {
                        Text("Name")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("R")
                            .foregroundColor(.cyan)
                            .frame(width: 65, alignment: .trailing)
                        Text("W")
                            .foregroundColor(.orange)
                            .frame(width: 65, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                    ForEach(Array(monitor.topProcesses.prefix(settings.diskProcessCount))) { process in
                        HStack {
                            // Process icon
                            ProcessIconView(pid: process.pid, processName: process.name, size: 14)
                            Text(process.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(ByteFormatter.compactSpeedOrDash(process.readSpeed))
                                .frame(width: 65, alignment: .trailing)
                            Text(ByteFormatter.compactSpeedOrDash(process.writeSpeed))
                                .frame(width: 65, alignment: .trailing)
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            Divider()
                .padding(.horizontal, 12)

            // Settings and Quit Buttons
            MenuFooterButtons()
        }
        .frame(width: 300)
        .padding(.vertical, 8)
        .alert("Eject Failed", isPresented: $showingEjectError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(ejectError ?? "Unknown error")
        }
    }
}

// MARK: - Disk Item View

struct DiskItemView: View {
    let disk: DiskInfo
    let readSpeed: Double
    let writeSpeed: Double
    var onEject: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Disk name and icon
            HStack(spacing: 6) {
                Image(systemName: disk.isRemovable ? "externaldrive.fill" : "internaldrive.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(disk.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                // Eject button for removable disks
                if let onEject = onEject {
                    Button(action: onEject) {
                        Image(systemName: "eject.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Eject \(disk.name)")
                }
            }

            // Free space / Total space
            Text(SystemFormatter.formatDiskUsage(free: disk.freeSpace, total: disk.totalSpace))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Usage bar (fixed width, independent of speed text)
            DiskUsageBar(usage: disk.usagePercentage)

            // Aggregated R/W speed below the bar, so varying text width
            // (e.g. "5.2 MB/s" vs "328 KB/s") never resizes the bar above.
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Text("R")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(ByteFormatter.compactSpeedOrDash(readSpeed))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                HStack(spacing: 3) {
                    Text("W")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(ByteFormatter.compactSpeedOrDash(writeSpeed))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Network Disk Item View

struct NetworkDiskItemView: View {
    let disk: DiskInfo
    var onEject: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            // Network disk icon
            Image(systemName: "server.rack")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(disk.name)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Small usage bar
            DiskUsageBar(usage: disk.usagePercentage)
                .frame(width: 80)

            // Eject button
            if let onEject = onEject {
                Button(action: onEject) {
                    Image(systemName: "eject.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Eject \(disk.name)")
            }
        }
    }
}

// MARK: - Disk Usage Bar

struct DiskUsageBar: View {
    let usage: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.1))

                // Used space fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(usageColor)
                    .frame(width: max(0, geometry.size.width * min(1, usage)))
            }
        }
        .frame(height: 8)
    }

    private var usageColor: Color {
        if usage > 0.9 {
            return .red
        } else if usage > 0.75 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Menu Bar Disk View

struct DiskMenuBarView: View {
    let diskUsage: Double  // 0.0 to 1.0
    var readSpeed: Double = 0
    var writeSpeed: Double = 0
    var warningThreshold: Double = 90.0

    // A manually-created bitmap context doesn't inherit the menu bar's actual
    // appearance, so NSColor.labelColor resolves to light-mode black even in a
    // dark menu bar. Reading the SwiftUI color scheme (which does track the
    // real context) lets us pick the correct color ourselves.
    @Environment(\.colorScheme) private var colorScheme

    private var isHighUsage: Bool {
        (diskUsage * 100) > warningThreshold
    }

    var body: some View {
        // Always draw as a bitmap: SwiftUI's native layout inside a MenuBarExtra
        // label doesn't reliably render multi-line/multi-color content (a nested
        // VStack here collapsed to a single line in testing), so — like
        // NetworkMenuBarView — this composes the whole label as one NSImage.
        Image(nsImage: createDiskImage())
    }

    // Same "fast" cutoff Network uses to turn its arrows green, so both
    // monitors highlight heavy activity the same way instead of using
    // unrelated fixed colors.
    private static let fastThreshold: Double = 1_000_000

    private func createDiskImage() -> NSImage {
        let percentText = String(format: "%.0f%%", diskUsage * 100)
        let readText = ByteFormatter.microSpeed(readSpeed)
        let writeText = ByteFormatter.microSpeed(writeSpeed)

        let primaryColor: NSColor = isHighUsage ? .systemRed : (colorScheme == .dark ? .white : .black)
        let readColor: NSColor = readSpeed > Self.fastThreshold ? .systemGreen : primaryColor
        let writeColor: NSColor = writeSpeed > Self.fastThreshold ? .systemGreen : primaryColor
        // Labels use the same primary color as everything else — a muted
        // secondary color had too little contrast to read against the
        // menu bar's translucent background.
        let labelColor = primaryColor

        let iconSize: CGFloat = 9
        let percentFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        let letterFont = NSFont.monospacedSystemFont(ofSize: 8, weight: .medium)
        let valueFont = NSFont.monospacedSystemFont(ofSize: 8, weight: .medium)

        let percentAttrs: [NSAttributedString.Key: Any] = [.font: percentFont, .foregroundColor: primaryColor]
        let rLabelAttrs: [NSAttributedString.Key: Any] = [.font: letterFont, .foregroundColor: labelColor]
        let wLabelAttrs: [NSAttributedString.Key: Any] = [.font: letterFont, .foregroundColor: labelColor]
        let readAttrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: readColor]
        let writeAttrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: writeColor]

        // Reserve room for the longest realistic string in each slot (rather
        // than the current one) so the icon's width stays stable and doesn't
        // jitter as digit counts change from tick to tick.
        let percentWidth = NSAttributedString(string: "100%", attributes: percentAttrs).size().width
        let rLabelWidth = NSAttributedString(string: "R", attributes: rLabelAttrs).size().width
        let wLabelWidth = NSAttributedString(string: "W", attributes: wLabelAttrs).size().width
        let valueWidth = NSAttributedString(string: "999K", attributes: readAttrs).size().width

        let row1Width = iconSize + 3 + percentWidth
        let row2Width = rLabelWidth + 2 + valueWidth + 9 + wLabelWidth + 2 + valueWidth
        let width = ceil(max(row1Width, row2Width)) + 2
        let height: CGFloat = 20

        let image = NSImage(size: NSSize(width: width, height: height))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(width * 2),
            pixelsHigh: Int(height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return NSImage() }
        rep.size = NSSize(width: width, height: height)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        // Row 1 (top): icon + storage percentage, centered over the wider row below
        let row1X = max(0, (width - row1Width) / 2)
        if let iconImage = NSImage(systemSymbolName: "internaldrive.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
            if let configuredIcon = iconImage.withSymbolConfiguration(config),
               let tintedIcon = configuredIcon.copy() as? NSImage {
                tintedIcon.lockFocus()
                primaryColor.set()
                NSRect(origin: .zero, size: tintedIcon.size).fill(using: .sourceAtop)
                tintedIcon.unlockFocus()
                tintedIcon.draw(in: NSRect(x: row1X, y: 12, width: iconSize, height: iconSize))
            }
        }
        NSAttributedString(string: percentText, attributes: percentAttrs).draw(at: NSPoint(x: row1X + iconSize + 3, y: 11))

        // Row 2 (bottom): R <value>  W <value>, left-aligned under row 1
        var x: CGFloat = 0
        NSAttributedString(string: "R", attributes: rLabelAttrs).draw(at: NSPoint(x: x, y: 1))
        x += rLabelWidth + 2
        NSAttributedString(string: readText, attributes: readAttrs).draw(at: NSPoint(x: x, y: 1))
        x += valueWidth + 9
        NSAttributedString(string: "W", attributes: wLabelAttrs).draw(at: NSPoint(x: x, y: 1))
        x += wLabelWidth + 2
        NSAttributedString(string: writeText, attributes: writeAttrs).draw(at: NSPoint(x: x, y: 1))

        NSGraphicsContext.restoreGraphicsState()

        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }
}

// MARK: - Disk Usage Icon (for dropdown content)

struct DiskUsageIcon: View {
    let usage: Double  // 0.0 to 1.0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let cornerRadius: CGFloat = 2
            let borderWidth: CGFloat = 1.5
            let fillPadding: CGFloat = 2

            ZStack(alignment: .leading) {
                // Outer border (disk shape)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary, lineWidth: borderWidth)

                // Fill level
                RoundedRectangle(cornerRadius: cornerRadius - 1)
                    .fill(fillColor)
                    .frame(width: max(0, (width - fillPadding * 2) * min(1, usage)))
                    .padding(fillPadding)
            }
        }
    }

    private var fillColor: Color {
        if usage > 0.9 {
            return .red
        } else if usage > 0.75 {
            return .orange
        } else {
            return .blue
        }
    }
}

// Keep the old signature for compatibility but unused
struct DiskMenuBarViewLegacy: View {
    let readSpeed: Double
    let writeSpeed: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 11))

            if readSpeed > 0 || writeSpeed > 0 {
                Text(ByteFormatter.compactSpeedOrDash(max(readSpeed, writeSpeed)))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
        }
    }
}
