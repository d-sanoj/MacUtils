import MacUtilsCore
import Foundation
import AppKit
import IOKit
import IOKit.i2c

// MARK: - IOAVService declarations (private API, works on Apple Silicon)

/// Opaque type for IOAVService connections
typealias IOAVServiceRef = CFTypeRef

/// Create an IOAVService for a given display location
@_silgen_name("IOAVServiceCreate")
func IOAVServiceCreate(_ allocator: CFAllocator?) -> IOAVServiceRef?

@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> IOAVServiceRef?

/// Read I2C data through AVService (Apple Silicon DDC)
@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(
    _ service: IOAVServiceRef,
    _ chipAddress: UInt32,
    _ offset: UInt32,
    _ outputBuffer: UnsafeMutableRawPointer,
    _ outputBufferSize: UInt32
) -> IOReturn

/// Write I2C data through AVService (Apple Silicon DDC)
@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(
    _ service: IOAVServiceRef,
    _ chipAddress: UInt32,
    _ dataAddress: UInt32,
    _ inputBuffer: UnsafeMutableRawPointer,
    _ inputBufferSize: UInt32
) -> IOReturn

// MARK: - LumensManager

/// Manages external monitor brightness and volume via DDC/CI.
/// Uses IOAVService on Apple Silicon (same approach as MonitorControl).
final class LumensManager: ObservableObject {

    @Published var monitors: [MonitorInfo] = []

    // Cache AVService references per display  
    private var avServices: [CGDirectDisplayID: IOAVServiceRef] = [:]

    // Event Tap for media keys
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        refreshMonitors()
        installEventTap()
    }

    // MARK: - Monitor Enumeration

    func refreshMonitors() {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0

        guard CGGetActiveDisplayList(16, &displayIDs, &displayCount) == .success else {
            monitors = []
            return
        }

        var detectedMonitors: [MonitorInfo] = []
        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]

            // Skip the built-in display
            if CGDisplayIsBuiltin(displayID) != 0 {
                continue
            }

            let name = displayName(for: displayID) ?? "External Display \(i + 1)"

            var monitor = MonitorInfo(
                id: displayID,
                name: name,
                isExternal: true,
                brightness: 50,
                volume: 50,
                supportsDDC: false
            )

            // Try to get AVService for this display
            if let avService = getAVService(for: displayID) {
                avServices[displayID] = avService

                // Try to read brightness
                if let brightness = ddcReadViaAVService(avService: avService, command: .brightness) {
                    monitor.brightness = Int(brightness)
                    monitor.supportsDDC = true
                } else {
                    // AVService exists but read failed — still mark as DDC supported
                    // Some monitors support write but not read
                    monitor.supportsDDC = true
                    print("[Lumens] DDC read failed for \(name), but AVService available — write may still work")
                }

                // Try to read volume
                if let volume = ddcReadViaAVService(avService: avService, command: .volume) {
                    monitor.volume = Int(volume)
                }
            } else {
                // Try legacy IOFramebuffer I2C as fallback (Intel Macs)
                if let brightness = legacyDDCRead(displayID: displayID, command: .brightness) {
                    monitor.brightness = Int(brightness)
                    monitor.supportsDDC = true
                }
            }

            detectedMonitors.append(monitor)
        }

        DispatchQueue.main.async { [weak self] in
            self?.monitors = detectedMonitors
        }
    }

    // MARK: - DDC Control (Public)

    func setBrightness(_ value: Int, for monitorID: UInt32) {
        let clamped = clampDDCValue(value)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let avService = self.avServices[monitorID] {
                self.ddcWriteViaAVService(avService: avService, command: .brightness, value: clamped)
            } else {
                self.legacyDDCWrite(displayID: monitorID, command: .brightness, value: clamped)
            }

            DispatchQueue.main.async {
                if let index = self.monitors.firstIndex(where: { $0.id == monitorID }) {
                    self.monitors[index].brightness = Int(clamped)
                }
            }
        }
    }

    func setVolume(_ value: Int, for monitorID: UInt32) {
        let clamped = clampDDCValue(value)

        if let avService = avServices[monitorID] {
            ddcWriteViaAVService(avService: avService, command: .volume, value: clamped)
        } else {
            legacyDDCWrite(displayID: monitorID, command: .volume, value: clamped)
        }

        if let index = monitors.firstIndex(where: { $0.id == monitorID }) {
            monitors[index].volume = Int(clamped)
        }
    }

    func increaseBrightness() {
        let currentSnapshot = monitors // Take local snapshot of current values
        for monitor in currentSnapshot {
            setBrightness(min(100, monitor.brightness + 5), for: monitor.id)
        }
    }

    func decreaseBrightness() {
        let currentSnapshot = monitors
        for monitor in currentSnapshot {
            setBrightness(max(0, monitor.brightness - 5), for: monitor.id)
        }
    }

    func increaseVolume() {
        for monitor in monitors {
            setVolume(min(100, monitor.volume + 5), for: monitor.id)
        }
    }

    func decreaseVolume() {
        for monitor in monitors {
            setVolume(max(0, monitor.volume - 5), for: monitor.id)
        }
    }

    func toggleMute() {
        for index in 0..<monitors.count {
            let monitor = monitors[index]
            if monitor.volume > 0 {
                monitors[index].lastVolume = monitor.volume
                setVolume(0, for: monitor.id)
            } else {
                let restore = monitor.lastVolume ?? 50
                setVolume(restore, for: monitor.id)
            }
        }
    }

    // MARK: - Event Tap for Media Keys

    private func installEventTap() {
        let eventMask: CGEventMask = (1 << 14)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<LumensManager>.fromOpaque(refcon).takeUnretainedValue()

            let mapBrightness = Settings.lumensMapBrightness
            let mapVolume = Settings.lumensMapVolume

            if type.rawValue == 14 {
                // systemDefined (Media Keys)
                let nsEvent = NSEvent(cgEvent: event)
                guard nsEvent?.subtype.rawValue == 8 else { return Unmanaged.passRetained(event) }

                let data1 = nsEvent?.data1 ?? 0
                let keyCode = (data1 & 0xFFFF0000) >> 16
                let keyFlags = (data1 & 0x0000FFFF)
                let keyDown = ((keyFlags & 0xFF00) >> 8) == 0xA

                let isTargetKey = (mapBrightness && (keyCode == 2 || keyCode == 3 || keyCode == 21 || keyCode == 22)) ||
                                  (mapVolume && (keyCode == 0 || keyCode == 1 || keyCode == 7))

                if isTargetKey && !manager.monitors.isEmpty {
                    if keyDown {
                        DispatchQueue.main.async {
                            if keyCode == 2 || keyCode == 22 { manager.increaseBrightness() }
                            else if keyCode == 3 || keyCode == 21 { manager.decreaseBrightness() }
                            else if keyCode == 0 { manager.increaseVolume() }
                            else if keyCode == 1 { manager.decreaseVolume() }
                            else if keyCode == 7 { manager.toggleMute() }
                        }
                    }
                    return nil // Swallow event natively to prevent macOS OSD overlay
                }
            } else if type == .keyDown {
                // F14 (107) and F15 (113) for Mac desktop keyboards
                // 144 and 145 are common alternative brightness keycodes on 3rd party keyboards
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let isBrightnessKey = (keyCode == 107 || keyCode == 113 || keyCode == 122 || keyCode == 120 || keyCode == 144 || keyCode == 145) // Always enabled to prevent toggle bugs
                
                if isBrightnessKey && !manager.monitors.isEmpty {
                    DispatchQueue.global(qos: .userInitiated).async {
                        if keyCode == 113 || keyCode == 120 || keyCode == 144 { manager.increaseBrightness() }
                        else if keyCode == 107 || keyCode == 122 || keyCode == 145 { manager.decreaseBrightness() }
                    }
                    return nil // Swallow event natively to prevent macOS OSD overlay
                }

                // F10 is 109, some boards map mute to F10 directly
                if mapVolume && (keyCode == 109 || keyCode == 7) && !manager.monitors.isEmpty {
                    DispatchQueue.main.async { manager.toggleMute() }
                    return nil // Swallow event natively to prevent macOS OSD overlay
                }
            }

            return Unmanaged.passRetained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: refcon
        )

        guard let tap = eventTap else {
            print("[Lumens] Failed to create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - AVService DDC (Apple Silicon — primary method)

    /// Get the IOAVService for a specific display by finding its DCPAVServiceProxy
    private func getAVService(for displayID: CGDirectDisplayID) -> IOAVServiceRef? {
        // Try to find the display's IOService and create AVService from it
        var iterator: io_iterator_t = 0
        if let matching = IOServiceMatching("DCPAVServiceProxy") {
            if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS {
                defer { IOObjectRelease(iterator) }
                var service = IOIteratorNext(iterator)
                while service != 0 {
                    // Because DDC is mostly for external monitors, just link to the first working Proxy
                    if let avService = IOAVServiceCreateWithService(kCFAllocatorDefault, service) {
                        IOObjectRelease(service)
                        return avService
                    }
                    IOObjectRelease(service)
                    service = IOIteratorNext(iterator)
                }
            }
        }

        // Try the simpler IOAVServiceCreate (returns default service)
        if let avService = IOAVServiceCreate(kCFAllocatorDefault) {
            return avService
        }

        return nil
    }

    /// Write DDC command via IOAVService (Apple Silicon)
    @discardableResult
    private func ddcWriteViaAVService(avService: IOAVServiceRef, command: DDCCommand, value: UInt8) -> Bool {
        // DDC/CI Set VCP Feature: [0x51, 0x84, 0x03, vcp_code, 0x00, value, checksum]
        // But on IOAVService, length/source are implicit in the buffer passed.
        // Wait, MonitorControl sends length/opcode/vcp inside the buffer:
        var data: [UInt8] = [
            0x84,              // Length byte: 0x80 | 4
            0x03,              // Set VCP Feature opcode
            command.rawValue,  // VCP code (brightness=0x10, volume=0x62)
            0x00,              // Value high byte
            value,             // Value low byte
        ]

        var checksum: UInt8 = 0x51 ^ 0x6E  // source ^ (dest << 1)
        for byte in data { checksum ^= byte }
        data.append(checksum)

        let result = data.withUnsafeMutableBytes { buffer in
            IOAVServiceWriteI2C(avService, 0x37, 0x51, buffer.baseAddress!, UInt32(buffer.count))
        }

        usleep(50_000) // 50ms delay
        return result == KERN_SUCCESS
    }

    /// Read DDC value via IOAVService (Apple Silicon)
    private func ddcReadViaAVService(avService: IOAVServiceRef, command: DDCCommand) -> UInt8? {
        var getData: [UInt8] = [
            0x82,              // Length byte: 0x80 | 2
            0x01,              // Get VCP Feature opcode
            command.rawValue,  // VCP code
        ]
        
        var getChecksum: UInt8 = 0x51 ^ 0x6E
        for byte in getData { getChecksum ^= byte }
        getData.append(getChecksum)

        let writeResult = getData.withUnsafeMutableBytes { buffer in
            IOAVServiceWriteI2C(avService, 0x37, 0x51, buffer.baseAddress!, UInt32(buffer.count))
        }

        guard writeResult == KERN_SUCCESS else { return nil }
        
        usleep(40_000) // 40ms delay

        // Needs 12 bytes to catch the full reply chunk on Apple Silicon
        var replyData = [UInt8](repeating: 0, count: 12)
        let readResult = replyData.withUnsafeMutableBytes { buffer in
            IOAVServiceReadI2C(avService, 0x37, 0x51, buffer.baseAddress!, UInt32(buffer.count))
        }

        guard readResult == KERN_SUCCESS else { return nil }

        // Find the VCP reply (0x02) and extract the current value
        // The script successfully found it at offset 2, where length allows checking to offset+7
        for offset in 0..<replyData.count where replyData[offset] == 0x02 {
            if offset + 7 < replyData.count {
                return replyData[offset + 7]
            }
        }

        return nil
    }

    // MARK: - Legacy IOFramebuffer I2C DDC (Intel Macs fallback)

    private func legacyDDCRead(displayID: CGDirectDisplayID, command: DDCCommand) -> UInt8? {
        guard let framebuffer = findFramebuffer(for: displayID) else { return nil }
        defer { IOObjectRelease(framebuffer) }

        var busCount: IOItemCount = 0
        guard IOFBGetI2CInterfaceCount(framebuffer, &busCount) == KERN_SUCCESS, busCount > 0 else {
            return nil
        }

        for bus in 0..<IOOptionBits(busCount) {
            var interface: io_service_t = 0
            guard IOFBCopyI2CInterfaceForBus(framebuffer, bus, &interface) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(interface) }

            var connect: IOI2CConnectRef?
            guard IOI2CInterfaceOpen(interface, 0, &connect) == KERN_SUCCESS, let conn = connect else { continue }
            defer { IOI2CInterfaceClose(conn, 0) }

            // Build VCP Get request
            var sendData: [UInt8] = [0x51, 0x82, 0x01, command.rawValue]
            let checksum = sendData.reduce(UInt8(0x6E)) { $0 ^ $1 }
            sendData.append(checksum)

            var replyData = [UInt8](repeating: 0, count: 12)

            var request = IOI2CRequest()
            request.sendAddress = 0x6E
            request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
            request.sendBytes = UInt32(sendData.count)
            request.replyAddress = 0x6F
            request.replyTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
            request.replyBytes = UInt32(replyData.count)
            request.minReplyDelay = 10_000_000

            let success = sendData.withUnsafeMutableBytes { sendBuf in
                replyData.withUnsafeMutableBytes { replyBuf -> Bool in
                    request.sendBuffer = vm_address_t(bitPattern: sendBuf.baseAddress)
                    request.replyBuffer = vm_address_t(bitPattern: replyBuf.baseAddress)
                    return IOI2CSendRequest(conn, 0, &request) == KERN_SUCCESS
                }
            }

            if success && replyData.count >= 11 && replyData[2] == 0x02 {
                return replyData[9]
            }
        }
        return nil
    }

    @discardableResult
    private func legacyDDCWrite(displayID: CGDirectDisplayID, command: DDCCommand, value: UInt8) -> Bool {
        guard let framebuffer = findFramebuffer(for: displayID) else { return false }
        defer { IOObjectRelease(framebuffer) }

        var busCount: IOItemCount = 0
        guard IOFBGetI2CInterfaceCount(framebuffer, &busCount) == KERN_SUCCESS, busCount > 0 else {
            return false
        }

        var interface: io_service_t = 0
        guard IOFBCopyI2CInterfaceForBus(framebuffer, 0, &interface) == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(interface) }

        var connect: IOI2CConnectRef?
        guard IOI2CInterfaceOpen(interface, 0, &connect) == KERN_SUCCESS, let conn = connect else { return false }
        defer { IOI2CInterfaceClose(conn, 0) }

        var data: [UInt8] = [0x51, 0x84, 0x03, command.rawValue, 0x00, value]
        let checksum = data.reduce(UInt8(0x6E)) { $0 ^ $1 }
        data.append(checksum)

        var request = IOI2CRequest()
        request.sendAddress = 0x6E
        request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
        request.sendBytes = UInt32(data.count)

        let result = data.withUnsafeMutableBytes { buffer -> Bool in
            request.sendBuffer = vm_address_t(bitPattern: buffer.baseAddress)
            return IOI2CSendRequest(conn, 0, &request) == KERN_SUCCESS
        }

        usleep(50_000)
        return result
    }

    private func findFramebuffer(for displayID: CGDirectDisplayID) -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOFramebuffer") else { return nil }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var busCount: IOItemCount = 0
            if IOFBGetI2CInterfaceCount(service, &busCount) == KERN_SUCCESS && busCount > 0 {
                return service
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    // MARK: - Display Name

    private func displayName(for displayID: CGDirectDisplayID) -> String? {
        let vendorNumber = CGDisplayVendorNumber(displayID)
        let modelNumber = CGDisplayModelNumber(displayID)

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IODisplayConnect")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let info = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary?,
               let vid = info[kDisplayVendorID] as? UInt32,
               let pid = info[kDisplayProductID] as? UInt32,
               vid == vendorNumber && pid == modelNumber,
               let names = info[kDisplayProductName] as? [String: String],
               let name = names["en_US"] ?? names.values.first {
                IOObjectRelease(service)
                return name
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return "External Display"
    }
}
