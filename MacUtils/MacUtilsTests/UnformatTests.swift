import XCTest
@testable import MacUtilsCore

final class UnformatTests: XCTestCase {

    let processor = UnformatProcessor()

    // MARK: - RTF to Plain Text

    func testRichRTFProducesPlainText() {
        // RTF with bold and italic formatting
        let rtfString = #"{\rtf1\ansi{\fonttbl\f0 Helvetica;}\f0\b Hello\b0  \i World\i0}"#
        guard let rtfData = rtfString.data(using: .utf8) else {
            XCTFail("Could not create RTF data"); return
        }

        let result = processor.stripRTF(rtfData)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.trimmingCharacters(in: .whitespacesAndNewlines), "Hello World")
    }

    func testSimpleRTFProducesPlainText() {
        let rtfString = #"{\rtf1\ansi Hello World}"#
        guard let rtfData = rtfString.data(using: .utf8) else {
            XCTFail("Could not create RTF data"); return
        }

        let result = processor.stripRTF(rtfData)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("Hello World") ?? false)
    }

    // MARK: - Plain Text Passthrough

    func testPlainTextInputIsUnchanged() {
        let plainText = "Hello, this is plain text."
        let result = processor.process(plainText: plainText, rtfData: nil, htmlData: nil)
        XCTAssertEqual(result, plainText)
    }

    func testPlainTextWithSpecialCharacters() {
        let plainText = "Special chars: à é ü ñ 日本語 🎉"
        let result = processor.process(plainText: plainText, rtfData: nil, htmlData: nil)
        XCTAssertEqual(result, plainText)
    }

    // MARK: - Empty Pasteboard

    func testNilPlainTextAndNoRichData() {
        let result = processor.process(plainText: nil, rtfData: nil, htmlData: nil)
        XCTAssertNil(result)
    }

    func testEmptyStringPlainText() {
        let result = processor.process(plainText: "", rtfData: nil, htmlData: nil)
        XCTAssertNil(result)
    }

    // MARK: - Rich Formatting Detection

    func testHasRichFormattingWithRTF() {
        let rtfData = Data()
        XCTAssertTrue(processor.hasRichFormatting(rtfData: rtfData, htmlData: nil))
    }

    func testHasRichFormattingWithHTML() {
        let htmlData = Data()
        XCTAssertTrue(processor.hasRichFormatting(rtfData: nil, htmlData: htmlData))
    }

    func testHasNoRichFormatting() {
        XCTAssertFalse(processor.hasRichFormatting(rtfData: nil, htmlData: nil))
    }

    // MARK: - HTML Stripping

    func testHTMLToPlainText() {
        let html = "<html><body><h1>Title</h1><p>Paragraph with <b>bold</b> text.</p></body></html>"
        guard let htmlData = html.data(using: .utf8) else {
            XCTFail("Could not create HTML data"); return
        }

        let result = processor.stripHTML(htmlData)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("Title") ?? false)
        XCTAssertTrue(result?.contains("bold") ?? false)
    }

    // MARK: - Process Priority

    func testProcessPrefersPlainTextOverRTF() {
        let plainText = "Plain version"
        let rtfString = #"{\rtf1\ansi RTF version}"#
        let rtfData = rtfString.data(using: .utf8)

        let result = processor.process(plainText: plainText, rtfData: rtfData, htmlData: nil)
        XCTAssertEqual(result, plainText)
    }

    func testProcessFallsBackToRTFWhenNoPlainText() {
        let rtfString = #"{\rtf1\ansi Fallback text}"#
        guard let rtfData = rtfString.data(using: .utf8) else {
            XCTFail("Could not create RTF data"); return
        }

        let result = processor.process(plainText: nil, rtfData: rtfData, htmlData: nil)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("Fallback text") ?? false)
    }

    // MARK: - Invalid RTF

    func testInvalidRTFDataReturnsNil() {
        let invalidData = "Not RTF at all".data(using: .utf8) ?? Data()
        let result = processor.stripRTF(invalidData)
        XCTAssertNil(result)
    }
}
