import SwiftUI
import AppKit
import MacUtilsCore

/// Settings window with macOS System Settings-style sidebar navigation.
struct SettingsView: View {
    @ObservedObject var focusManager: FocusManager
    @ObservedObject var ctrlPasteManager: CtrlPasteManager
    @ObservedObject var unformatManager: UnformatManager
    @ObservedObject var scanManager: ScanManager
    @ObservedObject var lumensManager: LumensManager

    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case lumens = "Lumens"
        case unformat = "Unformat"
        case ctrlPaste = "CtrlPaste"
        case scan = "Scan"
        case focus = "Focus"
        case permissions = "Permissions"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .lumens: return "sun.max"
            case .unformat: return "doc.plaintext"
            case .ctrlPaste: return "doc.on.clipboard"
            case .scan: return "text.viewfinder"
            case .focus: return "timer"
            case .permissions: return "lock.shield"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
        } detail: {
            VStack(spacing: 0) {
                // Header bar
                HStack(spacing: 10) {
                    Image(systemName: selectedTab.icon)
                        .font(.title3)
                        .foregroundColor(.primary)
                    Text(selectedTab.rawValue)
                        .font(.title3.bold())
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Scrollable content
                ScrollView {
                    detailContent
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(width: 680, height: 480)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .general: generalTab
        case .lumens: lumensSettingsTab
        case .unformat: unformatSettingsTab
        case .ctrlPaste: ctrlPasteSettingsTab
        case .scan: scanSettingsTab
        case .focus: focusSettingsTab
        case .permissions: permissionsSettingsTab
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {

            settingsSection(title: "Startup") {
                settingsToggle("Launch at login", isOn: Binding(
                    get: { Settings.launchAtLogin },
                    set: { Settings.launchAtLogin = $0 }
                ))

                settingsRow {
                    Toggle(isOn: .constant(true)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Mac Utils in menu bar")
                            Text("Always visible for quick access")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(true)
                }
            }

            settingsSection(title: "About") {
                settingsRow {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
                settingsRow {
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
                settingsRow {
                    Link("GitHub Repository", destination: URL(string: "https://github.com/d-sanoj/MacUtils")!)
                }
            }
        }
    }

    // MARK: - Lumens Tab

    private var lumensSettingsTab: some View {
        VStack(alignment: .leading, spacing: 20) {

            settingsSection(title: "Detected Monitors") {
                if lumensManager.monitors.isEmpty {
                    settingsRow {
                        HStack {
                            Image(systemName: "display.trianglebadge.exclamationmark")
                                .foregroundColor(.secondary)
                            Text("No external monitors detected")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    ForEach(lumensManager.monitors) { monitor in
                        settingsRow {
                            HStack {
                                Image(systemName: "display")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(monitor.name)
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
                }
            }
        }
    }

    // MARK: - Unformat Tab

    private var unformatSettingsTab: some View {
        VStack(alignment: .leading, spacing: 20) {

            settingsSection(title: "Paste Stripping") {
                settingsToggle("Enable Unformat", isOn: $unformatManager.isEnabled)

                settingsRow {
                    Toggle(isOn: Binding(
                        get: { Settings.unformatShowNotification },
                        set: { Settings.unformatShowNotification = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show notification")
                            Text("Display a notification when formatting is stripped")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - CtrlPaste Tab

    private var ctrlPasteSettingsTab: some View {
        VStack(alignment: .leading, spacing: 20) {

            settingsSection(title: "Clipboard History") {
                settingsToggle("Enable CtrlPaste", isOn: Binding(
                    get: { Settings.ctrlPasteEnabled },
                    set: { Settings.ctrlPasteEnabled = $0 }
                ))

                if !ctrlPasteManager.entries.isEmpty {
                    settingsRow {
                        Button("Clear all history", role: .destructive) {
                            ctrlPasteManager.clearHistory()
                        }
                    }
                }
            }

            if !ctrlPasteManager.entries.isEmpty {
                settingsSection(title: "History (\(ctrlPasteManager.entries.count) entries)") {
                    ForEach(ctrlPasteManager.entries.prefix(10)) { entry in
                        settingsRow {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.truncated(maxLength: 50))
                                        .font(.callout)
                                        .lineLimit(1)
                                    Text(entry.relativeTime)
                                        .font(.caption)
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
            }
        }
    }

    // MARK: - Scan Tab

    private var scanSettingsTab: some View {
        VStack(alignment: .leading, spacing: 20) {

            settingsSection(title: "Text Capture") {
                settingsToggle("Enable Scan", isOn: Binding(
                    get: { Settings.scanEnabled },
                    set: { Settings.scanEnabled = $0 }
                ))

                settingsRow {
                    HStack {
                        Text("Keyboard shortcut")
                        Spacer()
                        Text(Settings.scanShortcut)
                            .font(.callout.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }

                settingsRow {
                    Toggle(isOn: Binding(
                        get: { Settings.scanAutoAddToCtrlPaste },
                        set: { Settings.scanAutoAddToCtrlPaste = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-add to CtrlPaste history")
                            Text("Captured text is saved to clipboard history")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                settingsToggle("Show character count HUD", isOn: Binding(
                    get: { Settings.scanShowHUD },
                    set: { Settings.scanShowHUD = $0 }
                ))
            }
        }
    }

    // MARK: - Focus Tab

    private var focusSettingsTab: some View {
        VStack(alignment: .leading, spacing: 20) {

            settingsSection(title: "Duration") {
                settingsRow {
                    HStack {
                        Text("Focus duration")
                        Spacer()
                        Stepper(value: Binding(
                            get: { Settings.focusDuration },
                            set: {
                                Settings.focusDuration = $0
                                focusManager.objectWillChange.send()
                            }
                        ), in: 5...90, step: 5) {
                            Text("\(Settings.focusDuration) min")
                                .monospacedDigit()
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }

                settingsRow {
                    HStack {
                        Text("Break duration")
                        Spacer()
                        Stepper(value: Binding(
                            get: { Settings.breakDuration },
                            set: {
                                Settings.breakDuration = $0
                                focusManager.objectWillChange.send()
                            }
                        ), in: 1...30) {
                            Text("\(Settings.breakDuration) min")
                                .monospacedDigit()
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }

                settingsRow {
                    HStack {
                        Text("Sessions per cycle")
                        Spacer()
                        Stepper(value: Binding(
                            get: { Settings.sessionsPerCycle },
                            set: {
                                Settings.sessionsPerCycle = $0
                                focusManager.objectWillChange.send()
                            }
                        ), in: 1...8) {
                            Text("\(Settings.sessionsPerCycle)")
                                .monospacedDigit()
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }

            settingsSection(title: "Automation") {
                settingsRow {
                    Toggle(isOn: Binding(
                        get: { Settings.focusAutoStartBreak },
                        set: { Settings.focusAutoStartBreak = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-start break after focus")
                            Text("Automatically begin break when focus completes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                settingsRow {
                    Toggle(isOn: Binding(
                        get: { Settings.focusAutoStartFocus },
                        set: { Settings.focusAutoStartFocus = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-start focus after break")
                            Text("Automatically begin next focus session")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            settingsSection(title: "This Week") {
                settingsRow {
                    HStack(spacing: 24) {
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
                }
            }

            if !focusManager.completedSessions.isEmpty {
                settingsSection(title: "History (\(focusManager.completedSessions.count))") {
                    ForEach(focusManager.completedSessions.suffix(10).reversed()) { session in
                        settingsRow {
                            HStack {
                                Image(systemName: session.type == .focus ? "brain" : "cup.and.saucer")
                                    .foregroundColor(session.type == .focus ? .purple : .green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.note.isEmpty ? session.type.rawValue.capitalized : session.note)
                                        .font(.callout)
                                    Text("\(Int(session.duration / 60)) min — \(session.date, style: .date)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    settingsRow {
                        Button("Clear history", role: .destructive) {
                            focusManager.clearHistory()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Permissions Tab

    private var permissionsSettingsTab: some View {
        VStack(alignment: .leading, spacing: 20) {

            settingsSection(title: "Required Permissions") {
                settingsRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility")
                            Text("Required for hotkeys, clipboard, and paste stripping")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if AXIsProcessTrusted() {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button("Grant") {
                                let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
                                AXIsProcessTrustedWithOptions(options)
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }

                settingsRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Recording")
                            Text("Required for Scan OCR text capture")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            settingsSection(title: "Extensions") {
                settingsRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Glimpse Quick Look")
                            Text("Enable in System Settings → Extensions → Quick Look")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - Reusable Components


    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Divider().padding(.leading, 16)
        }
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        settingsRow {
            Toggle(title, isOn: isOn)
        }
    }
}
