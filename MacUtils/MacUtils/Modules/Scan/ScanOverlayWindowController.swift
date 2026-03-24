import AppKit
import SwiftUI
import CoreGraphics

/// A full-screen transparent window that allows the user to drag a rectangle for OCR.
final class ScanOverlayWindowController: NSWindowController {
    
    private let scanManager: ScanManager
    private var overlayView: ScanOverlayNSView!
    
    init(scanManager: ScanManager, screen: NSScreen) {
        self.scanManager = scanManager
        
        let overlayRect = screen.frame
        let window = NSWindow(
            contentRect: overlayRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        super.init(window: window)
        
        overlayView = ScanOverlayNSView(frame: overlayRect)
        overlayView.onSelectionComplete = { [weak self] rect in
            self?.close()
            // Convert window rect to global screen coordinates for CGWindowListCreateImage
            // NSScreen has origin at bottom-left, CGWindowList has origin at top-left
            guard let screenFrame = self?.window?.screen?.frame else { return }
            var cgRect = rect
            cgRect.origin.y = screenFrame.height - rect.maxY // Flip Y
            // Adjust for screen origin in global space
            cgRect.origin.x += screenFrame.minX
            cgRect.origin.y += (NSScreen.screens.first?.frame.height ?? 0) - screenFrame.maxY
            
            // Allow window to fully close before capturing to avoid capturing the overlay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scanManager.captureAndRecognize(in: cgRect) { result in
                    if let text = result {
                        scanManager.copyToClipboard(text)
                        DispatchQueue.main.async {
                            scanManager.showHUD(characterCount: text.count)
                        }
                    }
                }
            }
        }
        
        window.contentView = overlayView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()
    }

    override func close() {
        NSCursor.arrow.set()
        super.close()
    }
}

/// The actual NSView that draws the dark overlay and the clear selection rectangle.
final class ScanOverlayNSView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let start = startPoint, let end = currentPoint else { return }
        
        let rect = NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        startPoint = nil
        currentPoint = nil
        needsDisplay = true
        
        if rect.width > 10 && rect.height > 10 {
            onSelectionComplete?(rect)
        } else {
            // Cancelled
            onSelectionComplete?(CGRect.zero)
        }
    }
    
    // Press Escape to cancel
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onSelectionComplete?(CGRect.zero)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw dark overlay
        NSColor(white: 0.0, alpha: 0.3).setFill()
        dirtyRect.fill()
        
        // Clear out the selection rectangle
        if let start = startPoint, let end = currentPoint {
            let rect = NSRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            
            NSColor.clear.setFill()
            rect.fill(using: .copy)
            
            // Draw border
            NSColor.white.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1.0
            path.stroke()
        }
    }
}
