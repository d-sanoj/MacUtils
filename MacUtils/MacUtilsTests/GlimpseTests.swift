import XCTest
@testable import MacUtilsCore

final class GlimpseTests: XCTestCase {

    // MARK: - File Type Detection by Extension

    func testSwiftDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "swift"), .sourceCode(language: "swift"))
    }

    func testPythonDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "py"), .sourceCode(language: "python"))
    }

    func testJavaScriptDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "js"), .sourceCode(language: "javascript"))
    }

    func testTypeScriptDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "ts"), .sourceCode(language: "typescript"))
    }

    func testHTMLDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "html"), .sourceCode(language: "html"))
        XCTAssertEqual(GlimpseFileType.detect(from: "htm"), .sourceCode(language: "html"))
    }

    func testJSONDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "json"), .json)
    }

    func testYAMLDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "yaml"), .yaml)
        XCTAssertEqual(GlimpseFileType.detect(from: "yml"), .yaml)
    }

    func testMarkdownDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "md"), .markdown)
        XCTAssertEqual(GlimpseFileType.detect(from: "markdown"), .markdown)
    }

    func testCSVDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "csv"), .csv)
    }

    func testArchiveDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "zip"), .archive)
        XCTAssertEqual(GlimpseFileType.detect(from: "tar"), .archive)
        XCTAssertEqual(GlimpseFileType.detect(from: "gz"), .archive)
    }

    func testImageDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "jpg"), .image)
        XCTAssertEqual(GlimpseFileType.detect(from: "jpeg"), .image)
        XCTAssertEqual(GlimpseFileType.detect(from: "png"), .image)
        XCTAssertEqual(GlimpseFileType.detect(from: "heic"), .image)
        XCTAssertEqual(GlimpseFileType.detect(from: "webp"), .image)
    }

    func testUnknownExtension() {
        XCTAssertEqual(GlimpseFileType.detect(from: "xyz"), .unknown)
    }

    func testCaseInsensitiveDetection() {
        XCTAssertEqual(GlimpseFileType.detect(from: "SWIFT"), .sourceCode(language: "swift"))
        XCTAssertEqual(GlimpseFileType.detect(from: "JSON"), .json)
        XCTAssertEqual(GlimpseFileType.detect(from: "Csv"), .csv)
    }

    func testBadgeNames() {
        XCTAssertEqual(GlimpseFileType.json.badgeName, "JSON")
        XCTAssertEqual(GlimpseFileType.csv.badgeName, "CSV")
        XCTAssertEqual(GlimpseFileType.markdown.badgeName, "Markdown")
        XCTAssertEqual(GlimpseFileType.sourceCode(language: "swift").badgeName, "Swift")
    }

    // MARK: - CSV Parser

    func testCSVSimpleParsing() {
        let parser = CSVParser()
        let csv = "Name,Age,City\nAlice,30,NYC\nBob,25,LA"
        let rows = parser.parse(csv)

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], ["Name", "Age", "City"])
        XCTAssertEqual(rows[1], ["Alice", "30", "NYC"])
        XCTAssertEqual(rows[2], ["Bob", "25", "LA"])
    }

    func testCSVQuotedFields() {
        let parser = CSVParser()
        let csv = #"Name,Description"#  + "\n" + #""Alice","She said ""hello"""# + "\n"
        let rows = parser.parse(csv)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1][0], "Alice")
        XCTAssertEqual(rows[1][1], "She said \"hello\"")
    }

    func testCSVCommasInValues() {
        let parser = CSVParser()
        let csv = "Name,Address\n\"Doe, John\",\"123 Main St, Apt 4\""
        let rows = parser.parse(csv)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1][0], "Doe, John")
        XCTAssertEqual(rows[1][1], "123 Main St, Apt 4")
    }

    func testCSVEmptyInput() {
        let parser = CSVParser()
        let rows = parser.parse("")
        XCTAssertEqual(rows.count, 0)
    }

    func testCSVColumnCount() {
        let parser = CSVParser()
        let csv = "A,B,C\n1,2,3"
        let rows = parser.parse(csv)
        XCTAssertEqual(parser.columnCount(rows), 3)
    }

    func testCSVRowCount() {
        let parser = CSVParser()
        let csv = "Header\nRow1\nRow2\nRow3"
        let rows = parser.parse(csv)
        XCTAssertEqual(parser.rowCount(rows, hasHeader: true), 3)
        XCTAssertEqual(parser.rowCount(rows, hasHeader: false), 4)
    }

    // MARK: - JSON Pretty Printer

    func testJSONPrettyPrintOutput() {
        let printer = JSONPrettyPrinter()
        let input = #"{"name":"Alice","age":30}"#
        guard let output = printer.prettyPrint(input) else {
            XCTFail("Pretty print returned nil"); return
        }

        // Verify indentation exists
        XCTAssertTrue(output.contains("\n"))
        XCTAssertTrue(output.contains("  "))  // Indented
        XCTAssertTrue(output.contains("\"name\""))
        XCTAssertTrue(output.contains("\"Alice\""))
        XCTAssertTrue(output.contains("30"))
    }

    func testJSONPrettyPrintNestedObject() {
        let printer = JSONPrettyPrinter()
        let input = #"{"user":{"name":"Bob","scores":[1,2,3]}}"#
        guard let output = printer.prettyPrint(input) else {
            XCTFail("Pretty print returned nil"); return
        }

        XCTAssertTrue(output.contains("\"user\""))
        XCTAssertTrue(output.contains("\"scores\""))
    }

    func testJSONPrettyPrintInvalidInput() {
        let printer = JSONPrettyPrinter()
        let result = printer.prettyPrint("not json {{{")
        XCTAssertNil(result)
    }

    func testJSONPrettyPrintArray() {
        let printer = JSONPrettyPrinter()
        let input = "[1,2,3]"
        let output = printer.prettyPrint(input)
        XCTAssertNotNil(output)
        XCTAssertTrue(output?.contains("1") ?? false)
    }

    // MARK: - ZIP Tree Builder

    func testZIPTreeBuildsCorrectly() {
        let builder = ZIPTreeBuilder()
        let entries = [
            ZIPFileEntry(path: "src/main.swift", size: 1024, isDirectory: false),
            ZIPFileEntry(path: "src", size: 0, isDirectory: true),
            ZIPFileEntry(path: "README.md", size: 512, isDirectory: false),
        ]

        let tree = builder.buildTree(from: entries)
        XCTAssertTrue(tree.contains("README.md"))
        XCTAssertTrue(tree.contains("main.swift"))
        XCTAssertTrue(tree.contains("📁"))
        XCTAssertTrue(tree.contains("📄"))
    }

    func testZIPTreeEmptyArchive() {
        let builder = ZIPTreeBuilder()
        let tree = builder.buildTree(from: [])
        XCTAssertEqual(tree, "(empty archive)")
    }

    func testZIPTreeFileCount() {
        let builder = ZIPTreeBuilder()
        let entries = [
            ZIPFileEntry(path: "dir", size: 0, isDirectory: true),
            ZIPFileEntry(path: "dir/file1.txt", size: 100, isDirectory: false),
            ZIPFileEntry(path: "dir/file2.txt", size: 200, isDirectory: false),
        ]

        XCTAssertEqual(builder.fileCount(in: entries), 2)
    }

    func testZIPTreeTotalSize() {
        let builder = ZIPTreeBuilder()
        let entries = [
            ZIPFileEntry(path: "a.txt", size: 100, isDirectory: false),
            ZIPFileEntry(path: "b.txt", size: 200, isDirectory: false),
        ]

        XCTAssertEqual(builder.totalSize(of: entries), 300)
    }

    func testFormatBytes() {
        let builder = ZIPTreeBuilder()
        XCTAssertEqual(builder.formatBytes(500), "500 B")
        XCTAssertEqual(builder.formatBytes(1024), "1.0 KB")
        XCTAssertEqual(builder.formatBytes(1536), "1.5 KB")
        XCTAssertEqual(builder.formatBytes(1048576), "1.0 MB")
    }
}
