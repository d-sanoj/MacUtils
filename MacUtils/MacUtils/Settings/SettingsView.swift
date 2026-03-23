import SwiftUI
import AppKit
import MacUtilsCore

/// Settings window with tabbed view for each module.
struct SettingsView: View {
    @ObservedObject var focusManager: FocusManager
    @ObservedObject var ctrlPasteManager: CtrlPasteManager
    @ObservedObject var unformatManager: UnformatManager
    @ObservedObject var scanManager: ScanManager
    @ObservedObject var lumensManager: LumensManager

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            lumensSettingsTab
                .tabItem { Label("Lumens", systemImage: "sun.max") }
            unformatSettingsTab
                .tabItem { Label("Unformat", systemImage: "doc.plaintext") }
            ctrlPasteSettingsTab
                .tabItem { Label("CtrlPaste", systemImage: "doc.on.clipboard") }
            scanSettingsTab
                .tabItem { Label("Scan", systemImage: "text.viewfinder") }
            focusSettingsTab
                .tabItem { Label("Focus", systemImage: "timer") }
            glimpseSettingsTab
                .tabItem { Label("Glimpse", systemImage: "eye") }
        }
        .formStyle(.grouped)
        .frame(width: 680, height: 500)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { Settings.launchAtLogin },
                    set: { Settings.launchAtLogin = $0 }
                ))

                Toggle(isOn: .constant(true)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Mac Utils in menu bar")
                        Text("Always visible for quick access")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(true)
            } header: {
                Label("Startup", systemImage: "power")
            }

            Section {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
                Link("GitHub Repository", destination: URL(string: "https://github.com/d-sanoj/MacUtils")!)
            } header: {
                Label("About", systemImage: "info.circle")
            }
        }
    }

    // MARK: - Lumens Tab

    private var lumensSettingsTab: some View {
        Form {
            Section {
                Toggle("Map F1/F2 to brightness", isOn: Binding(
                    get: { Settings.lumensMapBrightness },
                    set: { Settings.lumensMapBrightness = $0 }
                ))
                Toggle("Map F10/F11/F12 to volume", isOn: Binding(
                    get: { Settings.lumensMapVolume },
                    set: { Settings.lumensMapVolume = $0 }
                ))
            } header: {
                Label("Hotkey Mapping", systemImage: "keyboard")
            }

            Section {
                if lumensManager.monitors.isEmpty {
                    HStack {
                        Image(systemName: "display.trianglebadge.exclamationmark")
                            .foregroundColor(.secondary)
                        Text("No external monitors detected")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(lumensManager.monitors) { monitor in
                        HStack {
                            Image(systemName: "display")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(monitor.name)
                                    .font(.body)
                                Text(monitor.supportsDDC ? "DDC/CI Connected" : "DDC Not Available")
                                    .font(.caption)
                                    .foregroundColor(monitor.supportsDDC ? .green : .orange)
                            }
                            Spacer()
                            if monitor.supportsDDC {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } header: {
                Label("Detected Monitors", systemImage: "display.2")
            }
        }
    }

    // MARK: - Unformat Tab

    private var unformatSettingsTab: some View {
        Form {
            Section {
                Toggle("Enable Unformat", isOn: $unformatManager.isEnabled)
                Toggle(isOn: Binding(
                    get: { Settings.unformatShowNotification },
                    set: { Settings.unformatShowNotification = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show notification")
                        Text("Display a notification when formatting is stripped from pasted text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("Paste Stripping", systemImage: "scissors")
            }
        }
    }

    // MARK: - CtrlPaste Tab

    private var ctrlPasteSettingsTab: some View {
        Form {
            Section {
                Toggle("Enable CtrlPaste", isOn: Binding(
                    get: { Settings.ctrlPasteEnabled },
                    set: { Settings.ctrlPasteEnabled = $0 }
                ))

                if !ctrlPasteManager.entries.isEmpty {
                    Button("Clear all history", role: .destructive) {
                        ctrlPasteManager.clearHistory()
                    }
                }
            } header: {
                Label("Clipboard History", systemImage: "doc.on.clipboard")
            }

            Section {
                if ctrlPasteManager.entries.isEmpty {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundColor(.secondary)
                        Text("No history")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(ctrlPasteManager.entries) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.truncated(maxLength: 60))
                                            .font(.caption)
                                            .lineLimit(1)
                                        Text(entry.relativeTime)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        ctrlPasteManager.removeEntry(id: entry.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            } header: {
                Label("History (\(ctrlPasteManager.entries.count) entries)", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    // MARK: - Scan Tab

    private var scanSettingsTab: some View {
        Form {
            Section {
                Toggle("Enable Scan", isOn: Binding(
                    get: { Settings.scanEnabled },
                    set: { Settings.scanEnabled = $0 }
                ))

                LabeledContent("Keyboard shortcut") {
                    Text(Settings.scanShortcut)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .font(.caption.monospaced())
                }

                Toggle(isOn: Binding(
                    get: { Settings.scanAutoAddToCtrlPaste },
                    set: { Settings.scanAutoAddToCtrlPaste = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-add to CtrlPaste history")
                        Text("Captured text is automatically saved to clipboard history")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle("Show character count HUD", isOn: Binding(
                    get: { Settings.scanShowHUD },
                    set: { Settings.scanShowHUD = $0 }
                ))
            } header: {
                Label("Text Capture", systemImage: "text.viewfinder")
            }
        }
    }

    // MARK: - Focus Tab

    private var focusSettingsTab: some View {
        Form {
            Section {
                LabeledContent("Focus duration") {
                    Stepper(value: Binding(
                        get: { Settings.focusDuration },
                        set: { Settings.focusDuration = $0 }
                    ), in: 5...90, step: 5) {
                        Text("\(Settings.focusDuration) min")
                            .monospacedDigit()
                    }
                }

                LabeledContent("Break duration") {
                    Stepper(value: Binding(
                        get: { Settings.breakDuration },
                        set: { Settings.breakDuration = $0 }
                    ), in: 1...30) {
                        Text("\(Settings.breakDuration) min")
                            .monospacedDigit()
                    }
                }

                LabeledContent("Sessions per cycle") {
                    Stepper(value: Binding(
                        get: { Settings.sessionsPerCycle },
                        set: { Settings.sessionsPerCycle = $0 }
                    ), in: 1...8) {
                        Text("\(Settings.sessionsPerCycle)")
                            .monospacedDigit()
                    }
                }
            } header: {
                Label("Duration", systemImage: "clock")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { Settings.focusAutoStartBreak },
                    set: { Settings.focusAutoStartBreak = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-start break after focus ends")
                        Text("Automatically begin break when the focus session completes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: Binding(
                    get: { Settings.focusAutoStartFocus },
                    set: { Settings.focusAutoStartFocus = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-start focus after break ends")
                        Text("Automatically begin the next focus session after break")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("Automation", systemImage: "arrow.triangle.2.circlepath")
            }

            Section {
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("\(focusManager.thisWeekSessionCount)")
                            .font(.title2.bold())
                        Text("sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Divider().frame(height: 32)
                    VStack(alignment: .leading) {
                        Text(String(format: "%.1f", focusManager.thisWeekHours))
                            .font(.title2.bold())
                        Text("hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("This Week", systemImage: "chart.bar")
            }

            Section {
                if focusManager.completedSessions.isEmpty {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundColor(.secondary)
                        Text("No sessions yet")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(focusManager.completedSessions.reversed()) { session in
                                HStack {
                                    Image(systemName: session.type == .focus ? "brain" : "cup.and.saucer")
                                        .foregroundColor(session.type == .focus ? .purple : .green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.note.isEmpty ? session.type.rawValue.capitalized : session.note)
                                            .font(.caption)
                                        Text("\(Int(session.duration / 60)) min — \(session.date, style: .date)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 150)

                    Button("Clear history", role: .destructive) {
                        focusManager.clearHistory()
                    }
                }
            } header: {
                Label("History (\(focusManager.completedSessions.count))", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    // MARK: - Glimpse Tab

    private var glimpseSettingsTab: some View {
        Form {
            Section {
                LabeledContent("Enable Glimpse") {
                    Button("Open Quick Look Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }
                }

                Picker(selection: Binding(
                    get: { Settings.glimpseDefaultTheme },
                    set: { Settings.glimpseDefaultTheme = $0 }
                )) {
                    Text("GitHub").tag("github")
                    Text("Monokai").tag("monokai")
                    Text("Dracula").tag("dracula")
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default theme")
                        Text("Applied to code preview in Quick Look")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Label("Quick Look Extension", systemImage: "eye")
            }
        }
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
