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
            // 1. App Header
            appHeader
                .padding(.bottom, 8)

            Divider()

            // 2. Focus Section
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
                Image(systemName: "square.grid.2x2.fill")
                .font(.title2)
                .foregroundColor(.primary)
            Text("Mac Utils")
                .font(.title3.bold())
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
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
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
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
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Skip →") {
                    focusManager.skip()
                }
                .buttonStyle(.bordered)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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
                    .buttonStyle(.plain)
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
                        .padding(.horizontal, 6)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 4) {
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
            .buttonStyle(.plain)

            Button(action: onQuit) {
                HStack {
                    Image(systemName: "power")
                        .foregroundColor(.secondary)
                    Text("Quit Mac Utils")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
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
