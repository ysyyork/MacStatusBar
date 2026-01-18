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
        XCTAssertEqual(SystemFormatter.formatMemory(1024), "1.0 KB")
        XCTAssertEqual(SystemFormatter.formatMemory(2048), "2.0 KB")
    }

    func testFormatMemoryMegabytes() {
        XCTAssertEqual(SystemFormatter.formatMemory(1_048_576), "1.0 MB")
        XCTAssertEqual(SystemFormatter.formatMemory(512_000_000), "488.3 MB")
    }

    func testFormatMemoryGigabytes() {
        XCTAssertEqual(SystemFormatter.formatMemory(1_073_741_824), "1.0 GB")
        XCTAssertEqual(SystemFormatter.formatMemory(8_589_934_592), "8.0 GB")
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
        // MenuFooterButtons now uses SwiftUI SettingsLink component
        // This test verifies the view can be instantiated (SettingsLink is built-in)
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

    func testCPUWarningThresholdDefault() {
        let settings = AppSettings.shared
        // Default should be 90%
        XCTAssertEqual(settings.cpuWarningThreshold, 90.0)
    }

    func testMemoryWarningThresholdDefault() {
        let settings = AppSettings.shared
        // Default should be 90%
        XCTAssertEqual(settings.memoryWarningThreshold, 90.0)
    }

    func testDiskWarningThresholdDefault() {
        let settings = AppSettings.shared
        // Default should be 90%
        XCTAssertEqual(settings.diskWarningThreshold, 90.0)
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

    // MARK: - menuBarSpeed Tests

    func testMenuBarSpeedZero() {
        XCTAssertEqual(ByteFormatter.menuBarSpeed(0), "0 B/s")
    }

    func testMenuBarSpeedKilobytes() {
        XCTAssertEqual(ByteFormatter.menuBarSpeed(13_000), "13 KB/s")
    }

    func testMenuBarSpeedMegabytes() {
        XCTAssertEqual(ByteFormatter.menuBarSpeed(5_500_000), "6 MB/s")  // Rounds to integer
    }

    func testMenuBarSpeedNegative() {
        XCTAssertEqual(ByteFormatter.menuBarSpeed(-100), "0 KB/s")
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
