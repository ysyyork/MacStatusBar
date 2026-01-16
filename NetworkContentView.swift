import SwiftUI

// MARK: - Network Menu Content View (MVVM - View Layer)

struct NetworkMenuContentView: View {
    @ObservedObject var monitor: NetworkMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // NETWORK Header
            SectionHeader(title: "NETWORK")

            // IP Addresses
            VStack(spacing: 6) {
                HStack {
                    Text("Public IP")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(monitor.wanIP)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }

                HStack {
                    Text("Local IP")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(monitor.lanIP)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Histogram
            SpeedHistogramView(
                uploadHistory: monitor.uploadHistory,
                downloadHistory: monitor.downloadHistory
            )
            .frame(height: 50)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Current Speeds
            HStack(spacing: 0) {
                // Upload
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(ByteFormatter.formatSpeed(monitor.uploadSpeed))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)

                // Download
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.cyan)
                    Text(ByteFormatter.formatSpeed(monitor.downloadSpeed))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // SESSION Header
            SectionHeader(title: "SESSION")

            // Session Totals
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text("Uploaded")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(ByteFormatter.formatBytes(monitor.totalUploaded))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                }

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9))
                            .foregroundColor(.cyan)
                        Text("Downloaded")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(ByteFormatter.formatBytes(monitor.totalDownloaded))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .font(.system(size: 11))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // PROCESSES Header (only show if there are active processes)
            if !monitor.topProcesses.isEmpty {
                Divider()
                    .padding(.horizontal, 12)

                SectionHeader(title: "PROCESSES")

                // Process list
                VStack(spacing: 4) {
                    // Header row
                    HStack {
                        Text("Name")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("↑")
                            .foregroundColor(.orange)
                            .frame(width: 55, alignment: .trailing)
                        Text("↓")
                            .foregroundColor(.cyan)
                            .frame(width: 55, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                    ForEach(monitor.topProcesses) { process in
                        HStack {
                            Text(process.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(ByteFormatter.compactSpeed(process.uploadSpeed))
                                .frame(width: 55, alignment: .trailing)
                            Text(ByteFormatter.compactSpeed(process.downloadSpeed))
                                .frame(width: 55, alignment: .trailing)
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

            // Quit Button
            QuitButton()
        }
        .frame(width: 280)
        .padding(.vertical, 8)
    }
}

// Keep MenuContentView as alias for backward compatibility
typealias MenuContentView = NetworkMenuContentView

// Speed Histogram View - Mirrored (upload down, download up)
struct SpeedHistogramView: View {
    let uploadHistory: [Double]
    let downloadHistory: [Double]

    var body: some View {
        GeometryReader { geometry in
            let maxUpload = uploadHistory.max() ?? 0
            let maxDownload = downloadHistory.max() ?? 0
            let maxValue = max(maxUpload, maxDownload, 1024)
            let halfHeight = (geometry.size.height - 4) / 2
            let barWidth = (geometry.size.width - 8) / CGFloat(downloadHistory.count) - 1

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.05))

                // Center line
                Rectangle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(height: 1)

                // Bars
                HStack(alignment: .center, spacing: 1) {
                    ForEach(0..<downloadHistory.count, id: \.self) { index in
                        let uploadValue = uploadHistory[index]
                        let downloadValue = downloadHistory[index]
                        let uploadHeight = maxValue > 0 ? CGFloat(uploadValue / maxValue) * halfHeight : 0
                        let downloadHeight = maxValue > 0 ? CGFloat(downloadValue / maxValue) * halfHeight : 0

                        VStack(spacing: 0) {
                            // Upload bar (orange) - goes UP
                            VStack {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.orange)
                                    .frame(width: max(1, barWidth), height: max(0, uploadHeight))
                            }
                            .frame(height: halfHeight)

                            // Download bar (cyan) - goes DOWN
                            VStack {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.cyan)
                                    .frame(width: max(1, barWidth), height: max(0, downloadHeight))
                                Spacer(minLength: 0)
                            }
                            .frame(height: halfHeight)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
    }
}
