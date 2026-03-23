import Foundation

// MARK: - Lumens DDC Core Logic

/// DDC/CI VCP codes for display control
public enum DDCCommand: UInt8 {
    case brightness = 0x10
    case volume = 0x62
    case contrast = 0x12
    case powerMode = 0xD6
}

/// Represents a DDC I2C request packet
public struct DDCPacket: Equatable {
    public let address: UInt8
    public let command: DDCCommand
    public let value: UInt8

    /// DDC/CI slave address
    public static let slaveAddress: UInt8 = 0x37

    /// DDC/CI host address
    public static let hostAddress: UInt8 = 0x51

    public init(command: DDCCommand, value: UInt8) {
        self.address = Self.slaveAddress
        self.command = command
        self.value = value
    }

    /// Build the raw I2C command bytes for a DDC set VCP feature command
    /// Format: [0x51, 0x84, 0x03, VCP_OPCODE, HIGH_BYTE, LOW_BYTE, CHECKSUM]
    public func buildCommandBytes() -> [UInt8] {
        let prefix: UInt8 = Self.hostAddress
        let length: UInt8 = 0x84  // Length | 0x80 (bit 7 set for DDC/CI)
        let setVCP: UInt8 = 0x03   // Set VCP Feature opcode
        let vcpCode = command.rawValue
        let highByte: UInt8 = 0x00
        let lowByte = value

        // XOR checksum: address XOR all bytes
        let checksum = (Self.slaveAddress << 1) ^ prefix ^ length ^ setVCP ^ vcpCode ^ highByte ^ lowByte

        return [prefix, length, setVCP, vcpCode, highByte, lowByte, checksum]
    }

    /// Build the raw I2C command bytes for a DDC get VCP feature command
    /// Format: [0x51, 0x82, 0x01, VCP_OPCODE, CHECKSUM]
    public func buildReadCommandBytes() -> [UInt8] {
        let prefix: UInt8 = Self.hostAddress
        let length: UInt8 = 0x82
        let getVCP: UInt8 = 0x01
        let vcpCode = command.rawValue

        let checksum = (Self.slaveAddress << 1) ^ prefix ^ length ^ getVCP ^ vcpCode

        return [prefix, length, getVCP, vcpCode, checksum]
    }
}

/// Clamps a value to the valid DDC brightness/volume range (0–100)
public func clampDDCValue(_ value: Int) -> UInt8 {
    return UInt8(max(0, min(100, value)))
}

/// Represents a detected external monitor
public struct MonitorInfo: Identifiable, Equatable {
    public let id: UInt32  // CGDirectDisplayID
    public let name: String
    public let isExternal: Bool
    public var brightness: Int
    public var volume: Int
    public var supportsDDC: Bool

    public init(id: UInt32, name: String, isExternal: Bool = true,
                brightness: Int = 50, volume: Int = 50, supportsDDC: Bool = true) {
        self.id = id
        self.name = name
        self.isExternal = isExternal
        self.brightness = brightness
        self.volume = volume
        self.supportsDDC = supportsDDC
    }
}
