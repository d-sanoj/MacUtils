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
        window.setContentSize(NSSize(width: 640, height: 480))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
    }
}
