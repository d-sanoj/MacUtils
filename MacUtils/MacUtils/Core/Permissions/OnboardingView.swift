import SwiftUI

/// First-launch permission wizard shown as a window.
struct OnboardingView: View {
    @StateObject private var permissions = PermissionsManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("Welcome to Mac Utils")
                    .font(.title.bold())
                Text("Grant permissions to enable all features")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            Divider()

            // Permission steps
            VStack(spacing: 16) {
                permissionRow(
                    step: 1,
                    title: "Accessibility",
                    description: "Required for clipboard interception and global keyboard shortcuts (e.g., Lumens Brightness/Volume).",
                    isGranted: permissions.accessibilityGranted,
                    action: {
                        permissions.requestAccessibility()
                        permissions.openAccessibilitySettings()
                    }
                )

                permissionRow(
                    step: 2,
                    title: "Screen Recording",
                    description: "Required for OCR text capture (Scan module)",
                    isGranted: permissions.screenRecordingGranted,
                    action: {
                        permissions.requestScreenRecording()
                        permissions.openScreenRecordingSettings()
                    }
                )

                permissionRow(
                    step: 3,
                    title: "Launch at Login",
                    description: "Start Mac Utils automatically when you log in",
                    isGranted: Settings.launchAtLogin,
                    action: {
                        Settings.launchAtLogin.toggle()
                    },
                    isOptional: true
                )
            }
            .padding(24)

            Spacer()

            Divider()

            // Done button
            HStack {
                Spacer()
                Button("Done") {
                    Settings.onboardingCompleted = true
                    permissions.stopPolling()
                    dismiss()
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!permissions.accessibilityGranted || !permissions.screenRecordingGranted)
                .controlSize(.large)
            }
            .padding(20)
        }
        .frame(width: 480, height: 560)
        .onAppear {
            permissions.startPolling()
        }
        .onDisappear {
            permissions.stopPolling()
        }
    }

    private func permissionRow(step: Int, title: String, description: String, isGranted: Bool, action: @escaping () -> Void, isOptional: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)

                if isGranted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(step)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    if isOptional {
                        Text("Optional")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.gray.opacity(0.2)))
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isGranted {
                Button("Open Settings") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
