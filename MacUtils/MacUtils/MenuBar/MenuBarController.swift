import AppKit

/// Central controller for the menu bar icon (NSStatusItem).
/// Handles icon updates and coordinates with the AppDelegate.
final class MenuBarController {

    private let statusItem: NSStatusItem

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        setupDefaultIcon()
    }

    // MARK: - Icon Management

    func setupDefaultIcon() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Mac Utils")
            button.image?.size = NSSize(width: 18, height: 18)
            button.title = ""
        }
    }

    func showTimerIcon(timeRemaining: String) {
        if let button = statusItem.button {
            button.image = nil
            button.title = "🟠 \(timeRemaining)"
        }
    }

    func resetToDefaultIcon() {
        setupDefaultIcon()
    }

    var button: NSStatusBarButton? {
        return statusItem.button
    }
}
