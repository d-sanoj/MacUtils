import AppKit
import SwiftUI

/// NSWindowController for the Settings window.
final class SettingsWindowController: NSWindowController {

    convenience init(focusManager: FocusManager, ctrlPasteManager: CtrlPasteManager, unformatManager: UnformatManager, scanManager: ScanManager, lumensManager: LumensManager) {
        let settingsView = SettingsView(
            focusManager: focusManager,
            ctrlPasteManager: ctrlPasteManager,
            unformatManager: unformatManager,
            scanManager: scanManager,
            lumensManager: lumensManager
        )
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Mac Utils Settings"
        window.setContentSize(NSSize(width: 680, height: 480))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 580, height: 400)
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible

        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
