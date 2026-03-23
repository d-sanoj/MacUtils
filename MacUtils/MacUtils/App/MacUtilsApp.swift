import SwiftUI

@main
struct MacUtilsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window scene — we're a menu bar only app (LSUIElement = YES)
        SwiftUI.Settings {
            EmptyView()
        }
    }
}
