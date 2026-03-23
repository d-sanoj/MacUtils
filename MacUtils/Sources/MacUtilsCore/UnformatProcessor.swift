import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Unformat Core Logic

/// Processes pasteboard content to strip rich text formatting.
/// Returns the plain text representation.
public struct UnformatProcessor {

    public init() {}

    #if canImport(AppKit)
    /// Strip RTF data to plain text
    /// - Parameter rtfData: Raw RTF data from the pasteboard
    /// - Returns: Plain text string, or nil if the data cannot be parsed
    public func stripRTF(_ rtfData: Data) -> String? {
        guard let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) else {
            return nil
        }
        return attributedString.string
    }

    /// Strip HTML data to plain text
    /// - Parameter htmlData: Raw HTML data from the pasteboard
    /// - Returns: Plain text string, or nil if the data cannot be parsed
    public func stripHTML(_ htmlData: Data) -> String? {
        guard let attributedString = NSAttributedString(html: htmlData, documentAttributes: nil) else {
            return nil
        }
        return attributedString.string
    }
    #else
    /// Fallback RTF stripper without AppKit — strips RTF control codes manually
    public func stripRTF(_ rtfData: Data) -> String? {
        guard let raw = String(data: rtfData, encoding: .utf8) else { return nil }
        return stripRTFControlCodes(raw)
    }

    /// Fallback HTML stripper without AppKit — strips HTML tags manually
    public func stripHTML(_ htmlData: Data) -> String? {
        guard let raw = String(data: htmlData, encoding: .utf8) else { return nil }
        return stripHTMLTags(raw)
    }

    private func stripRTFControlCodes(_ rtf: String) -> String? {
        // Simple RTF stripper: remove {\rtf1...} wrapper and control words
        var result = ""
        var depth = 0
        var inControl = false
        var controlWord = ""

        for char in rtf {
            if char == "{" {
                depth += 1
                continue
            }
            if char == "}" {
                depth -= 1
                continue
            }
            if char == "\\" {
                inControl = true
                controlWord = ""
                continue
            }
            if inControl {
                if char == " " || char == "\n" {
                    inControl = false
                    // Skip the control word
                    continue
                }
                if char.isLetter || char == "'" {
                    controlWord.append(char)
                    continue
                }
                inControl = false
            }
            if depth >= 1 {
                result.append(char)
            }
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func stripHTMLTags(_ html: String) -> String? {
        var result = ""
        var inTag = false
        for char in html {
            if char == "<" {
                inTag = true
                continue
            }
            if char == ">" {
                inTag = false
                continue
            }
            if !inTag {
                result.append(char)
            }
        }
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    #endif

    /// Process pasteboard content: if it has rich text, return plain text version.
    /// If it's already plain text, return it unchanged.
    /// - Parameters:
    ///   - plainText: Plain text from pasteboard (NSPasteboardType.string)
    ///   - rtfData: RTF data from pasteboard (NSPasteboardType.rtf), if any
    ///   - htmlData: HTML data from pasteboard (NSPasteboardType.html), if any
    /// - Returns: The plain text to write back, or nil if pasteboard was empty
    public func process(plainText: String?, rtfData: Data?, htmlData: Data?) -> String? {
        // If there's plain text, return it (this is the stripped version)
        if let text = plainText, !text.isEmpty {
            return text
        }

        // Try to extract from RTF
        if let rtf = rtfData, let text = stripRTF(rtf), !text.isEmpty {
            return text
        }

        // Try to extract from HTML
        if let html = htmlData, let text = stripHTML(html), !text.isEmpty {
            return text
        }

        return nil
    }

    /// Check if the pasteboard contains rich formatting that would be stripped
    public func hasRichFormatting(rtfData: Data?, htmlData: Data?) -> Bool {
        return rtfData != nil || htmlData != nil
    }
}
