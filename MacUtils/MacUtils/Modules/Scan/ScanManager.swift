import MacUtilsCore
import Foundation
import AppKit
import Vision
import SwiftUI

/// Manages OCR text capture from screen regions.
final class ScanManager: ObservableObject {

    @Published var isEnabled: Bool = Settings.scanEnabled
    
    // Store overlay controllers (one per screen)
    private var overlayControllers: [ScanOverlayWindowController] = []
    private var globalMonitor: Any?

    private let reconstructor = ScanTextReconstructor()

    init() {}
    
    // MARK: - Hotkey Management
    
    func registerHotkeys() {
        if globalMonitor != nil { return }
        
        // Listen for Cmd+Shift+2 globally (Key Code 19 for '2')
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isEnabled else { return }
            
            let command = event.modifierFlags.contains(.command)
            let shift = event.modifierFlags.contains(.shift)
            
            if command && shift && event.keyCode == 19 {
                DispatchQueue.main.async {
                    self.showOverlay()
                }
            }
        }
    }
    
    func unregisterHotkeys() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
    
    // MARK: - Overlay
    
    func showOverlay() {
        // Close existing
        for controller in overlayControllers {
            controller.close()
        }
        overlayControllers.removeAll()
        
        // Create an overlay for every screen so multi-monitor setups are fully covered
        for screen in NSScreen.screens {
            let controller = ScanOverlayWindowController(scanManager: self, screen: screen)
            controller.showWindow(nil)
            overlayControllers.append(controller)
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeOverlays() {
        for controller in overlayControllers {
            controller.close()
        }
        overlayControllers.removeAll()
    }

    // MARK: - Screen Capture & OCR

    func captureAndRecognize(in rect: CGRect, completion: @escaping (String?) -> Void) {
        // Capture the screen region
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming]
        ) else {
            completion(nil)
            return
        }

        // Run OCR
        performOCR(on: cgImage, imageWidth: CGFloat(cgImage.width)) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func performOCR(on image: CGImage, imageWidth: CGFloat, completion: @escaping (String?) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation],
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

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
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
        guard Settings.scanShowHUD else { return }

        let hudView = ScanHUDView(characterCount: characterCount)
        let hostingController = NSHostingController(rootView: hudView)

        let hudWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        hudWindow.contentViewController = hostingController
        hudWindow.isOpaque = false
        hudWindow.backgroundColor = .clear
        hudWindow.level = .floating
        hudWindow.hasShadow = false
        
        // Position top center
        if let screenFrame = NSScreen.main?.visibleFrame {
            let x = screenFrame.midX - (hudWindow.frame.width / 2)
            let y = screenFrame.maxY - hudWindow.frame.height - 16
            hudWindow.setFrame(NSRect(x: x, y: y, width: hudWindow.frame.width, height: hudWindow.frame.height), display: true)
        }

        hudWindow.alphaValue = 0.0
        hudWindow.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            hudWindow.animator().alphaValue = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                hudWindow.animator().alphaValue = 0.0
            }) {
                hudWindow.orderOut(nil)
            }
        }
    }
}

private struct ScanHUDView: View {
    let characterCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.body)
            Text("Copied \(characterCount) characters")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .padding(12) // Extra padding to prevent shadow clipping
    }
}
