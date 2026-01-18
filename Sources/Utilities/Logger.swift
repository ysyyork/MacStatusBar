import Foundation
import os.log

// MARK: - App Logger

/// Centralized logging infrastructure using os_log for debugging and monitoring
struct AppLogger {
    static let network = Logger(subsystem: "com.macstatusbar", category: "network")
    static let cpu = Logger(subsystem: "com.macstatusbar", category: "cpu")
    static let disk = Logger(subsystem: "com.macstatusbar", category: "disk")
    static let general = Logger(subsystem: "com.macstatusbar", category: "general")
    static let process = Logger(subsystem: "com.macstatusbar", category: "process")
}
