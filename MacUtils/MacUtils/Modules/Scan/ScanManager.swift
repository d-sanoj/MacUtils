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
    private var currentHUDWindow: NSPanel?

    private let reconstructor = ScanTextReconstructor()

    init() {}
    
    // MARK: - Hotkey Management
    
    func registerHotkeys() {
        // Monitor for Cmd + Shift + 2 globally
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            // Cmd + Shift + 2: keyCode 19
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 19 {
                DispatchQueue.main.async {
                    self.startCapture()
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
        let fittingSize = hudView.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: fittingSize.width, height: fittingSize.height),
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
    }
}
