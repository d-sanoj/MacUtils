import SwiftUI

/// First-launch permission wizard shown as a window.
struct OnboardingView: View {
    @StateObject private var permissions = PermissionsManager()
    @State private var didRequestRelaunch = false
    @State private var relaunchTask: Process?

    private let steps = [
        OnboardingStep(
            icon: "hand.raised.fill",
            title: "Accessibility",
            description: "Required for global keyboard shortcuts and clipboard interception. This enables Lumens brightness/volume controls, Unformat paste stripping, and CtrlPaste clipboard history.",
            color: .blue
        ),
        OnboardingStep(
            icon: "camera.metering.spot",
            title: "Screen Recording",
            description: "Required for OCR text capture with the Scan module. Mac Utils captures a screenshot of the selected region to extract text.",
            color: .purple
        ),
        OnboardingStep(
            icon: "power",
            title: "Launch at Login",
            description: "Start Mac Utils automatically when you log in so your utilities are always available in the menu bar.",
            color: .green
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Group {
                    if let path = Bundle.main.path(forResource: "icon", ofType: "png", inDirectory: "icon") ?? Bundle.main.path(forResource: "icon", ofType: "png"),
                       let img = NSImage(contentsOfFile: path) {
                        Image(nsImage: img)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                            .foregroundColor(.primary)
                    } else {
                        let debugPath = (Bundle.main.bundlePath.components(separatedBy: ".build").first ?? "") + "icon/icon.png"
                        if let img = NSImage(contentsOfFile: debugPath) {
                            Image(nsImage: img)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 72, height: 72)
                                .foregroundColor(.primary)
                        } else {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.primary)
                        }
                    }
                }

                Text("Welcome to MacUtils")
                    .font(.largeTitle.bold())

                Text("A few permissions are needed to enable all features.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.bottom, 28)

            Divider()

            // Permission steps
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    permissionRow(
                        step: index,
                        config: step,
                        isGranted: permissionGranted(for: index),
                        action: { performAction(for: index) }
                    )

                    if index < steps.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            Divider()

            Text("Restart or reopen the app after enabling the permissions and MacUtils will launch in the status bar. You can check whether permissions are enabled from the Permissions tab in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
            .padding(20)
        }
        .frame(width: 520, height: 600)
        .onAppear {
            permissions.startPolling()
        }
        .onDisappear {
            permissions.stopPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.checkPermissions()
        }
        .onChange(of: allRequiredGranted) { granted in
            guard granted else { return }
            relaunchIfNeeded()
        }
    }

    private var allRequiredGranted: Bool {
        permissions.accessibilityGranted && permissions.screenRecordingGranted
    }

    private func permissionGranted(for index: Int) -> Bool {
        switch index {
        case 0: return permissions.accessibilityGranted
        case 1: return permissions.screenRecordingGranted
        case 2: return Settings.launchAtLogin
        default: return false
        }
    }

    private func performAction(for index: Int) {
        switch index {
        case 0:
            permissions.requestAccessibility()
        case 1:
            permissions.requestScreenRecording()
        case 2:
            Settings.launchAtLogin.toggle()
        default:
            break
        }
    }

    private func relaunchIfNeeded() {
        guard !didRequestRelaunch else { return }
        didRequestRelaunch = true
        Settings.onboardingCompleted = true
        permissions.stopPolling()

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = [
            "-c",
            """
            target_pid="$1"
            app_path="$2"
            deadline=$(( $(date +%s) + 30 ))

            while kill -0 "$target_pid" 2>/dev/null; do
                if [ "$(date +%s)" -ge "$deadline" ]; then
                    exit 0
                fi
                sleep 1
            done

            sleep 1
            /usr/bin/open "$app_path"
            """,
            "sh",
            String(currentPID),
            bundlePath
        ]
        relaunchTask = task

        try? task.run()
        NSApp.terminate(nil)
    }

    private func permissionRow(step: Int, config: OnboardingStep, isGranted: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green : config.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: isGranted ? "checkmark" : config.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isGranted ? .white : config.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(config.title)
                        .font(.headline)
                    if step == 2 {
                        Text("Optional")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.gray.opacity(0.15)))
                    }
                }
                Text(config.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            } else {
                Button("Enable") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .tint(config.color)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
    let color: Color
}
