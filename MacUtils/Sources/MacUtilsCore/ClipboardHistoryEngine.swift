import Foundation

// MARK: - CtrlPaste Clipboard History Core Logic

/// Represents a single clipboard history entry
public struct ClipboardEntry: Codable, Equatable, Identifiable {
    public let id: UUID
    public let text: String
    public let timestamp: Date

    public init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }

    /// Relative time description (e.g. "2m ago", "1h ago")
    public var relativeTime: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    /// Truncated text for display (max caractères)
    public func truncated(maxLength: Int = 80) -> String {
        if text.count <= maxLength {
            return text
        }
        let endIndex = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<endIndex]) + "…"
    }
}

/// Core logic for clipboard history management.
/// Handles history cap, deduplication, ordering, and persistence.
public final class ClipboardHistoryEngine {

    /// Maximum number of entries to keep
    public static let maxEntries = 20

    /// Current history, ordered newest first
    public private(set) var entries: [ClipboardEntry] = []

    public init() {}

    /// Initialize with existing entries (e.g. loaded from persistence)
    public init(entries: [ClipboardEntry]) {
        self.entries = Array(entries.prefix(Self.maxEntries))
    }

    /// Add a new clipboard text entry.
    /// - Returns: true if the entry was added, false if it was a duplicate or empty
    @discardableResult
    public func addEntry(_ text: String, timestamp: Date = Date()) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Deduplication: remove existing entry with same text
        entries.removeAll { $0.text == trimmed }

        // Prepend new entry
        let entry = ClipboardEntry(text: trimmed, timestamp: timestamp)
        entries.insert(entry, at: 0)

        // Cap at max entries
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }

        return true
    }

    /// Remove a specific entry by ID
    public func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    /// Clear all history
    public func clearHistory() {
        entries.removeAll()
    }

    /// Get the last N entries for display
    public func recentEntries(count: Int = 5) -> [ClipboardEntry] {
        return Array(entries.prefix(count))
    }

    // MARK: - Persistence

    /// Encode entries to Data for storage
    public func encode() throws -> Data {
        try JSONEncoder().encode(entries)
    }

    /// Decode entries from stored Data
    public func load(from data: Data) throws {
        entries = try JSONDecoder().decode([ClipboardEntry].self, from: data)
    }

    /// Encode to legacy format (separate string and timestamp arrays)
    public func encodeLegacy() -> (strings: [String], timestamps: [Double]) {
        let strings = entries.map { $0.text }
        let timestamps = entries.map { $0.timestamp.timeIntervalSince1970 }
        return (strings, timestamps)
    }

    /// Load from legacy format
    public func loadLegacy(strings: [String], timestamps: [Double]) {
        entries = zip(strings, timestamps).map { text, ts in
            ClipboardEntry(text: text, timestamp: Date(timeIntervalSince1970: ts))
        }
    }
}
