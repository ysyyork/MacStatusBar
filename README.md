# MacStatusBar

An open-source system monitoring status bar app for macOS users.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

### Network Monitor
- Real-time upload/download speeds
- Public and local IP addresses
- Per-process network activity (top 5)
- Speed history graph

### CPU Monitor
- CPU usage breakdown (User/System/Idle)
- CPU temperature indicator
- GPU usage and memory (Apple Silicon & discrete GPUs)
- Memory and swap usage
- Load average with history graph
- Top processes by CPU usage
- System uptime

### Disk Monitor
- Local disk usage with visual bars
- Network disk detection
- Read/Write activity indicators
- Per-process disk I/O activity

## Screenshots

### Status Bar
![Status Bar](docs/status_bar.png)

### Network Monitor
![Network Monitor](docs/network_status.png)

### CPU Monitor
![CPU Monitor](docs/compute_status.png)

### Disk Monitor
![Disk Monitor](docs/disk_status.png)

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (M1/M2/M3) recommended
- Xcode 15.0 or later (for building)

> **Note:** Intel Mac support is not fully verified. If you encounter issues on Intel-based Macs, please [open an issue](https://github.com/ysyyork/MacStatusBar/issues) or submit a pull request.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/ysyyork/MacStatusBar.git
   ```

2. Open `MacStatusBar.xcodeproj` in Xcode

3. Build and run (⌘R)

## Architecture

The app follows the **MVVM (Model-View-ViewModel)** pattern:

```
├── ViewModels (Monitors)
│   ├── NetworkMonitor.swift
│   ├── CPUMonitor.swift
│   └── DiskMonitor.swift
├── Views
│   ├── NetworkContentView.swift
│   ├── CPUContentView.swift
│   └── DiskContentView.swift
├── Shared
│   ├── SharedViews.swift
│   └── Formatters.swift
└── App
    └── MacStatusBarApp.swift
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests.
