import MacUtilsCore
import SwiftUI

/// Main popover dropdown view shown when clicking the menu bar icon.
struct DropdownView: View {
    @ObservedObject var focusManager: FocusManager
    @ObservedObject var ctrlPasteManager: CtrlPasteManager
    @ObservedObject var lumensManager: LumensManager
    @ObservedObject var unformatManager: UnformatManager

    // Live-updating focus settings
    @State private var focusDuration: Int = Settings.focusDuration
    @State private var breakDuration: Int = Settings.breakDuration

    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Focus Section
            focusSection

            Divider()

            // 3. Lumens Section
            lumensSection

            Divider()

            // 4. Unformat Section
            unformatSection

            Divider()

            // 5. CtrlPaste Section
            ctrlPasteSection

            Divider()

            // 6. Footer
            footerSection
        }
        .padding(10)
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            focusDuration = Settings.focusDuration
            breakDuration = Settings.breakDuration
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(spacing: 10) {
            appIcon(size: 18)
                .frame(width: 20, height: 20)
            Text("MacUtils")
                .font(.title3.bold())
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private func appIcon(size: CGFloat) -> some View {
        Group {
            if let image = loadAppIcon() {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(.primary)
            } else {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: size * 0.7))
                    .foregroundColor(.primary)
            }
        }
    }

    private func loadAppIcon() -> NSImage? {
        // Try bundle resource first, then debug path
        if let path = Bundle.main.path(forResource: "icon", ofType: "png", inDirectory: "icon"),
           let img = NSImage(contentsOfFile: path) {
            return img
        }
        let debugPath = (Bundle.main.bundlePath.components(separatedBy: ".build").first ?? "") + "icon/icon.png"
        return NSImage(contentsOfFile: debugPath)
    }

    // MARK: - Focus Section

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if focusManager.state == .idle {
                focusIdleView
            } else {
                focusRunningView
            }
        }
        .padding(12)
    }

    private var focusIdleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.primary)
                    .font(.title3)
                Text("Focus")
                    .font(.title3.bold())
                Spacer()
                Text("Today: \(focusManager.todaySessionCount) sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                chip(text: "\(focusDuration) min focus", color: .purple)
                chip(text: "\(breakDuration) min break", color: .green)
            }

            TextField("What's this session about? (optional)", text: $focusManager.currentNote)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            Button(action: {
                focusManager.startFocus(note: focusManager.currentNote)
            }) {
                Text("Start focus session")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(HoverButtonStyle(filled: true, color: .blue))
            .controlSize(.small)
        }
    }

    private var focusRunningView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(focusManager.state == .focusRunning
                 ? "FOCUS SESSION · \(focusManager.sessionNumber) OF \(focusManager.sessionsPerCycle)"
                 : "BREAK · \(focusManager.sessionNumber) OF \(focusManager.sessionsPerCycle)")
                .font(.caption.bold())
                .foregroundColor(focusManager.state == .focusRunning ? .blue : .green)

            Text(focusManager.formattedTimeRemaining)
                .font(.system(size: 32, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .center)

            if !focusManager.currentNote.isEmpty {
                Text(focusManager.currentNote)
                    .font(.caption.italic())
                    .foregroundColor(.secondary)
            }

            ProgressView(value: focusManager.progress)
                .tint(focusManager.state == .focusRunning ? .blue : .green)

            HStack {
                Button(focusManager.isPaused ? "Resume" : "Pause") {
                    if focusManager.isPaused {
                        focusManager.resume()
                    } else {
                        focusManager.pause()
                    }
                }
                .buttonStyle(HoverButtonStyle())
                .controlSize(.small)

                Spacer()

                Button("Skip →") {
                    focusManager.skip()
                }
                .buttonStyle(HoverButtonStyle())
                .controlSize(.small)
            }
        }
    }

    // MARK: - Lumens Section

    private var lumensSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sun.max")
                    .foregroundColor(.primary)
                    .font(.title3)
                Text("Lumens")
                    .font(.title3.bold())
            }

            if lumensManager.monitors.isEmpty {
                Text("No external monitors detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            } else {
                ForEach(lumensManager.monitors) { monitor in
                    monitorView(monitor: monitor)
                }
            }
        }
        .padding(12)
    }

    private func monitorView(monitor: MonitorInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monitor.name)
                .font(.caption.bold())

            if monitor.supportsDDC {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(value: Binding(
                        get: { Double(monitor.brightness) },
                        set: { lumensManager.setBrightness(Int($0), for: monitor.id) }
                    ), in: 0...100)
                    Text("\(monitor.brightness)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }

                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(value: Binding(
                        get: { Double(monitor.volume) },
                        set: { lumensManager.setVolume(Int($0), for: monitor.id) }
                    ), in: 0...100)
                    Text("\(monitor.volume)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }
            } else {
                Text("DDC not supported")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Unformat

    private var unformatSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "doc.plaintext")
                    .foregroundColor(.primary)
                    .font(.title3)
                Text("Unformat")
                    .font(.title3.bold())
                Spacer()
                Toggle("", isOn: $unformatManager.isEnabled)
                    .labelsHidden()
                    .controlSize(.small)
            }
            Text("Strip formatting on paste")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
    }

    // MARK: - CtrlPaste

    private var ctrlPasteSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.primary)
                    .font(.title3)
                Text("CtrlPaste")
                    .font(.title3.bold())
                Spacer()
                if !ctrlPasteManager.recentEntries.isEmpty {
                    Button(action: {
                        ctrlPasteManager.clearHistory()
                    }) {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .controlSize(.small)
                }
            }

            if ctrlPasteManager.recentEntries.isEmpty {
                Text("No clipboard history yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(ctrlPasteManager.recentEntries) { entry in
                    Button(action: {
                        ctrlPasteManager.copyToClipboard(entry.text)
                    }) {
                        HStack {
                            Text(entry.truncated(maxLength: 40))
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(entry.relativeTime)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(HoverButtonStyle())
                }
            }
        }
        .padding(12)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 2) {
            Button(action: onOpenSettings) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                    Text("Settings...")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(HoverButtonStyle())

            Button(action: onQuit) {
                HStack {
                    Image(systemName: "power")
                        .foregroundColor(.secondary)
                    Text("Quit MacUtils")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(HoverButtonStyle())
        }
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private func chip(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundColor(color)
    }
}

// MARK: - Hover Button Style

struct HoverButtonStyle: ButtonStyle {
    var filled: Bool = false
    var color: Color = .primary

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(filled ? .white : nil)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundFill(isPressed: configuration.isPressed))
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private func backgroundFill(isPressed: Bool) -> Color {
        if filled {
            return isPressed ? color.opacity(0.6) : (isHovered ? color.opacity(0.85) : color)
        } else {
            return (isHovered || isPressed) ? Color.primary.opacity(0.08) : Color.clear
        }
    }
}
