# MacStatusBar

An open-source system monitoring status bar app for macOS users.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
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

Three separate menu bar icons for Network, CPU, and Disk monitoring:
- **Network**: `↑ 1.2 KB/s  ↓ 3.4 KB/s`
- **CPU**: (cpu icon) `21%`
- **Disk**: (drive icon)

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building)

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
