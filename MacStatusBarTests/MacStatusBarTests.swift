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
