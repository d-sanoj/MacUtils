import Foundation

// MARK: - Glimpse File Type Detection & Parsing Core

/// Supported file types for Glimpse Quick Look extension
public enum GlimpseFileType: Equatable {
    case sourceCode(language: String)
    case markdown
    case json
    case yaml
    case toml
    case xml
    case csv
    case archive
    case image
    case unknown

    /// Detect file type from file extension
    public static func detect(from extension: String) -> GlimpseFileType {
        let ext = `extension`.lowercased()
        switch ext {
        // Source code
        case "swift": return .sourceCode(language: "swift")
        case "py": return .sourceCode(language: "python")
        case "js": return .sourceCode(language: "javascript")
        case "ts": return .sourceCode(language: "typescript")
        case "jsx": return .sourceCode(language: "javascript")
        case "tsx": return .sourceCode(language: "typescript")
        case "html", "htm": return .sourceCode(language: "html")
        case "css": return .sourceCode(language: "css")
        case "sh", "bash", "zsh": return .sourceCode(language: "bash")
        case "rb": return .sourceCode(language: "ruby")
        case "go": return .sourceCode(language: "go")
        case "rs": return .sourceCode(language: "rust")
        case "kt": return .sourceCode(language: "kotlin")
        case "java": return .sourceCode(language: "java")
        case "c": return .sourceCode(language: "c")
        case "cpp", "cc", "cxx": return .sourceCode(language: "cpp")
        case "h", "hpp": return .sourceCode(language: "c")
        case "m": return .sourceCode(language: "objectivec")
        case "sql": return .sourceCode(language: "sql")
        case "r": return .sourceCode(language: "r")

        // Structured data
        case "json": return .json
        case "yaml", "yml": return .yaml
        case "toml": return .toml
        case "xml": return .xml
        case "md", "markdown": return .markdown
        case "csv", "tsv": return .csv

        // Archives
        case "zip", "tar", "gz", "tgz", "tar.gz": return .archive

        // Images
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "bmp", "tiff", "tif":
            return .image

        default: return .unknown
        }
    }

    /// Display name for the file type badge
    public var badgeName: String {
        switch self {
        case .sourceCode(let language):
            return language.capitalized
        case .markdown: return "Markdown"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .toml: return "TOML"
        case .xml: return "XML"
        case .csv: return "CSV"
        case .archive: return "Archive"
        case .image: return "Image"
        case .unknown: return "File"
        }
    }
}

// MARK: - CSV Parser

/// Simple CSV parser that handles quoted fields and commas in values
public struct CSVParser {

    public init() {}

    /// Parse a CSV string into a 2D array of strings
    /// Handles quoted fields, escaped quotes (""), and newlines in quoted fields.
    public func parse(_ input: String) -> [[String]] {
        guard !input.isEmpty else { return [] }

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var index = input.startIndex

        while index < input.endIndex {
            let char = input[index]

            if inQuotes {
                if char == "\"" {
                    let nextIndex = input.index(after: index)
                    if nextIndex < input.endIndex && input[nextIndex] == "\"" {
                        // Escaped quote
                        currentField.append("\"")
                        index = input.index(after: nextIndex)
                        continue
                    } else {
                        // End of quoted field
                        inQuotes = false
                        index = input.index(after: index)
                        continue
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" && currentField.isEmpty {
                    inQuotes = true
                } else if char == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if char == "\n" || char == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.isEmpty {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    // Handle \r\n
                    if char == "\r" {
                        let nextIndex = input.index(after: index)
                        if nextIndex < input.endIndex && input[nextIndex] == "\n" {
                            index = input.index(after: nextIndex)
                            continue
                        }
                    }
                } else {
                    currentField.append(char)
                }
            }

            index = input.index(after: index)
        }

        // Don't forget the last field and row
        currentRow.append(currentField)
        if !currentRow.isEmpty && !(currentRow.count == 1 && currentRow[0].isEmpty) {
            rows.append(currentRow)
        }

        return rows
    }

    /// Get column count from parsed CSV
    public func columnCount(_ rows: [[String]]) -> Int {
        return rows.first?.count ?? 0
    }

    /// Get row count (excluding header if present)
    public func rowCount(_ rows: [[String]], hasHeader: Bool = true) -> Int {
        let count = rows.count
        return hasHeader ? max(0, count - 1) : count
    }
}

// MARK: - JSON Pretty Printer

/// Pretty-prints JSON with proper indentation
public struct JSONPrettyPrinter {

    public let indentSize: Int

    public init(indentSize: Int = 2) {
        self.indentSize = indentSize
    }

    /// Pretty-print a JSON string
    /// - Parameter input: Raw JSON string
    /// - Returns: Formatted JSON string, or nil if input is invalid JSON
    public func prettyPrint(_ input: String) -> String? {
        guard let data = input.data(using: .utf8) else { return nil }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            let prettyData = try JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys]
            )
            return String(data: prettyData, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// MARK: - ZIP File Tree

/// Represents a file entry in a ZIP archive
public struct ZIPFileEntry: Equatable {
    public let path: String
    public let size: UInt64
    public let isDirectory: Bool

    public init(path: String, size: UInt64, isDirectory: Bool) {
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
    }
}

/// Builds a text tree representation of ZIP contents
public struct ZIPTreeBuilder {

    public init() {}

    /// Build an indented tree string from a list of file entries
    public func buildTree(from entries: [ZIPFileEntry]) -> String {
        guard !entries.isEmpty else { return "(empty archive)" }

        var lines: [String] = []
        let sorted = entries.sorted { $0.path < $1.path }

        for entry in sorted {
            let components = entry.path.split(separator: "/")
            let depth = components.count - 1
            let indent = String(repeating: "  ", count: depth)
            let name = String(components.last ?? "")

            if entry.isDirectory {
                lines.append("\(indent)📁 \(name)/")
            } else {
                let sizeStr = formatBytes(entry.size)
                lines.append("\(indent)📄 \(name) (\(sizeStr))")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Format byte count to human-readable string
    public func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    /// Calculate total uncompressed size
    public func totalSize(of entries: [ZIPFileEntry]) -> UInt64 {
        return entries.reduce(0) { $0 + $1.size }
    }

    /// Count total files (non-directories)
    public func fileCount(in entries: [ZIPFileEntry]) -> Int {
        return entries.filter { !$0.isDirectory }.count
    }
}
