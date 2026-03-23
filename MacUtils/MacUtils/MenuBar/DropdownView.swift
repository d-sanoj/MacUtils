import MacUtilsCore
import SwiftUI

/// Main popover dropdown view shown when clicking the menu bar icon.
struct DropdownView: View {
    @ObservedObject var focusManager: FocusManager
    @ObservedObject var ctrlPasteManager: CtrlPasteManager
    @ObservedObject var lumensManager: LumensManager
    @ObservedObject var unformatManager: UnformatManager

    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. App Header
            appHeader

            // 2. Focus Section
            focusSection

            // 3. Lumens Section
            lumensSection

            // 4. Unformat Section
            unformatSection

            // 5. CtrlPaste Section
            ctrlPasteSection

            // 6. Footer
            footerSection
        }
        .padding(12)
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.title)
                .foregroundColor(.accentColor)
            Text("Mac Utils")
                .font(.title3.bold())
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
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
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var focusIdleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("Focus")
                    .font(.title3.bold())
                Spacer()
                Text("Today: \(focusManager.todaySessionCount) sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                chip(text: "\(Settings.focusDuration) min focus", color: .purple)
                chip(text: "\(Settings.breakDuration) min break", color: .green)
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
                    .foregroundColor(.orange)
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
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private func monitorView(monitor: MonitorInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monitor.name)
                .font(.caption.bold())

            if monitor.supportsDDC {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max")
                        .font(.caption2)
                    Slider(value: Binding(
                        get: { Double(monitor.brightness) },
                        set: { lumensManager.setBrightness(Int($0), for: monitor.id) }
                    ), in: 0...100)
                    Text("\(monitor.brightness)%")
                        .font(.caption2)
                        .frame(width: 30)
                }

                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption2)
                    Slider(value: Binding(
                        get: { Double(monitor.volume) },
                        set: { lumensManager.setVolume(Int($0), for: monitor.id) }
                    ), in: 0...100)
                    Text("\(monitor.volume)%")
                        .font(.caption2)
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
                    .foregroundColor(.blue)
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
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - CtrlPaste

    private var ctrlPasteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.teal)
                    .font(.title3)
                Text("CtrlPaste")
                    .font(.title3.bold())
                Spacer()
                if !ctrlPasteManager.recentEntries.isEmpty {
                    Button(action: {
                        ctrlPasteManager.clearHistory()
                    }) {
                        Image(systemName: "trash")
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
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            Button(action: onOpenSettings) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button(action: onQuit) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Mac Utils")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

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
