import AppKit
import QuickLook
import WebKit

/// Quick Look preview extension for code, markdown, CSV, ZIP, and images.
class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        let ext = url.pathExtension.lowercased()
        let fileType = GlimpseFileType.detect(from: ext)

        switch fileType {
        case .sourceCode(let language):
            return try await makeCodePreview(url: url, language: language, request: request)
        case .markdown:
            return try await makeMarkdownPreview(url: url, request: request)
        case .json:
            return try await makeJSONPreview(url: url, request: request)
        case .yaml, .toml, .xml:
            return try await makeCodePreview(url: url, language: ext, request: request)
        case .csv:
            return try await makeCSVPreview(url: url, request: request)
        case .archive:
            return try await makeArchivePreview(url: url, request: request)
        case .image:
            return try await makeImagePreview(url: url, request: request)
        case .unknown:
            return try await makeCodePreview(url: url, language: "plaintext", request: request)
        }
    }

    // MARK: - Code Preview

    private func makeCodePreview(url: URL, language: String, request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lineCount = content.components(separatedBy: .newlines).count
        let escaped = content
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        let theme = UserDefaults.standard.string(forKey: "com.macutils.glimpse.defaultTheme") ?? "github"
        let cssTheme = themeCSS(for: theme)

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { margin: 0; padding: 0; background: \(theme == "github" ? "#fff" : "#282a36"); }
        pre { margin: 0; padding: 16px; overflow-x: auto; font-size: 13px; line-height: 1.5; }
        code { font-family: 'SF Mono', 'Menlo', 'Monaco', monospace; }
        .toolbar { padding: 8px 16px; background: rgba(0,0,0,0.05); border-bottom: 1px solid rgba(0,0,0,0.1); font-family: -apple-system; font-size: 12px; color: #666; display: flex; justify-content: space-between; }
        .badge { background: #0366d6; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; }
        .line-numbers { counter-reset: line; }
        .line-numbers .line::before { counter-increment: line; content: counter(line); display: inline-block; width: 3em; margin-right: 1em; text-align: right; color: #999; }
        \(cssTheme)
        </style>
        </head>
        <body>
        <div class="toolbar">
            <span class="badge">\(language.capitalized)</span>
            <span>\(lineCount) lines</span>
        </div>
        <pre><code class="language-\(language) line-numbers">\(addLineNumbers(escaped))</code></pre>
        </body>
        </html>
        """

        let data = Data(html.utf8)
        return QLPreviewReply(dataOfContentType: .html, contentSize: request.maximumSize) { _ in data }
    }

    // MARK: - Markdown Preview

    private func makeMarkdownPreview(url: URL, request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let content = try String(contentsOf: url, encoding: .utf8)
        let htmlContent = simpleMarkdownToHTML(content)

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 32px; max-width: 800px; line-height: 1.6; color: #24292e; }
        h1 { border-bottom: 1px solid #eaecef; padding-bottom: 8px; }
        h2 { border-bottom: 1px solid #eaecef; padding-bottom: 4px; }
        code { background: #f6f8fa; padding: 2px 6px; border-radius: 3px; font-size: 0.9em; }
        pre { background: #f6f8fa; padding: 16px; border-radius: 6px; overflow-x: auto; }
        pre code { background: none; padding: 0; }
        blockquote { border-left: 4px solid #dfe2e5; margin: 0; padding: 0 16px; color: #6a737d; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #dfe2e5; padding: 8px 12px; text-align: left; }
        th { background: #f6f8fa; }
        a { color: #0366d6; }
        img { max-width: 100%; }
        </style>
        </head>
        <body>\(htmlContent)</body>
        </html>
        """

        let data = Data(html.utf8)
        return QLPreviewReply(dataOfContentType: .html, contentSize: request.maximumSize) { _ in data }
    }

    // MARK: - JSON Preview

    private func makeJSONPreview(url: URL, request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let content = try String(contentsOf: url, encoding: .utf8)
        let printer = JSONPrettyPrinter()

        if let formatted = printer.prettyPrint(content) {
            return try await makeCodePreview(url: url, language: "json", request: request)
        } else {
            let errorHTML = "<html><body><p style='color:red;font-family:monospace;padding:16px;'>Invalid JSON — parse error</p><pre>\(content)</pre></body></html>"
            let data = Data(errorHTML.utf8)
            return QLPreviewReply(dataOfContentType: .html, contentSize: request.maximumSize) { _ in data }
        }
    }

    // MARK: - CSV Preview

    private func makeCSVPreview(url: URL, request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let content = try String(contentsOf: url, encoding: .utf8)
        let parser = CSVParser()
        let rows = parser.parse(content)
        let colCount = parser.columnCount(rows)
        let rowCount = parser.rowCount(rows)

        var tableHTML = "<table>"
        for (i, row) in rows.enumerated() {
            tableHTML += "<tr>"
            for cell in row {
                let tag = i == 0 ? "th" : "td"
                let escaped = cell
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                tableHTML += "<\(tag)>\(escaped)</\(tag)>"
            }
            tableHTML += "</tr>"
        }
        tableHTML += "</table>"

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { font-family: -apple-system; margin: 0; padding: 0; }
        .toolbar { padding: 8px 16px; background: #f6f8fa; border-bottom: 1px solid #e1e4e8; font-size: 12px; color: #586069; }
        .badge { background: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; }
        table { border-collapse: collapse; width: 100%; font-size: 13px; }
        th { background: #f6f8fa; position: sticky; top: 0; font-weight: 600; }
        th, td { border: 1px solid #e1e4e8; padding: 6px 12px; text-align: left; }
        tr:nth-child(even) { background: #f9f9f9; }
        </style>
        </head>
        <body>
        <div class="toolbar">
            <span class="badge">CSV</span>
            &nbsp; \(colCount) columns × \(rowCount) rows
        </div>
        \(tableHTML)
        </body>
        </html>
        """

        let data = Data(html.utf8)
        return QLPreviewReply(dataOfContentType: .html, contentSize: request.maximumSize) { _ in data }
    }

    // MARK: - Archive Preview

    private func makeArchivePreview(url: URL, request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        // List ZIP contents using Process/unzip
        let entries = listArchiveContents(url: url)
        let builder = ZIPTreeBuilder()
        let tree = builder.buildTree(from: entries)
        let fileCount = builder.fileCount(in: entries)
        let totalSize = builder.totalSize(of: entries)

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { font-family: 'SF Mono', monospace; margin: 0; padding: 0; font-size: 13px; }
        .toolbar { padding: 8px 16px; background: #f6f8fa; border-bottom: 1px solid #e1e4e8; font-size: 12px; font-family: -apple-system; }
        .badge { background: #6f42c1; color: white; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; }
        pre { padding: 16px; margin: 0; white-space: pre-wrap; line-height: 1.6; }
        </style>
        </head>
        <body>
        <div class="toolbar">
            <span class="badge">Archive</span>
            &nbsp; \(fileCount) files · \(builder.formatBytes(totalSize))
        </div>
        <pre>\(tree)</pre>
        </body>
        </html>
        """

        let data = Data(html.utf8)
        return QLPreviewReply(dataOfContentType: .html, contentSize: request.maximumSize) { _ in data }
    }

    // MARK: - Image Preview

    private func makeImagePreview(url: URL, request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw NSError(domain: "Glimpse", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read image"])
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs[.size] as? Int64 ?? 0
        let formatter = ByteCountFormatter()
        let sizeStr = formatter.string(fromByteCount: fileSize)

        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]

        var metadataHTML = """
        <div class="meta-item"><span class="label">Dimensions</span><span>\(width) × \(height)</span></div>
        <div class="meta-item"><span class="label">File size</span><span>\(sizeStr)</span></div>
        """

        if let make = tiff?["Make"] as? String { metadataHTML += "<div class='meta-item'><span class='label'>Camera</span><span>\(make)</span></div>" }
        if let model = tiff?["Model"] as? String { metadataHTML += "<div class='meta-item'><span class='label'>Model</span><span>\(model)</span></div>" }
        if let iso = exif?["ISOSpeedRatings"] as? [Int], let isoVal = iso.first { metadataHTML += "<div class='meta-item'><span class='label'>ISO</span><span>\(isoVal)</span></div>" }
        if let exposure = exif?["ExposureTime"] as? Double { metadataHTML += "<div class='meta-item'><span class='label'>Exposure</span><span>1/\(Int(1/exposure))s</span></div>" }
        if let fNumber = exif?["FNumber"] as? Double { metadataHTML += "<div class='meta-item'><span class='label'>Aperture</span><span>f/\(fNumber)</span></div>" }

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { margin: 0; display: flex; height: 100vh; font-family: -apple-system; }
        .image-container { flex: 1; display: flex; align-items: center; justify-content: center; background: #1e1e1e; padding: 16px; }
        .image-container img { max-width: 100%; max-height: 100%; object-fit: contain; }
        .sidebar { width: 200px; padding: 16px; background: #f6f8fa; border-left: 1px solid #e1e4e8; overflow-y: auto; }
        .meta-item { display: flex; justify-content: space-between; padding: 4px 0; font-size: 11px; border-bottom: 1px solid #eee; }
        .label { color: #586069; font-weight: 600; }
        .filename { font-weight: 600; font-size: 13px; margin-bottom: 12px; word-break: break-all; }
        </style>
        </head>
        <body>
        <div class="image-container">
            <img src="\(url.absoluteString)">
        </div>
        <div class="sidebar">
            <div class="filename">\(url.lastPathComponent)</div>
            \(metadataHTML)
        </div>
        </body>
        </html>
        """

        let data = Data(html.utf8)
        return QLPreviewReply(dataOfContentType: .html, contentSize: request.maximumSize) { _ in data }
    }

    // MARK: - Helpers

    private func addLineNumbers(_ code: String) -> String {
        return code.components(separatedBy: "\n").map { "<span class=\"line\">\($0)</span>" }.joined(separator: "\n")
    }

    private func themeCSS(for theme: String) -> String {
        switch theme {
        case "monokai":
            return "body { background: #272822; color: #f8f8f2; } .toolbar { background: #3e3d32; color: #a6a28c; }"
        case "dracula":
            return "body { background: #282a36; color: #f8f8f2; } .toolbar { background: #44475a; color: #6272a4; }"
        default: // github
            return "body { background: #fff; color: #24292e; } .toolbar { background: #f6f8fa; color: #586069; }"
        }
    }

    private func simpleMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown
        // Headers
        html = html.replacingOccurrences(of: "(?m)^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)
        // Bold and italic
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        // Code
        html = html.replacingOccurrences(of: "`(.+?)`", with: "<code>$1</code>", options: .regularExpression)
        // Line breaks
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = "<p>" + html + "</p>"
        return html
    }

    private func listArchiveContents(url: URL) -> [ZIPFileEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo")
        process.arguments = ["-1", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            return output.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .map { path in
                    ZIPFileEntry(
                        path: path,
                        size: 0,
                        isDirectory: path.hasSuffix("/")
                    )
                }
        } catch {
            return []
        }
    }
}
