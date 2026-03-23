import XCTest
@testable import MacUtilsCore

final class LumensTests: XCTestCase {

    // MARK: - DDC Command Byte Construction

    func testBrightnessCommandBytes() {
        let packet = DDCPacket(command: .brightness, value: 50)
        let bytes = packet.buildCommandBytes()

        // Format: [host, length|0x80, setVCP, VCP_code, high, low, checksum]
        XCTAssertEqual(bytes[0], 0x51)     // Host address
        XCTAssertEqual(bytes[1], 0x84)     // Length byte with DDC flag
        XCTAssertEqual(bytes[2], 0x03)     // Set VCP Feature opcode
        XCTAssertEqual(bytes[3], 0x10)     // Brightness VCP code
        XCTAssertEqual(bytes[4], 0x00)     // High byte
        XCTAssertEqual(bytes[5], 50)       // Low byte (value)
        XCTAssertEqual(bytes.count, 7)     // 6 data bytes + checksum
    }

    func testVolumeCommandBytes() {
        let packet = DDCPacket(command: .volume, value: 75)
        let bytes = packet.buildCommandBytes()

        XCTAssertEqual(bytes[3], 0x62)     // Volume VCP code
        XCTAssertEqual(bytes[5], 75)       // Volume value
    }

    func testReadCommandBytes() {
        let packet = DDCPacket(command: .brightness, value: 0)
        let bytes = packet.buildReadCommandBytes()

        XCTAssertEqual(bytes[0], 0x51)     // Host address
        XCTAssertEqual(bytes[1], 0x82)     // Read length
        XCTAssertEqual(bytes[2], 0x01)     // Get VCP Feature opcode
        XCTAssertEqual(bytes[3], 0x10)     // Brightness VCP code
        XCTAssertEqual(bytes.count, 5)     // 4 data bytes + checksum
    }

    func testChecksumCalculation() {
        let packet = DDCPacket(command: .brightness, value: 50)
        let bytes = packet.buildCommandBytes()

        // Verify checksum: XOR of (slave_addr << 1) ^ all other bytes
        let expectedChecksum = (DDCPacket.slaveAddress << 1) ^ bytes[0] ^ bytes[1] ^ bytes[2] ^ bytes[3] ^ bytes[4] ^ bytes[5]
        XCTAssertEqual(bytes[6], expectedChecksum)
    }

    func testReadChecksumCalculation() {
        let packet = DDCPacket(command: .volume, value: 0)
        let bytes = packet.buildReadCommandBytes()

        let expectedChecksum = (DDCPacket.slaveAddress << 1) ^ bytes[0] ^ bytes[1] ^ bytes[2] ^ bytes[3]
        XCTAssertEqual(bytes[4], expectedChecksum)
    }

    // MARK: - Value Clamping

    func testClampWithinRange() {
        XCTAssertEqual(clampDDCValue(0), 0)
        XCTAssertEqual(clampDDCValue(50), 50)
        XCTAssertEqual(clampDDCValue(100), 100)
    }

    func testClampAboveMax() {
        XCTAssertEqual(clampDDCValue(101), 100)
        XCTAssertEqual(clampDDCValue(255), 100)
        XCTAssertEqual(clampDDCValue(1000), 100)
    }

    func testClampBelowMin() {
        XCTAssertEqual(clampDDCValue(-1), 0)
        XCTAssertEqual(clampDDCValue(-100), 0)
        XCTAssertEqual(clampDDCValue(Int.min), 0)
    }

    func testClampBoundaryValues() {
        XCTAssertEqual(clampDDCValue(0), 0)
        XCTAssertEqual(clampDDCValue(100), 100)
    }

    // MARK: - Monitor Info

    func testMonitorInfoCreation() {
        let monitor = MonitorInfo(id: 1, name: "Dell U2720Q", isExternal: true, brightness: 70, volume: 30, supportsDDC: true)
        XCTAssertEqual(monitor.id, 1)
        XCTAssertEqual(monitor.name, "Dell U2720Q")
        XCTAssertTrue(monitor.isExternal)
        XCTAssertEqual(monitor.brightness, 70)
        XCTAssertEqual(monitor.volume, 30)
        XCTAssertTrue(monitor.supportsDDC)
    }

    func testMonitorDefaults() {
        let monitor = MonitorInfo(id: 2, name: "LG 27UL850")
        XCTAssertTrue(monitor.isExternal)
        XCTAssertEqual(monitor.brightness, 50)
        XCTAssertEqual(monitor.volume, 50)
        XCTAssertTrue(monitor.supportsDDC)
    }

    func testMonitorEquality() {
        let m1 = MonitorInfo(id: 1, name: "Test", brightness: 50, volume: 50)
        let m2 = MonitorInfo(id: 1, name: "Test", brightness: 50, volume: 50)
        XCTAssertEqual(m1, m2)
    }

    // MARK: - DDC Command Codes

    func testDDCCommandCodes() {
        XCTAssertEqual(DDCCommand.brightness.rawValue, 0x10)
        XCTAssertEqual(DDCCommand.volume.rawValue, 0x62)
        XCTAssertEqual(DDCCommand.contrast.rawValue, 0x12)
        XCTAssertEqual(DDCCommand.powerMode.rawValue, 0xD6)
    }

    // MARK: - Packet Equality

    func testPacketEquality() {
        let p1 = DDCPacket(command: .brightness, value: 50)
        let p2 = DDCPacket(command: .brightness, value: 50)
        XCTAssertEqual(p1, p2)

        let p3 = DDCPacket(command: .brightness, value: 51)
        XCTAssertNotEqual(p1, p3)
    }
}
