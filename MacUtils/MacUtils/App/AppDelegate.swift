import MacUtilsCore
import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    // Module managers
    private var focusManager: FocusManager?
    private var ctrlPasteManager: CtrlPasteManager?
    private var lumensManager: LumensManager?
    private var unformatManager: UnformatManager?
    private var scanManager: ScanManager?

    // Settings window
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize module managers
        focusManager = FocusManager()
        ctrlPasteManager = CtrlPasteManager()
        lumensManager = LumensManager()
        unformatManager = UnformatManager()
        scanManager = ScanManager()

        // Setup menu bar status item
        setupStatusItem()

        // Show onboarding on first launch or if crucial permissions are missing
        if !Settings.onboardingCompleted || !AXIsProcessTrusted() {
            showOnboarding()
        }

        // Start clipboard polling
        ctrlPasteManager?.startPolling()

        // Register global hotkeys if enabled
        if Settings.scanEnabled {
            scanManager?.registerHotkeys()
        }

        if Settings.unformatEnabled {
            unformatManager?.installEventTap()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        scanManager?.unregisterHotkeys()
        unformatManager?.removeEventTap()
        ctrlPasteManager?.stopPolling()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Load custom icon and set as template (auto-adapts to light/dark mode)
            if let iconPath = Bundle.main.path(forResource: "icon_statusbar", ofType: "png", inDirectory: "icon"),
               let image = NSImage(contentsOfFile: iconPath) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                // Fallback: try loading from project directory for debug builds
                let debugPath = Bundle.main.bundlePath
                    .components(separatedBy: ".build").first ?? ""
                let iconFile = debugPath + "icon/icon_statusbar.png"
                if let image = NSImage(contentsOfFile: iconFile) {
                    image.isTemplate = true
                    image.size = NSSize(width: 18, height: 18)
                    button.image = image
                } else {
                    button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "MacUtils")
                }
            }
            button.action = #selector(togglePopover)
            button.target = self
        }

        setupPopover()
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let dropdownView = DropdownView(
            focusManager: focusManager ?? FocusManager(),
            ctrlPasteManager: ctrlPasteManager ?? CtrlPasteManager(),
            lumensManager: lumensManager ?? LumensManager(),
            unformatManager: unformatManager ?? UnformatManager(),
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )

        popover.contentViewController = NSHostingController(rootView: dropdownView)
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Refresh data before showing
            lumensManager?.refreshMonitors()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Ensure popover closes when user clicks elsewhere
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Menu Bar Updates for Focus

    func updateMenuBarForFocus(timeRemaining: String?) {
        guard let button = statusItem?.button else { return }

        if let time = timeRemaining {
            button.image = nil
            button.title = "🟠 \(time)"
        } else {
            button.title = ""
            button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Mac Utils")
        }
    }

    // MARK: - Settings

    private func openSettings() {
        popover?.performClose(nil)

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                focusManager: focusManager ?? FocusManager(),
                ctrlPasteManager: ctrlPasteManager ?? CtrlPasteManager(),
                unformatManager: unformatManager ?? UnformatManager(),
                scanManager: scanManager ?? ScanManager(),
                lumensManager: lumensManager ?? LumensManager()
            )
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let onboardingView = OnboardingView()
        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to MacUtils"
        window.setContentSize(NSSize(width: 520, height: 600))
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
