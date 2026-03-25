import Foundation
import AppKit

private func permissionsDebugLog(_ message: String) {
    guard ProcessInfo.processInfo.environment["MACUTILS_DEBUG_PERMISSIONS"] == "1" else { return }
    print("[Permissions] \(message)")
}

/// Manages checking and requesting macOS permissions.
final class PermissionsManager: ObservableObject {

    @Published var accessibilityGranted: Bool = false
    @Published var screenRecordingGranted: Bool = false

    private var pollTimer: Timer?

    init() {
        checkPermissions()
    }

    func checkPermissions() {
        accessibilityGranted = AXIsProcessTrusted()
        screenRecordingGranted = checkScreenRecording()
        permissionsDebugLog("check accessibility=\(accessibilityGranted) screen=\(screenRecordingGranted)")
    }

    func startPolling() {
        stopPolling()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Request Permissions

    func requestAccessibility() {
        NSApp.activate(ignoringOtherApps: true)
        permissionsDebugLog("open accessibility settings")
        openAccessibilitySettings()
    }

    func requestScreenRecording() {
        NSApp.activate(ignoringOtherApps: true)
        if CGPreflightScreenCaptureAccess() {
            screenRecordingGranted = true
            permissionsDebugLog("screen recording already granted")
            return
        }

        let granted = CGRequestScreenCaptureAccess()
        permissionsDebugLog("requestScreenRecording result=\(granted)")
        if granted {
            screenRecordingGranted = true
        }
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    func openExtensionsSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private

    private func checkScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
}
