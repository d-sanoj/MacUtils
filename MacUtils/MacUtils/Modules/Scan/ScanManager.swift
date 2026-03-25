import MacUtilsCore
import Foundation
import AppKit
import Carbon
import Vision
import SwiftUI

/// Manages OCR text capture from screen regions.
final class ScanManager: ObservableObject {

    @Published var isEnabled: Bool = Settings.scanEnabled
    
    // Store overlay controllers (one per screen)
    private var overlayControllers: [ScanOverlayWindowController] = []
    private var currentHUDWindow: NSPanel?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?

    private let reconstructor = ScanTextReconstructor()
    private let scanHotKeyID: UInt32 = 1
    private let scanHotKeySignature: OSType = 0x5343414E // 'SCAN'

    init() {}

    deinit {
        unregisterHotkeys()
    }
    
    // MARK: - Hotkey Management
    
    func registerHotkeys() {
        guard hotKeyRef == nil else { return }

        if hotKeyHandlerRef == nil {
            var eventSpec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )

            let callback: EventHandlerUPP = { _, event, userData in
                guard
                    let event,
                    let userData
                else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else { return status }

                let manager = Unmanaged<ScanManager>.fromOpaque(userData).takeUnretainedValue()
                guard hotKeyID.signature == manager.scanHotKeySignature, hotKeyID.id == manager.scanHotKeyID else {
                    return noErr
                }

                DispatchQueue.main.async {
                    manager.startCapture()
                }

                return noErr
            }

            let userData = Unmanaged.passUnretained(self).toOpaque()
            let installStatus = InstallEventHandler(
                GetApplicationEventTarget(),
                callback,
                1,
                &eventSpec,
                userData,
                &hotKeyHandlerRef
            )

            guard installStatus == noErr else {
                print("[Scan] Failed to install hotkey handler: \(installStatus)")
                hotKeyHandlerRef = nil
                return
            }
        }

        var hotKeyID = EventHotKeyID(signature: scanHotKeySignature, id: scanHotKeyID)
        let modifiers = UInt32(cmdKey | shiftKey)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_2),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            print("[Scan] Failed to register Cmd+Shift+2 hotkey: \(registerStatus)")
            hotKeyRef = nil
            return
        }
    }
    
    func unregisterHotkeys() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
    
    // MARK: - Capture Flow
    
    func startCapture() {
        guard isEnabled else { return }
        
        // Close any existing overlays
        overlayControllers.forEach { $0.close() }
        overlayControllers.removeAll()
        
        // Create an overlay for each screen
        for screen in NSScreen.screens {
            let controller = ScanOverlayWindowController(scanManager: self, screen: screen)
            overlayControllers.append(controller)
            controller.showWindow(nil)
        }
    }
    
    // MARK: - OCR
    
    func captureAndRecognize(in rect: CGRect, completion: @escaping (String?) -> Void) {
        guard rect.width > 1, rect.height > 1 else {
            completion(nil)
            return
        }

        guard let cgImage = CGWindowListCreateImage(rect, .optionOnScreenBelowWindow, kCGNullWindowID, [.bestResolution]) else {
            completion(nil)
            return
        }
        
        let imageWidth = CGFloat(cgImage.width)

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  !observations.isEmpty else {
                completion(nil)
                return
            }

            let textObservations = observations.compactMap { observation -> MacUtilsCore.TextObservation? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return MacUtilsCore.TextObservation(
                    text: candidate.string,
                    boundingBox: observation.boundingBox,
                    confidence: candidate.confidence
                )
            }

            // Use reconstructor for indentation
            let reconstructor = ScanTextReconstructor()
            let result = reconstructor.reconstructFromNormalized(
                observations: textObservations,
                imageWidth: imageWidth
            )

            completion(result)
        }

        request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    // MARK: - Copy Result

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func showHUD(characterCount: Int) {
        currentHUDWindow?.orderOut(nil)
        currentHUDWindow = nil

        let hudView = NSHostingView(rootView: ScanHUDView())
        hudView.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        let fittingSize = hudView.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: max(fittingSize.width, 200), height: max(fittingSize.height, 44)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hudView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true

        // Position top center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = screenFrame.midX - (fittingSize.width / 2)
            let y = screenFrame.maxY - fittingSize.height - 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.currentHUDWindow = panel
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.currentHUDWindow === panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                panel.animator().alphaValue = 0.0
            }) {
                panel.orderOut(nil)
                if self.currentHUDWindow === panel {
                    self.currentHUDWindow = nil
                }
            }
        }
    }
}

private struct ScanHUDView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
            Text("Content copied")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .fixedSize()
    }
}
