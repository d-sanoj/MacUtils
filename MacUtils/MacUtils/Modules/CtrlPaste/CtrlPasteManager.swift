import Foundation
import AppKit

/// Manages clipboard history with pasteboard polling and deduplication.
final class CtrlPasteManager: ObservableObject {

    @Published var entries: [ClipboardEntryItem] = []

    private var pollTimer: Timer?
    private var lastChangeCount: Int = 0

    struct ClipboardEntryItem: Identifiable, Equatable {
        let id: UUID
        let text: String
        let timestamp: Date

        var relativeTime: String {
            let interval = Date().timeIntervalSince(timestamp)
            if interval < 60 { return "Just now" }
            if interval < 3600 { return "\(Int(interval / 60))m ago" }
            if interval < 86400 { return "\(Int(interval / 3600))h ago" }
            return "\(Int(interval / 86400))d ago"
        }

        func truncated(maxLength: Int = 80) -> String {
            if text.count <= maxLength { return text }
            let endIndex = text.index(text.startIndex, offsetBy: maxLength)
            return String(text[..<endIndex]) + "…"
        }
    }

    static let maxEntries = 20

    init() {
        loadFromDefaults()
        lastChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - Polling

    func startPolling() {
        guard Settings.ctrlPasteEnabled else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkPasteboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Skip concealed (password manager) content
        let types = NSPasteboard.general.types ?? []
        if types.contains(NSPasteboard.PasteboardType(rawValue: "org.nspasteboard.ConcealedType")) {
            return
        }

        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        addEntry(text)
    }

    // MARK: - History Management

    @discardableResult
    func addEntry(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Deduplication
        entries.removeAll { $0.text == trimmed }

        let entry = ClipboardEntryItem(id: UUID(), text: trimmed, timestamp: Date())
        entries.insert(entry, at: 0)

        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }

        saveToDefaults()
        return true
    }

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveToDefaults()
    }

    func clearHistory() {
        entries.removeAll()
        saveToDefaults()
    }

    var recentEntries: [ClipboardEntryItem] {
        Array(entries.prefix(5))
    }

    // MARK: - Persistence

    private func saveToDefaults() {
        Settings.ctrlPasteHistory = entries.map { $0.text }
        Settings.ctrlPasteTimestamps = entries.map { $0.timestamp.timeIntervalSince1970 }
    }

    private func loadFromDefaults() {
        let strings = Settings.ctrlPasteHistory
        let timestamps = Settings.ctrlPasteTimestamps

        entries = zip(strings, timestamps).map { text, ts in
            ClipboardEntryItem(id: UUID(), text: text, timestamp: Date(timeIntervalSince1970: ts))
        }
    }
}
