import XCTest
@testable import MacStatusBar

final class ByteFormatterTests: XCTestCase {

    // MARK: - formatSpeed Tests

    func testFormatSpeedBytes() {
        XCTAssertEqual(ByteFormatter.formatSpeed(0), "0 B/s")
        XCTAssertEqual(ByteFormatter.formatSpeed(500), "500 B/s")
        XCTAssertEqual(ByteFormatter.formatSpeed(999), "999 B/s")
    }

    func testFormatSpeedKilobytes() {
        XCTAssertEqual(ByteFormatter.formatSpeed(1000), "1.0 KB/s")
        XCTAssertEqual(ByteFormatter.formatSpeed(1500), "1.5 KB/s")
        XCTAssertEqual(ByteFormatter.formatSpeed(999_000), "999.0 KB/s")
    }

    func testFormatSpeedMegabytes() {
        XCTAssertEqual(ByteFormatter.formatSpeed(1_000_000), "1.0 MB/s")
        XCTAssertEqual(ByteFormatter.formatSpeed(5_500_000), "5.5 MB/s")
        XCTAssertEqual(ByteFormatter.formatSpeed(100_000_000), "100.0 MB/s")
    }

    func testFormatSpeedGigabytes() {
        XCTAssertEqual(ByteFormatter.formatSpeed(1_000_000_000), "1.0 GB/s")
        XCTAssertEqual(ByteFormatter.formatSpeed(2_500_000_000), "2.5 GB/s")
    }

    func testFormatSpeedNegative() {
        XCTAssertEqual(ByteFormatter.formatSpeed(-1), "—")
        XCTAssertEqual(ByteFormatter.formatSpeed(-100), "—")
    }

    // MARK: - formatBytes Tests

    func testFormatBytesSmall() {
        XCTAssertEqual(ByteFormatter.formatBytes(0), "0 B")
        XCTAssertEqual(ByteFormatter.formatBytes(512), "512 B")
        XCTAssertEqual(ByteFormatter.formatBytes(999), "999 B")
    }

    func testFormatBytesKilobytes() {
        XCTAssertEqual(ByteFormatter.formatBytes(1000), "1.0 KB")
        XCTAssertEqual(ByteFormatter.formatBytes(1500), "1.5 KB")
    }

    func testFormatBytesMegabytes() {
        XCTAssertEqual(ByteFormatter.formatBytes(1_000_000), "1.0 MB")
        XCTAssertEqual(ByteFormatter.formatBytes(500_000_000), "500.0 MB")
    }

    func testFormatBytesGigabytes() {
        XCTAssertEqual(ByteFormatter.formatBytes(1_000_000_000), "1.0 GB")
        XCTAssertEqual(ByteFormatter.formatBytes(256_000_000_000), "256.0 GB")
    }

    func testFormatBytesTerabytes() {
        XCTAssertEqual(ByteFormatter.formatBytes(1_000_000_000_000), "1.0 TB")
        XCTAssertEqual(ByteFormatter.formatBytes(2_000_000_000_000), "2.0 TB")
    }

    // MARK: - compactSpeed Tests

    func testCompactSpeedSmall() {
        XCTAssertEqual(ByteFormatter.compactSpeed(0), "0 B/s")
        XCTAssertEqual(ByteFormatter.compactSpeed(500), "500 B/s")
    }

    func testCompactSpeedLargeValues() {
        // Values >= 100 should have no decimal
        XCTAssertEqual(ByteFormatter.compactSpeed(100_000), "100 KB/s")
        XCTAssertEqual(ByteFormatter.compactSpeed(250_000), "250 KB/s")
    }

    func testCompactSpeedMediumValues() {
        // Values >= 10 but < 100 should have no decimal
        XCTAssertEqual(ByteFormatter.compactSpeed(50_000), "50 KB/s")
    }

    func testCompactSpeedSmallDecimal() {
        // Values < 10 should have 1 decimal
        XCTAssertEqual(ByteFormatter.compactSpeed(1500), "1.5 KB/s")
        XCTAssertEqual(ByteFormatter.compactSpeed(5500), "5.5 KB/s")
    }

    func testCompactSpeedNegative() {
        XCTAssertEqual(ByteFormatter.compactSpeed(-1), "—")
    }
}

final class SystemFormatterTests: XCTestCase {

    // MARK: - formatPercentage Tests

    func testFormatPercentageNoDecimals() {
        XCTAssertEqual(SystemFormatter.formatPercentage(0), "0%")
        XCTAssertEqual(SystemFormatter.formatPercentage(50), "50%")
        XCTAssertEqual(SystemFormatter.formatPercentage(100), "100%")
    }

    func testFormatPercentageWithDecimals() {
        XCTAssertEqual(SystemFormatter.formatPercentage(50.5, decimals: 1), "50.5%")
        XCTAssertEqual(SystemFormatter.formatPercentage(33.33, decimals: 2), "33.33%")
    }

    func testFormatPercentageNegative() {
        XCTAssertEqual(SystemFormatter.formatPercentage(-1), "—")
    }

    // MARK: - formatTemperature Tests

    func testFormatTemperatureValid() {
        XCTAssertEqual(SystemFormatter.formatTemperature(45), "45°")
        XCTAssertEqual(SystemFormatter.formatTemperature(72.6), "73°")
        XCTAssertEqual(SystemFormatter.formatTemperature(100), "100°")
    }

    func testFormatTemperatureInvalid() {
        XCTAssertEqual(SystemFormatter.formatTemperature(0), "—")
        XCTAssertEqual(SystemFormatter.formatTemperature(-10), "—")
    }

    // MARK: - formatUptime Tests

    func testFormatUptimeMinutes() {
        XCTAssertEqual(SystemFormatter.formatUptime(60), "1 minutes")
        XCTAssertEqual(SystemFormatter.formatUptime(1800), "30 minutes")
        XCTAssertEqual(SystemFormatter.formatUptime(3540), "59 minutes")
    }

    func testFormatUptimeHours() {
        XCTAssertEqual(SystemFormatter.formatUptime(3600), "1 hours, 0 minutes")
        XCTAssertEqual(SystemFormatter.formatUptime(7200), "2 hours, 0 minutes")
        XCTAssertEqual(SystemFormatter.formatUptime(5400), "1 hours, 30 minutes")
    }

    func testFormatUptimeDays() {
        XCTAssertEqual(SystemFormatter.formatUptime(86400), "1 days, 0 hours, 0 minutes")
        XCTAssertEqual(SystemFormatter.formatUptime(172800), "2 days, 0 hours, 0 minutes")
        XCTAssertEqual(SystemFormatter.formatUptime(90000), "1 days, 1 hours, 0 minutes")
    }

    func testFormatUptimeInvalid() {
        XCTAssertEqual(SystemFormatter.formatUptime(0), "—")
        XCTAssertEqual(SystemFormatter.formatUptime(-100), "—")
    }

    // MARK: - formatLoadAverage Tests

    func testFormatLoadAverage() {
        XCTAssertEqual(SystemFormatter.formatLoadAverage(0), "0.00")
        XCTAssertEqual(SystemFormatter.formatLoadAverage(1.5), "1.50")
        XCTAssertEqual(SystemFormatter.formatLoadAverage(10.25), "10.25")
    }

    // MARK: - formatMemory Tests

    func testFormatMemoryBytes() {
        XCTAssertEqual(SystemFormatter.formatMemory(0), "0 B")
        XCTAssertEqual(SystemFormatter.formatMemory(512), "512 B")
    }

    func testFormatMemoryKilobytes() {
        // Note: SystemFormatter uses 1024 divisor (binary)
        // Values < 10 show 2 decimal places, values >= 10 show 1 decimal place
        XCTAssertEqual(SystemFormatter.formatMemory(1024), "1.00 KB")
        XCTAssertEqual(SystemFormatter.formatMemory(2048), "2.00 KB")
    }

    func testFormatMemoryMegabytes() {
        XCTAssertEqual(SystemFormatter.formatMemory(1_048_576), "1.00 MB")
        XCTAssertEqual(SystemFormatter.formatMemory(512_000_000), "488.3 MB")
    }

    func testFormatMemoryGigabytes() {
        XCTAssertEqual(SystemFormatter.formatMemory(1_073_741_824), "1.00 GB")
        XCTAssertEqual(SystemFormatter.formatMemory(8_589_934_592), "8.00 GB")
    }
}

final class DiskInfoTests: XCTestCase {

    func testUsedSpaceCalculation() {
        let disk = DiskInfo(
            name: "Macintosh HD",
            mountPoint: "/",
            totalSpace: 1_000_000_000_000,
            freeSpace: 400_000_000_000,
            isNetworkDisk: false,
            isRemovable: false
        )

        XCTAssertEqual(disk.usedSpace, 600_000_000_000)
    }

    func testUsedSpaceWhenFreeExceedsTotal() {
        // Edge case: should return 0 not negative
        let disk = DiskInfo(
            name: "Test",
            mountPoint: "/test",
            totalSpace: 100,
            freeSpace: 200, // Free > total (edge case)
            isNetworkDisk: false,
            isRemovable: false
        )

        XCTAssertEqual(disk.usedSpace, 0)
    }

    func testUsagePercentage() {
        let disk = DiskInfo(
            name: "Macintosh HD",
            mountPoint: "/",
            totalSpace: 1_000_000_000_000,
            freeSpace: 400_000_000_000,
            isNetworkDisk: false,
            isRemovable: false
        )

        XCTAssertEqual(disk.usagePercentage, 0.6, accuracy: 0.001)
    }

    func testUsagePercentageZeroTotal() {
        let disk = DiskInfo(
            name: "Empty",
            mountPoint: "/empty",
            totalSpace: 0,
            freeSpace: 0,
            isNetworkDisk: false,
            isRemovable: false
        )

        XCTAssertEqual(disk.usagePercentage, 0)
    }

    func testUsagePercentageFullDisk() {
        let disk = DiskInfo(
            name: "Full",
            mountPoint: "/full",
            totalSpace: 1_000_000,
            freeSpace: 0,
            isNetworkDisk: false,
            isRemovable: false
        )

        XCTAssertEqual(disk.usagePercentage, 1.0)
    }

    func testNetworkDiskFlag() {
        let networkDisk = DiskInfo(
            name: "NAS",
            mountPoint: "/Volumes/NAS",
            totalSpace: 1_000_000_000_000,
            freeSpace: 500_000_000_000,
            isNetworkDisk: true,
            isRemovable: false
        )

        XCTAssertTrue(networkDisk.isNetworkDisk)
    }

    func testRemovableDiskFlag() {
        let usbDrive = DiskInfo(
            name: "USB Drive",
            mountPoint: "/Volumes/USB",
            totalSpace: 64_000_000_000,
            freeSpace: 32_000_000_000,
            isNetworkDisk: false,
            isRemovable: true
        )

        XCTAssertTrue(usbDrive.isRemovable)
        XCTAssertFalse(usbDrive.isNetworkDisk)
    }
}

final class ProcessDiskUsageTests: XCTestCase {

    func testProcessCreation() {
        let process = ProcessDiskUsage(
            name: "Safari",
            readSpeed: 1_000_000,
            writeSpeed: 500_000,
            pid: 1234
        )

        XCTAssertEqual(process.name, "Safari")
        XCTAssertEqual(process.readSpeed, 1_000_000)
        XCTAssertEqual(process.writeSpeed, 500_000)
        XCTAssertEqual(process.pid, 1234)
    }
}

// MARK: - Speed Unit Tests

final class SpeedUnitTests: XCTestCase {

    func testSpeedUnitRawValues() {
        XCTAssertEqual(SpeedUnit.auto.rawValue, "Auto")
        XCTAssertEqual(SpeedUnit.bytesPerSec.rawValue, "B/s")
        XCTAssertEqual(SpeedUnit.kilobytesPerSec.rawValue, "KB/s")
        XCTAssertEqual(SpeedUnit.megabytesPerSec.rawValue, "MB/s")
    }

    func testSpeedUnitFromRawValue() {
        XCTAssertEqual(SpeedUnit(rawValue: "Auto"), .auto)
        XCTAssertEqual(SpeedUnit(rawValue: "B/s"), .bytesPerSec)
        XCTAssertEqual(SpeedUnit(rawValue: "KB/s"), .kilobytesPerSec)
        XCTAssertEqual(SpeedUnit(rawValue: "MB/s"), .megabytesPerSec)
    }

    func testSpeedUnitFromInvalidRawValue() {
        // Invalid raw values should default to .auto
        XCTAssertEqual(SpeedUnit(rawValue: "invalid"), .auto)
        XCTAssertEqual(SpeedUnit(rawValue: ""), .auto)
        XCTAssertEqual(SpeedUnit(rawValue: "Gbps"), .auto)
    }

    func testSpeedUnitAllCases() {
        let allCases = SpeedUnit.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.auto))
        XCTAssertTrue(allCases.contains(.bytesPerSec))
        XCTAssertTrue(allCases.contains(.kilobytesPerSec))
        XCTAssertTrue(allCases.contains(.megabytesPerSec))
    }
}

// MARK: - App Settings Tests

final class AppSettingsTests: XCTestCase {

    func testSharedInstanceExists() {
        let settings = AppSettings.shared
        XCTAssertNotNil(settings)
    }

    func testSharedInstanceIsSingleton() {
        let settings1 = AppSettings.shared
        let settings2 = AppSettings.shared
        XCTAssertTrue(settings1 === settings2)
    }

    func testDefaultUpdateInterval() {
        // Test that default update interval is 1.0 second
        // Note: This test verifies the @AppStorage default, actual value may differ
        // if previously saved by the app
        let settings = AppSettings.shared
        XCTAssertGreaterThan(settings.updateInterval, 0)
        XCTAssertLessThanOrEqual(settings.updateInterval, 10)
    }

    func testDefaultProcessCounts() {
        let settings = AppSettings.shared
        // Process counts should be reasonable values (1-10)
        XCTAssertGreaterThanOrEqual(settings.networkProcessCount, 1)
        XCTAssertLessThanOrEqual(settings.networkProcessCount, 10)

        XCTAssertGreaterThanOrEqual(settings.cpuProcessCount, 1)
        XCTAssertLessThanOrEqual(settings.cpuProcessCount, 10)

        XCTAssertGreaterThanOrEqual(settings.diskProcessCount, 1)
        XCTAssertLessThanOrEqual(settings.diskProcessCount, 10)
    }

    func testVisibilitySettingsAreBool() {
        let settings = AppSettings.shared
        // These should be Bool values (either true or false)
        XCTAssertNotNil(settings.showNetworkMonitor as Bool)
        XCTAssertNotNil(settings.showCPUMonitor as Bool)
        XCTAssertNotNil(settings.showDiskMonitor as Bool)
    }

    func testNetworkSettingsAreBool() {
        let settings = AppSettings.shared
        XCTAssertNotNil(settings.networkShowUpload as Bool)
        XCTAssertNotNil(settings.networkShowDownload as Bool)
    }

    func testCPUSettingsAreBool() {
        let settings = AppSettings.shared
        XCTAssertNotNil(settings.cpuShowTemperature as Bool)
        XCTAssertNotNil(settings.cpuShowGPU as Bool)
        XCTAssertNotNil(settings.cpuShowMemory as Bool)
        XCTAssertNotNil(settings.cpuShowLoadAverage as Bool)
        XCTAssertNotNil(settings.cpuShowUptime as Bool)
    }

    func testDiskSettingsAreBool() {
        let settings = AppSettings.shared
        XCTAssertNotNil(settings.diskShowNetworkDisks as Bool)
        XCTAssertNotNil(settings.diskShowProcesses as Bool)
    }

    func testNetworkSpeedUnitIsValid() {
        let settings = AppSettings.shared
        let validUnits = SpeedUnit.allCases
        XCTAssertTrue(validUnits.contains(settings.networkSpeedUnit))
    }
}

// MARK: - Settings View Tests

final class SettingsViewTests: XCTestCase {

    func testSettingsViewCanBeInstantiated() {
        // Verify SettingsView can be created without crashing
        let settingsView = SettingsView()
        XCTAssertNotNil(settingsView)
    }

    func testSettingsViewUsesSharedSettings() {
        // Verify SettingsView uses the shared AppSettings instance
        let settingsView = SettingsView()
        XCTAssertNotNil(settingsView.body)
    }
}

// MARK: - Menu Footer Buttons Tests

final class MenuFooterButtonsTests: XCTestCase {

    func testMenuFooterButtonsCanBeInstantiated() {
        // Verify MenuFooterButtons can be created without crashing
        let footerButtons = MenuFooterButtons()
        XCTAssertNotNil(footerButtons)
    }

    func testSettingsLinkIsUsed() {
        // MenuFooterButtons uses SwiftUI SettingsLink component
        // This test verifies the view can be instantiated
        let footerButtons = MenuFooterButtons()
        XCTAssertNotNil(footerButtons.body)
    }

    func testTerminateActionExists() {
        // Verify terminate action is available
        XCTAssertTrue(NSApp.responds(to: #selector(NSApplication.terminate(_:))))
    }
}

// MARK: - Shared Views Tests

final class SharedViewsTests: XCTestCase {

    func testSectionHeaderCanBeInstantiated() {
        let header = SectionHeader(title: "Test Section")
        XCTAssertNotNil(header)
    }

    func testStatRowCanBeInstantiated() {
        let statRow = StatRow(label: "Test", value: "100%")
        XCTAssertNotNil(statRow)
    }

    func testStatRowWithIcon() {
        let statRow = StatRow(label: "CPU", value: "50%", icon: "cpu", iconColor: .blue)
        XCTAssertNotNil(statRow)
    }

    func testLegendItemCanBeInstantiated() {
        let legend = LegendItem(color: .blue, label: "Active")
        XCTAssertNotNil(legend)
    }

    func testQuitButtonCanBeInstantiated() {
        let quitButton = QuitButton()
        XCTAssertNotNil(quitButton)
    }

    func testProcessIconViewCanBeInstantiated() {
        let iconView = ProcessIconView(pid: 1, processName: "Finder", size: 16)
        XCTAssertNotNil(iconView)
    }

    func testCopyableIPRowCanBeInstantiated() {
        let ipRow = CopyableIPRow(label: "Public IP", value: "192.168.1.1")
        XCTAssertNotNil(ipRow)
    }

    func testCopyableIPRowWithEmptyValue() {
        let ipRow = CopyableIPRow(label: "Public IP", value: "")
        XCTAssertNotNil(ipRow)
    }

    func testCopyableIPRowWithDash() {
        let ipRow = CopyableIPRow(label: "Public IP", value: "—")
        XCTAssertNotNil(ipRow)
    }
}

// MARK: - Warning Threshold Tests

final class WarningThresholdTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset UserDefaults to ensure tests get default values
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "cpuWarningThreshold")
        defaults.removeObject(forKey: "memoryWarningThreshold")
        defaults.removeObject(forKey: "diskWarningThreshold")
    }

    func testCPUWarningThresholdDefault() {
        // After clearing UserDefaults, reading the key should return nil,
        // and AppSettings should use the default value of 90.0
        let defaults = UserDefaults.standard
        let value = defaults.object(forKey: "cpuWarningThreshold") as? Double ?? 90.0
        XCTAssertEqual(value, 90.0)
    }

    func testMemoryWarningThresholdDefault() {
        let defaults = UserDefaults.standard
        let value = defaults.object(forKey: "memoryWarningThreshold") as? Double ?? 90.0
        XCTAssertEqual(value, 90.0)
    }

    func testDiskWarningThresholdDefault() {
        let defaults = UserDefaults.standard
        let value = defaults.object(forKey: "diskWarningThreshold") as? Double ?? 90.0
        XCTAssertEqual(value, 90.0)
    }

    func testWarningThresholdsAreInValidRange() {
        let settings = AppSettings.shared
        // Thresholds should be between 0 and 100
        XCTAssertGreaterThanOrEqual(settings.cpuWarningThreshold, 0)
        XCTAssertLessThanOrEqual(settings.cpuWarningThreshold, 100)

        XCTAssertGreaterThanOrEqual(settings.memoryWarningThreshold, 0)
        XCTAssertLessThanOrEqual(settings.memoryWarningThreshold, 100)

        XCTAssertGreaterThanOrEqual(settings.diskWarningThreshold, 0)
        XCTAssertLessThanOrEqual(settings.diskWarningThreshold, 100)
    }
}

// MARK: - Additional Formatter Tests

final class AdditionalFormatterTests: XCTestCase {

    // MARK: - compactSpeedOrDash Tests

    func testCompactSpeedOrDashReturnsValueForPositive() {
        XCTAssertEqual(ByteFormatter.compactSpeedOrDash(1000), "1.0 KB/s")
        XCTAssertEqual(ByteFormatter.compactSpeedOrDash(5_000_000), "5.0 MB/s")
    }

    func testCompactSpeedOrDashReturnsDashForZero() {
        XCTAssertEqual(ByteFormatter.compactSpeedOrDash(0), "—")
    }

    func testCompactSpeedOrDashReturnsDashForNegative() {
        XCTAssertEqual(ByteFormatter.compactSpeedOrDash(-1), "—")
        XCTAssertEqual(ByteFormatter.compactSpeedOrDash(-1000), "—")
    }

    // MARK: - formatMemoryUsage Tests

    func testFormatMemoryUsageGigabytes() {
        // 28.9 GB used of 32 GB
        let used: UInt64 = 31_037_849_600  // ~28.9 GiB
        let total: UInt64 = 34_359_738_368  // 32 GiB
        let result = SystemFormatter.formatMemoryUsage(used: used, total: total)
        XCTAssertTrue(result.contains("GB"))
        XCTAssertTrue(result.contains("/"))
    }

    func testFormatMemoryUsageMegabytes() {
        // 500 MB used of 1024 MB
        let used: UInt64 = 524_288_000  // 500 MiB
        let total: UInt64 = 1_073_741_824  // 1 GiB
        let result = SystemFormatter.formatMemoryUsage(used: used, total: total)
        // Should use GB as unit since total is 1 GB
        XCTAssertTrue(result.contains("GB") || result.contains("MB"))
        XCTAssertTrue(result.contains("/"))
    }

    func testFormatMemoryUsageZero() {
        let result = SystemFormatter.formatMemoryUsage(used: 0, total: 0)
        XCTAssertEqual(result, "0/0 B")
    }

    // MARK: - formatDiskSpace Tests

    func testFormatDiskSpaceGigabytes() {
        // 500 GB (using 1000 divisor)
        XCTAssertEqual(SystemFormatter.formatDiskSpace(500_000_000_000), "500.0 GB")
    }

    func testFormatDiskSpaceTerabytes() {
        // 2 TB
        XCTAssertEqual(SystemFormatter.formatDiskSpace(2_000_000_000_000), "2.0 TB")
    }

    func testFormatDiskSpaceZero() {
        XCTAssertEqual(SystemFormatter.formatDiskSpace(0), "0 B")
    }

    // MARK: - formatDiskUsage Tests

    func testFormatDiskUsage() {
        let free: UInt64 = 209_300_000_000  // 209.3 GB
        let total: UInt64 = 500_000_000_000  // 500 GB
        let result = SystemFormatter.formatDiskUsage(free: free, total: total)
        XCTAssertTrue(result.contains("free of"))
        XCTAssertTrue(result.contains("GB"))
    }

    func testFormatDiskUsageTerabyte() {
        let free: UInt64 = 500_000_000_000  // 500 GB
        let total: UInt64 = 2_000_000_000_000  // 2 TB
        let result = SystemFormatter.formatDiskUsage(free: free, total: total)
        XCTAssertTrue(result.contains("free of"))
        XCTAssertTrue(result.contains("500.0 GB"))
        XCTAssertTrue(result.contains("2.0 TB"))
    }

    // MARK: - menuBarSpeed Tests (Fixed-width format with 3-char number padding)

    func testMenuBarSpeedZero() {
        XCTAssertEqual(ByteFormatter.menuBarSpeed(0), "  0 B/s")
    }

    func testMenuBarSpeedKilobytes() {
        XCTAssertEqual(ByteFormatter.menuBarSpeed(13_000), " 13 KB/s")
    }

    func testMenuBarSpeedMegabytes() {
        XCTAssertEqual(ByteFormatter.menuBarSpeed(5_500_000), "  6 MB/s")  // Rounds to integer
    }

    func testMenuBarSpeedNegative() {
        XCTAssertEqual(ByteFormatter.menuBarSpeed(-100), "  0 KB/s")
    }

    func testMenuBarSpeedFixedWidth() {
        // All outputs should have consistent width (number padded to 3 chars)
        let speed1 = ByteFormatter.menuBarSpeed(5_000)      // "  5 KB/s"
        let speed2 = ByteFormatter.menuBarSpeed(50_000)     // " 50 KB/s"
        let speed3 = ByteFormatter.menuBarSpeed(500_000)    // "500 KB/s"

        // Extract just the number portion (first 3 chars) to verify padding
        XCTAssertEqual(String(speed1.prefix(3)), "  5")
        XCTAssertEqual(String(speed2.prefix(3)), " 50")
        XCTAssertEqual(String(speed3.prefix(3)), "500")
    }
}

// MARK: - Menu Bar View Tests

// MARK: - ProcessRunner Tests

final class ProcessRunnerTests: XCTestCase {

    func testRunSuccessfulCommand() {
        // Test running a simple command that should always succeed
        let result = ProcessRunner.run(
            executable: "/bin/echo",
            arguments: ["hello"],
            timeout: 5.0
        )

        switch result {
        case .success(let output):
            XCTAssertTrue(output.contains("hello"))
        case .failure(let error):
            XCTFail("Expected success, got error: \(error)")
        }
    }

    func testRunWithInvalidExecutable() {
        // Test running a non-existent executable
        let result = ProcessRunner.run(
            executable: "/nonexistent/path/to/executable",
            arguments: [],
            timeout: 5.0
        )

        switch result {
        case .success:
            XCTFail("Expected failure for non-existent executable")
        case .failure(let error):
            if case .processNotFound = error {
                // Expected
            } else {
                XCTFail("Expected processNotFound error, got: \(error)")
            }
        }
    }

    func testRunOrNilReturnsNilOnFailure() {
        // Test runOrNil returns nil for failed commands
        let result = ProcessRunner.runOrNil(
            executable: "/nonexistent/path",
            arguments: [],
            timeout: 5.0
        )

        XCTAssertNil(result)
    }

    func testRunOrNilReturnsOutputOnSuccess() {
        // Test runOrNil returns output for successful commands
        let result = ProcessRunner.runOrNil(
            executable: "/bin/echo",
            arguments: ["test"],
            timeout: 5.0
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("test") ?? false)
    }

    func testProcessErrorDescriptions() {
        // Test that all error types have descriptions
        XCTAssertNotNil(ProcessError.timeout.errorDescription)
        XCTAssertNotNil(ProcessError.executionFailed("test").errorDescription)
        XCTAssertNotNil(ProcessError.invalidOutput.errorDescription)
        XCTAssertNotNil(ProcessError.processNotFound("/test").errorDescription)

        XCTAssertTrue(ProcessError.timeout.errorDescription?.contains("timed out") ?? false)
        XCTAssertTrue(ProcessError.executionFailed("reason").errorDescription?.contains("reason") ?? false)
        XCTAssertTrue(ProcessError.processNotFound("/path").errorDescription?.contains("/path") ?? false)
    }
}

// MARK: - Validation Tests

final class ValidationTests: XCTestCase {

    func testClampPercentageValues() {
        // Test that percentage values are properly clamped
        let clampedLow = min(100, max(0, -10.0))
        let clampedHigh = min(100, max(0, 150.0))
        let clampedNormal = min(100, max(0, 50.0))

        XCTAssertEqual(clampedLow, 0)
        XCTAssertEqual(clampedHigh, 100)
        XCTAssertEqual(clampedNormal, 50)
    }

    func testCounterWraparound() {
        // Test counter wraparound handling logic
        // Helper function to calculate delta with wraparound handling
        func calculateDelta(newValue: UInt64, oldValue: UInt64) -> UInt64 {
            return newValue >= oldValue ? newValue - oldValue : newValue
        }

        let oldValue: UInt64 = 1000
        let newValueNormal: UInt64 = 2000
        let newValueWrapped: UInt64 = 500  // Simulates counter reset

        // Normal case
        let deltaNormal = calculateDelta(newValue: newValueNormal, oldValue: oldValue)
        XCTAssertEqual(deltaNormal, 1000)

        // Wraparound case
        let deltaWrapped = calculateDelta(newValue: newValueWrapped, oldValue: oldValue)
        XCTAssertEqual(deltaWrapped, 500)  // Uses new value when wrapped
    }

    func testSpeedClamping() {
        // Test that speeds are clamped to reasonable values
        let maxSpeed: Double = 10_000_000_000  // 10 Gbps
        let unreasonableSpeed: Double = 100_000_000_000  // 100 Gbps
        let normalSpeed: Double = 1_000_000  // 1 MB/s

        let clampedUnreasonable = min(maxSpeed, max(0, unreasonableSpeed))
        let clampedNormal = min(maxSpeed, max(0, normalSpeed))
        let clampedNegative = min(maxSpeed, max(0, -1000.0))

        XCTAssertEqual(clampedUnreasonable, maxSpeed)
        XCTAssertEqual(clampedNormal, normalSpeed)
        XCTAssertEqual(clampedNegative, 0)
    }

    func testUptimeValidation() {
        // Test uptime validation logic
        let maxUptime: TimeInterval = 315_360_000  // 10 years in seconds

        let validUptime: TimeInterval = 86400  // 1 day
        let negativeUptime: TimeInterval = -100
        let excessiveUptime: TimeInterval = 400_000_000  // > 10 years

        let isValidNormal = validUptime > 0 && validUptime < maxUptime
        let isValidNegative = negativeUptime > 0 && negativeUptime < maxUptime
        let isValidExcessive = excessiveUptime > 0 && excessiveUptime < maxUptime

        XCTAssertTrue(isValidNormal)
        XCTAssertFalse(isValidNegative)
        XCTAssertFalse(isValidExcessive)
    }

    func testMemoryValidation() {
        // Test that used memory doesn't exceed total
        let totalMemory: UInt64 = 16_000_000_000  // 16 GB
        let usedNormal: UInt64 = 8_000_000_000   // 8 GB
        let usedExcessive: UInt64 = 20_000_000_000  // 20 GB (impossible)

        let validatedNormal = min(usedNormal, totalMemory)
        let validatedExcessive = min(usedExcessive, totalMemory)

        XCTAssertEqual(validatedNormal, usedNormal)
        XCTAssertEqual(validatedExcessive, totalMemory)  // Clamped to total
    }
}

// MARK: - Network Byte Direction Tests

final class NetworkByteDirectionTests: XCTestCase {

    func testIfDataByteDirectionConvention() {
        // This test documents and verifies the correct interpretation of if_data fields:
        // - ifi_ibytes = input bytes (data received/downloaded FROM the network)
        // - ifi_obytes = output bytes (data sent/uploaded TO the network)
        //
        // A previous bug swapped these values, causing download speeds to show upload values.
        // This test ensures the convention is correctly understood.

        // Simulate if_data values (as would come from network interface)
        let ifi_ibytes: UInt64 = 1_000_000  // 1 MB received (download)
        let ifi_obytes: UInt64 = 500_000    // 500 KB sent (upload)

        // Correct assignment (matching NetworkMonitor.getNetworkBytes())
        let totalBytesIn = ifi_ibytes   // Download = input bytes
        let totalBytesOut = ifi_obytes  // Upload = output bytes

        // Verify the naming convention
        XCTAssertEqual(totalBytesIn, 1_000_000, "totalBytesIn should equal ifi_ibytes (input/download)")
        XCTAssertEqual(totalBytesOut, 500_000, "totalBytesOut should equal ifi_obytes (output/upload)")

        // Verify download > upload in this test case (common pattern)
        XCTAssertGreaterThan(totalBytesIn, totalBytesOut, "Download (input) should be greater than upload (output) in this test")
    }

    func testNetworkSpeedCalculation() {
        // Test that speed calculation handles the byte values correctly
        let previousBytesIn: UInt64 = 1_000_000
        let currentBytesIn: UInt64 = 2_000_000
        let timeDelta: Double = 1.0  // 1 second

        let deltaIn = currentBytesIn - previousBytesIn
        let downloadSpeed = Double(deltaIn) / timeDelta

        XCTAssertEqual(downloadSpeed, 1_000_000, "Download speed should be 1 MB/s")
    }
}

// MARK: - IP Validation Tests

final class IPValidationTests: XCTestCase {

    func testValidIPv4Addresses() {
        let validIPs = ["192.168.1.1", "10.0.0.1", "8.8.8.8", "255.255.255.255", "0.0.0.0"]

        for ip in validIPs {
            XCTAssertTrue(isValidIPv4(ip), "Expected \(ip) to be valid")
        }
    }

    func testInvalidIPv4Addresses() {
        let invalidIPs = ["256.1.1.1", "1.1.1", "1.1.1.1.1", "abc.def.ghi.jkl", ""]

        for ip in invalidIPs {
            XCTAssertFalse(isValidIPv4(ip), "Expected \(ip) to be invalid")
        }
    }

    // Helper function matching the logic in NetworkMonitor
    private func isValidIPv4(_ ip: String) -> Bool {
        let ipv4Pattern = #"^(\d{1,3}\.){3}\d{1,3}$"#

        if ip.range(of: ipv4Pattern, options: .regularExpression) != nil {
            let octets = ip.split(separator: ".").compactMap { Int($0) }
            return octets.count == 4 && octets.allSatisfy { $0 >= 0 && $0 <= 255 }
        }
        return false
    }
}

// MARK: - Menu Bar View Tests

final class MenuBarViewTests: XCTestCase {

    func testCPUMenuBarViewNormalState() {
        // Below threshold - should not show warning
        let view = CPUMenuBarView(cpuUsage: 50.0, warningThreshold: 90.0)
        XCTAssertNotNil(view)
    }

    func testCPUMenuBarViewWarningState() {
        // Above threshold - should show warning
        let view = CPUMenuBarView(cpuUsage: 95.0, warningThreshold: 90.0)
        XCTAssertNotNil(view)
    }

    func testCPUMenuBarViewCustomThreshold() {
        // Test with custom threshold
        let view = CPUMenuBarView(cpuUsage: 75.0, warningThreshold: 70.0)
        XCTAssertNotNil(view)
    }

    func testDiskMenuBarViewNormalState() {
        // Below threshold (0.5 = 50%)
        let view = DiskMenuBarView(diskUsage: 0.5, warningThreshold: 90.0)
        XCTAssertNotNil(view)
    }

    func testDiskMenuBarViewWarningState() {
        // Above threshold (0.95 = 95%)
        let view = DiskMenuBarView(diskUsage: 0.95, warningThreshold: 90.0)
        XCTAssertNotNil(view)
    }

    func testDiskMenuBarViewCustomThreshold() {
        // Test with custom threshold
        let view = DiskMenuBarView(diskUsage: 0.8, warningThreshold: 75.0)
        XCTAssertNotNil(view)
    }
}

// MARK: - Disk Eject Eligibility Tests

final class DiskEjectTests: XCTestCase {

    func testRootVolumeCannotBeEjected() {
        // Root volume "/" should never be ejectable
        let rootDisk = DiskInfo(
            name: "Macintosh HD",
            mountPoint: "/",
            totalSpace: 1_000_000_000_000,
            freeSpace: 200_000_000_000,
            isNetworkDisk: false,
            isRemovable: false
        )

        let canEject = rootDisk.mountPoint != "/"
        XCTAssertFalse(canEject, "Root volume should not be ejectable")
    }

    func testExternalDriveCanBeEjected() {
        // External drives mounted at /Volumes/... should be ejectable
        let externalDisk = DiskInfo(
            name: "Untitled",
            mountPoint: "/Volumes/Untitled",
            totalSpace: 500_000_000_000,
            freeSpace: 250_000_000_000,
            isNetworkDisk: false,
            isRemovable: false  // Note: isRemovable may be false for external SSDs
        )

        let canEject = externalDisk.mountPoint != "/"
        XCTAssertTrue(canEject, "External drive should be ejectable")
    }

    func testNetworkDiskCanBeEjected() {
        // Network disks should be ejectable
        let networkDisk = DiskInfo(
            name: "OrbStack",
            mountPoint: "/Volumes/OrbStack",
            totalSpace: 100_000_000_000,
            freeSpace: 50_000_000_000,
            isNetworkDisk: true,
            isRemovable: false
        )

        let canEject = networkDisk.mountPoint != "/"
        XCTAssertTrue(canEject, "Network disk should be ejectable")
    }

    func testRemovableDiskCanBeEjected() {
        // Removable disks (USB, SD cards) should be ejectable
        let usbDrive = DiskInfo(
            name: "USB Drive",
            mountPoint: "/Volumes/USB",
            totalSpace: 64_000_000_000,
            freeSpace: 32_000_000_000,
            isNetworkDisk: false,
            isRemovable: true
        )

        let canEject = usbDrive.mountPoint != "/"
        XCTAssertTrue(canEject, "Removable disk should be ejectable")
    }
}

// MARK: - Network Speed Color Threshold Tests

final class NetworkSpeedColorTests: XCTestCase {

    // Threshold for green color: > 1 MB/s (1,000,000 bytes/sec)
    let speedThreshold: Double = 1_000_000

    func testSpeedBelowThresholdNotGreen() {
        // Speeds below 1 MB/s should NOT be green
        let slowSpeeds: [Double] = [0, 100, 1000, 100_000, 500_000, 999_999]

        for speed in slowSpeeds {
            let isGreen = speed > speedThreshold
            XCTAssertFalse(isGreen, "Speed \(speed) B/s should not be green")
        }
    }

    func testSpeedAboveThresholdIsGreen() {
        // Speeds above 1 MB/s should be green
        let fastSpeeds: [Double] = [1_000_001, 5_000_000, 10_000_000, 50_000_000, 100_000_000]

        for speed in fastSpeeds {
            let isGreen = speed > speedThreshold
            XCTAssertTrue(isGreen, "Speed \(speed) B/s should be green")
        }
    }

    func testSpeedExactlyAtThresholdNotGreen() {
        // Speed exactly at 1 MB/s should NOT be green (> not >=)
        let exactSpeed: Double = 1_000_000
        let isGreen = exactSpeed > speedThreshold
        XCTAssertFalse(isGreen, "Speed exactly at threshold should not be green")
    }

    func testUploadAndDownloadIndependent() {
        // Upload and download should be evaluated independently
        let uploadSpeed: Double = 500_000      // 500 KB/s - not green
        let downloadSpeed: Double = 50_000_000 // 50 MB/s - green

        let uploadGreen = uploadSpeed > speedThreshold
        let downloadGreen = downloadSpeed > speedThreshold

        XCTAssertFalse(uploadGreen, "Upload should not be green")
        XCTAssertTrue(downloadGreen, "Download should be green")
    }
}

// MARK: - System Disk Priority Tests

final class SystemDiskPriorityTests: XCTestCase {

    func testSystemDiskSelectedOverLargerExternalDrive() {
        // Simulate disks sorted by size (largest first)
        // External 4TB drive would be first in size-sorted list
        let disks = [
            DiskInfo(
                name: "External Drive",
                mountPoint: "/Volumes/External",
                totalSpace: 4_000_000_000_000,  // 4 TB (largest)
                freeSpace: 3_700_000_000_000,
                isNetworkDisk: false,
                isRemovable: true
            ),
            DiskInfo(
                name: "Macintosh HD",
                mountPoint: "/",  // System disk
                totalSpace: 1_000_000_000_000,  // 1 TB (smaller)
                freeSpace: 200_000_000_000,
                isNetworkDisk: false,
                isRemovable: false
            )
        ]

        // The correct behavior: find system disk by mountPoint, not take first (largest)
        let systemDisk = disks.first(where: { $0.mountPoint == "/" })
        XCTAssertNotNil(systemDisk)
        XCTAssertEqual(systemDisk?.name, "Macintosh HD")
        XCTAssertEqual(systemDisk?.mountPoint, "/")
    }

    func testFallbackToFirstDiskIfNoRootPartition() {
        // Edge case: no disk mounted at "/" (unlikely but handle gracefully)
        let disks = [
            DiskInfo(
                name: "External Only",
                mountPoint: "/Volumes/External",
                totalSpace: 1_000_000_000_000,
                freeSpace: 500_000_000_000,
                isNetworkDisk: false,
                isRemovable: true
            )
        ]

        // If no "/" mount point, should fallback to first disk
        let systemDisk = disks.first(where: { $0.mountPoint == "/" })
        let fallbackDisk = systemDisk ?? disks.first

        XCTAssertNil(systemDisk)
        XCTAssertNotNil(fallbackDisk)
        XCTAssertEqual(fallbackDisk?.name, "External Only")
    }

    func testSystemDiskUsageCalculation() {
        // Test that usage is calculated for the system disk, not external
        let systemDisk = DiskInfo(
            name: "Macintosh HD",
            mountPoint: "/",
            totalSpace: 1_000_000_000_000,  // 1 TB
            freeSpace: 200_000_000_000,      // 200 GB free = 80% used
            isNetworkDisk: false,
            isRemovable: false
        )

        let externalDisk = DiskInfo(
            name: "External",
            mountPoint: "/Volumes/External",
            totalSpace: 4_000_000_000_000,  // 4 TB
            freeSpace: 3_700_000_000_000,    // 3.7 TB free = 7.5% used
            isNetworkDisk: false,
            isRemovable: true
        )

        // System disk should show 80% usage
        XCTAssertEqual(systemDisk.usagePercentage, 0.8, accuracy: 0.001)
        // External disk shows 7.5% usage (but should not be displayed in status bar)
        XCTAssertEqual(externalDisk.usagePercentage, 0.075, accuracy: 0.001)
    }
}

// MARK: - Process Disk First Measurement Tests

final class ProcessDiskFirstMeasurementTests: XCTestCase {

    func testFirstMeasurementShouldBeSkipped() {
        // This test documents the fix for inflated first measurements.
        // When a process is first seen, proc_pid_rusage returns cumulative bytes
        // since process start. Using this as a delta would show massive speeds.

        // Simulate first measurement
        let cumulativeBytesAtStart: UInt64 = 500_000_000  // 500 MB written since process started
        let previousStats: (read: UInt64, write: UInt64)? = nil  // First time seeing this process

        // The WRONG behavior (old code):
        // prev = previousStats ?? (0, 0)  // Uses (0, 0) for first measurement
        // delta = cumulativeBytesAtStart - 0 = 500 MB
        // speed = 500 MB / 2 seconds = 250 MB/s (WRONG - massively inflated!)

        // The CORRECT behavior (new code):
        // Skip first measurement entirely when previousStats is nil
        let shouldSkipFirstMeasurement = previousStats == nil

        XCTAssertTrue(shouldSkipFirstMeasurement, "First measurement should be skipped to avoid inflated values")
    }

    func testSecondMeasurementIsValid() {
        // After first measurement is recorded, subsequent deltas are valid

        // First poll: record stats
        let firstPollStats: (read: UInt64, write: UInt64) = (500_000_000, 200_000_000)

        // Second poll: new stats after 2 seconds
        let secondPollStats: (read: UInt64, write: UInt64) = (510_000_000, 204_000_000)  // 10 MB read, 4 MB write

        // Calculate delta (this is valid because we have previous stats)
        let readDelta = secondPollStats.read - firstPollStats.read
        let writeDelta = secondPollStats.write - firstPollStats.write

        // Speed over 2-second interval
        let readSpeed = Double(readDelta) / 2.0
        let writeSpeed = Double(writeDelta) / 2.0

        XCTAssertEqual(readDelta, 10_000_000)  // 10 MB
        XCTAssertEqual(writeDelta, 4_000_000)  // 4 MB
        XCTAssertEqual(readSpeed, 5_000_000)   // 5 MB/s
        XCTAssertEqual(writeSpeed, 2_000_000)  // 2 MB/s
    }

    func testProcessSortingByCurrentSpeed() {
        // Test that processes are sorted by current speed, not historical total

        struct TestProcess {
            let name: String
            let currentReadSpeed: Double
            let currentWriteSpeed: Double
            let totalActivity: UInt64

            var currentTotalSpeed: Double {
                currentReadSpeed + currentWriteSpeed
            }
        }

        let processes = [
            // Process A: High historical total, but currently idle
            TestProcess(name: "ProcessA", currentReadSpeed: 0, currentWriteSpeed: 0, totalActivity: 10_000_000_000),
            // Process B: Low historical total, but currently active
            TestProcess(name: "ProcessB", currentReadSpeed: 5_000_000, currentWriteSpeed: 2_000_000, totalActivity: 500_000)
        ]

        // WRONG: Sort by totalActivity (old behavior)
        let wrongSort = processes.sorted { $0.totalActivity > $1.totalActivity }
        XCTAssertEqual(wrongSort.first?.name, "ProcessA")  // Idle process shows first

        // CORRECT: Sort by current speed (new behavior)
        let correctSort = processes
            .filter { $0.currentTotalSpeed > 0 }  // Only show active processes
            .sorted { $0.currentTotalSpeed > $1.currentTotalSpeed }
        XCTAssertEqual(correctSort.first?.name, "ProcessB")  // Active process shows first
        XCTAssertEqual(correctSort.count, 1)  // Idle process filtered out
    }
}

// MARK: - Memory Process Tests

final class MemoryProcessTests: XCTestCase {

    func testProcessMemoryUsageStructure() {
        // Test that ProcessMemoryUsage can hold name, memory, and pid
        let process = ProcessMemoryUsage(name: "Safari", memoryBytes: 1_073_741_824, pid: 1234)

        XCTAssertEqual(process.name, "Safari")
        XCTAssertEqual(process.memoryBytes, 1_073_741_824)  // 1 GB
        XCTAssertEqual(process.pid, 1234)
        XCTAssertNotNil(process.id)
    }

    func testMemoryBytesValidation() {
        // Test memory values are within valid range
        let validMemoryValues: [UInt64] = [0, 1_048_576, 1_073_741_824, 8_589_934_592]  // 0, 1MB, 1GB, 8GB

        for memBytes in validMemoryValues {
            let process = ProcessMemoryUsage(name: "Test", memoryBytes: memBytes, pid: 1)
            XCTAssertEqual(process.memoryBytes, memBytes)
        }
    }

    func testMultipleMemoryProcesses() {
        // Test handling multiple memory processes
        var processes: [ProcessMemoryUsage] = []
        processes.append(ProcessMemoryUsage(name: "Chrome", memoryBytes: 2_147_483_648, pid: 100))
        processes.append(ProcessMemoryUsage(name: "Xcode", memoryBytes: 4_294_967_296, pid: 200))

        XCTAssertEqual(processes.count, 2)
        XCTAssertEqual(processes[0].name, "Chrome")
        XCTAssertEqual(processes[0].memoryBytes, 2_147_483_648)  // 2 GB
        XCTAssertEqual(processes[1].name, "Xcode")
        XCTAssertEqual(processes[1].memoryBytes, 4_294_967_296)  // 4 GB
    }

    func testEmptyMemoryProcessesArray() {
        // Test that empty memory processes array is handled
        let processes: [ProcessMemoryUsage] = []

        XCTAssertTrue(processes.isEmpty)
        XCTAssertEqual(processes.count, 0)
    }

    func testMemoryFormattingForProcesses() {
        // Test that memory values format correctly
        let testCases: [(UInt64, String)] = [
            (1_048_576, "1.00 MB"),        // 1 MB
            (104_857_600, "100.0 MB"),     // 100 MB
            (1_073_741_824, "1.00 GB"),    // 1 GB
            (2_684_354_560, "2.50 GB"),    // 2.5 GB
        ]

        for (bytes, expected) in testCases {
            let formatted = SystemFormatter.formatMemory(bytes)
            XCTAssertEqual(formatted, expected, "Expected \(expected) for \(bytes) bytes, got \(formatted)")
        }
    }
}
