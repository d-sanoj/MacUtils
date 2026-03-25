import MacUtilsCore
import Foundation
import AppKit

/// Manages paste formatting stripping via CGEvent tap.
final class UnformatManager: ObservableObject {

    @Published var isEnabled: Bool = Settings.unformatEnabled {
        didSet {
            Settings.unformatEnabled = isEnabled
            refreshEventTap()
        }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let processor = UnformatProcessor()

    init() {}

    deinit {
        removeEventTap()
    }

    // MARK: - Event Tap

    func refreshEventTap() {
        guard isEnabled, AXIsProcessTrusted() else {
            removeEventTap()
            return
        }

        guard eventTap == nil else { return }
        installEventTap()
    }

    func installEventTap() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<UnformatManager>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }

            guard type == .keyDown else { return Unmanaged.passRetained(event) }

            // Check for ⌘V (keycode 9, command modifier)
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            guard keyCode == 9, flags.contains(.maskCommand), !flags.contains(.maskControl), !flags.contains(.maskAlternate) else {
                return Unmanaged.passRetained(event)
            }

            guard manager.isEnabled else { return Unmanaged.passRetained(event) }

            // Strip formatting from pasteboard
            manager.stripPasteboardFormatting()

            return Unmanaged.passRetained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: refcon
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap — Accessibility permission may be required")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func removeEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    // MARK: - Formatting Strip

    private func stripPasteboardFormatting() {
        let pasteboard = NSPasteboard.general
        let plainText = pasteboard.string(forType: .string)
        let rtfData = pasteboard.data(forType: .rtf)
        let htmlData = pasteboard.data(forType: .html)

        guard let text = processor.process(plainText: plainText, rtfData: rtfData, htmlData: htmlData) else {
            return
        }

        // Only rewrite if there was rich formatting
        if processor.hasRichFormatting(rtfData: rtfData, htmlData: htmlData) {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            if Settings.unformatShowNotification {
                showStrippedNotification()
            }
        }
    }

    private func showStrippedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Formatting stripped"
        content.body = "Paste will use plain text"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

import UserNotifications
