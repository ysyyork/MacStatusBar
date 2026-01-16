import SwiftUI

// MARK: - Shared UI Components
// These components are reusable across multiple views in the app

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
