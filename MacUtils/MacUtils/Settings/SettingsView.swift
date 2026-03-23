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
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
            lumensSettingsTab.tabItem { Label("Lumens", systemImage: "sun.max") }
            unformatSettingsTab.tabItem { Label("Unformat", systemImage: "doc.plaintext") }
            ctrlPasteSettingsTab.tabItem { Label("CtrlPaste", systemImage: "doc.on.clipboard") }
            scanSettingsTab.tabItem { Label("Scan", systemImage: "text.viewfinder") }
            focusSettingsTab.tabItem { Label("Focus", systemImage: "timer") }
            glimpseSettingsTab.tabItem { Label("Glimpse", systemImage: "eye") }
        }
        .formStyle(.grouped)
        .frame(width: 650, height: 480)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { Settings.launchAtLogin },
                    set: { newValue in
                        Settings.launchAtLogin = newValue
                    }
                ))

                Toggle(isOn: .constant(true)) {
                    VStack(alignment: .leading) {
                        Text("Show Mac Utils in menu bar")
                        Text("(always on)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(true)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
            }
        }
    }

    // MARK: - Lumens Tab

    private var lumensSettingsTab: some View {
        Form {
            Section("Hotkey Mapping") {
                Toggle("Map F1/F2 to brightness", isOn: Binding(
                    get: { Settings.lumensMapBrightness },
                    set: { Settings.lumensMapBrightness = $0 }
                ))
                Toggle("Map F10/F11/F12 to volume", isOn: Binding(
                    get: { Settings.lumensMapVolume },
                    set: { Settings.lumensMapVolume = $0 }
                ))
            }

            Section("Detected Monitors") {
                if lumensManager.monitors.isEmpty {
                    Text("No external monitors detected")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(lumensManager.monitors) { monitor in
                        LabeledContent(monitor.name, value: monitor.supportsDDC ? "DDC OK" : "No DDC")
                    }
                }
            }
        }
    }

    // MARK: - Unformat Tab

    private var unformatSettingsTab: some View {
        Form {
            Section("Paste Stripping") {
                Toggle("Enable Unformat", isOn: $unformatManager.isEnabled)
                Toggle("Show notification when formatting is stripped", isOn: Binding(
                    get: { Settings.unformatShowNotification },
                    set: { Settings.unformatShowNotification = $0 }
                ))
            }
        }
    }

    // MARK: - CtrlPaste Tab

    private var ctrlPasteSettingsTab: some View {
        Form {
            Section("Clipboard History") {
                Toggle("Enable CtrlPaste", isOn: Binding(
                    get: { Settings.ctrlPasteEnabled },
                    set: { Settings.ctrlPasteEnabled = $0 }
                ))

                Button("Clear history", role: .destructive) {
                    ctrlPasteManager.clearHistory()
                }
            }

            Section("History (\(ctrlPasteManager.entries.count) entries)") {
                if ctrlPasteManager.entries.isEmpty {
                    Text("No history")
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(ctrlPasteManager.entries) { entry in
                                HStack {
                                    VStack(alignment: .leading) {
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
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
    }

    // MARK: - Scan Tab

    private var scanSettingsTab: some View {
        Form {
            Section("Text Capture") {
                Toggle("Enable Scan", isOn: Binding(
                    get: { Settings.scanEnabled },
                    set: { Settings.scanEnabled = $0 }
                ))

                LabeledContent("Keyboard shortcut", value: Settings.scanShortcut)

                Toggle("Auto-add to CtrlPaste history", isOn: Binding(
                    get: { Settings.scanAutoAddToCtrlPaste },
                    set: { Settings.scanAutoAddToCtrlPaste = $0 }
                ))

                Toggle("Show character count HUD after capture", isOn: Binding(
                    get: { Settings.scanShowHUD },
                    set: { Settings.scanShowHUD = $0 }
                ))
            }
        }
    }

    // MARK: - Focus Tab

    private var focusSettingsTab: some View {
        Form {
            Section("Duration") {
                LabeledContent("Focus duration") {
                    Stepper(value: Binding(
                        get: { Settings.focusDuration },
                        set: { Settings.focusDuration = $0 }
                    ), in: 5...90, step: 5) {
                        Text("\(Settings.focusDuration) min")
                    }
                }

                LabeledContent("Break duration") {
                    Stepper(value: Binding(
                        get: { Settings.breakDuration },
                        set: { Settings.breakDuration = $0 }
                    ), in: 1...30) {
                        Text("\(Settings.breakDuration) min")
                    }
                }

                LabeledContent("Sessions per cycle") {
                    Stepper(value: Binding(
                        get: { Settings.sessionsPerCycle },
                        set: { Settings.sessionsPerCycle = $0 }
                    ), in: 1...8) {
                        Text("\(Settings.sessionsPerCycle)")
                    }
                }
            }

            Section("Automation") {
                Toggle("Auto-start break after focus ends", isOn: Binding(
                    get: { Settings.focusAutoStartBreak },
                    set: { Settings.focusAutoStartBreak = $0 }
                ))
                Toggle("Auto-start focus after break ends", isOn: Binding(
                    get: { Settings.focusAutoStartFocus },
                    set: { Settings.focusAutoStartFocus = $0 }
                ))
            }

            Section("Stats") {
                LabeledContent("This week", value: "\(focusManager.thisWeekSessionCount) sessions · \(String(format: "%.1f", focusManager.thisWeekHours)) hours")
            }

            Section("History (\(focusManager.completedSessions.count) sessions)") {
                if focusManager.completedSessions.isEmpty {
                    Text("No sessions yet")
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(focusManager.completedSessions.reversed()) { session in
                                HStack {
                                    Image(systemName: session.type == .focus ? "brain" : "cup.and.saucer")
                                        .foregroundColor(session.type == .focus ? .purple : .green)
                                    VStack(alignment: .leading) {
                                        Text(session.note.isEmpty ? session.type.rawValue.capitalized : session.note)
                                            .font(.caption)
                                        Text("\(Int(session.duration / 60)) min — \(session.date, style: .date)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)

                    Button("Clear history", role: .destructive) {
                        focusManager.clearHistory()
                    }
                }
            }
        }
    }

    // MARK: - Glimpse Tab

    private var glimpseSettingsTab: some View {
        Form {
            Section("Quick Look Extension") {
                LabeledContent("Enable Glimpse") {
                    Button("Open Quick Look Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }
                }

                Picker("Default theme", selection: Binding(
                    get: { Settings.glimpseDefaultTheme },
                    set: { Settings.glimpseDefaultTheme = $0 }
                )) {
                    Text("GitHub").tag("github")
                    Text("Monokai").tag("monokai")
                    Text("Dracula").tag("dracula")
                }
                .pickerStyle(.segmented)
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
