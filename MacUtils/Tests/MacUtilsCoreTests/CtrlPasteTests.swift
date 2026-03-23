import XCTest
@testable import MacUtilsCore

final class CtrlPasteTests: XCTestCase {

    var engine: ClipboardHistoryEngine!

    override func setUp() {
        super.setUp()
        engine = ClipboardHistoryEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - History Cap

    func testHistoryCapsAt20Items() {
        for i in 1...25 {
            engine.addEntry("Entry \(i)")
        }
        XCTAssertEqual(engine.entries.count, 20)
    }

    func testCapRemovesOldestEntries() {
        for i in 1...25 {
            engine.addEntry("Entry \(i)")
        }
        // Newest should be Entry 25, oldest in list should be Entry 6
        XCTAssertEqual(engine.entries.first?.text, "Entry 25")
        XCTAssertEqual(engine.entries.last?.text, "Entry 6")
    }

    // MARK: - Deduplication

    func testDuplicateStringDoesNotCreateDuplicate() {
        engine.addEntry("Hello World")
        engine.addEntry("Other text")
        engine.addEntry("Hello World")  // Duplicate

        XCTAssertEqual(engine.entries.count, 2)
        XCTAssertEqual(engine.entries[0].text, "Hello World")  // Most recent
        XCTAssertEqual(engine.entries[1].text, "Other text")
    }

    func testDuplicateMovesToFront() {
        engine.addEntry("First")
        engine.addEntry("Second")
        engine.addEntry("Third")
        engine.addEntry("First")  // Re-add "First"

        XCTAssertEqual(engine.entries.count, 3)
        XCTAssertEqual(engine.entries[0].text, "First")
        XCTAssertEqual(engine.entries[1].text, "Third")
        XCTAssertEqual(engine.entries[2].text, "Second")
    }

    // MARK: - Empty/Whitespace Handling

    func testEmptyStringIsRejected() {
        let added = engine.addEntry("")
        XCTAssertFalse(added)
        XCTAssertEqual(engine.entries.count, 0)
    }

    func testWhitespaceOnlyStringIsRejected() {
        let added = engine.addEntry("   \n\t  ")
        XCTAssertFalse(added)
        XCTAssertEqual(engine.entries.count, 0)
    }

    func testStringsAreTrimmed() {
        engine.addEntry("  Hello  ")
        XCTAssertEqual(engine.entries[0].text, "Hello")
    }

    // MARK: - Timestamp Ordering

    func testEntriesAreOrderedNewestFirst() {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let date3 = Date(timeIntervalSince1970: 3000)

        engine.addEntry("First", timestamp: date1)
        engine.addEntry("Second", timestamp: date2)
        engine.addEntry("Third", timestamp: date3)

        XCTAssertEqual(engine.entries[0].text, "Third")
        XCTAssertEqual(engine.entries[1].text, "Second")
        XCTAssertEqual(engine.entries[2].text, "First")
    }

    // MARK: - Persistence Encode/Decode Round Trip

    func testEncodeDecodeRoundTrip() throws {
        engine.addEntry("Alpha")
        engine.addEntry("Beta")
        engine.addEntry("Gamma")

        let data = try engine.encode()

        let newEngine = ClipboardHistoryEngine()
        try newEngine.load(from: data)

        XCTAssertEqual(newEngine.entries.count, 3)
        XCTAssertEqual(newEngine.entries[0].text, "Gamma")
        XCTAssertEqual(newEngine.entries[1].text, "Beta")
        XCTAssertEqual(newEngine.entries[2].text, "Alpha")
    }

    func testLegacyEncodeDecodeRoundTrip() {
        engine.addEntry("One")
        engine.addEntry("Two")

        let legacy = engine.encodeLegacy()

        let newEngine = ClipboardHistoryEngine()
        newEngine.loadLegacy(strings: legacy.strings, timestamps: legacy.timestamps)

        XCTAssertEqual(newEngine.entries.count, 2)
        XCTAssertEqual(newEngine.entries[0].text, "Two")
        XCTAssertEqual(newEngine.entries[1].text, "One")
    }

    // MARK: - Recent Entries

    func testRecentEntriesDefaultsFive() {
        for i in 1...10 {
            engine.addEntry("Entry \(i)")
        }
        let recent = engine.recentEntries()
        XCTAssertEqual(recent.count, 5)
        XCTAssertEqual(recent[0].text, "Entry 10")
    }

    func testRecentEntriesCustomCount() {
        for i in 1...10 {
            engine.addEntry("Entry \(i)")
        }
        let recent = engine.recentEntries(count: 3)
        XCTAssertEqual(recent.count, 3)
    }

    // MARK: - Remove and Clear

    func testRemoveEntry() {
        engine.addEntry("Keep")
        engine.addEntry("Remove")

        let id = engine.entries[0].id
        engine.removeEntry(id: id)

        XCTAssertEqual(engine.entries.count, 1)
        XCTAssertEqual(engine.entries[0].text, "Keep")
    }

    func testClearHistory() {
        engine.addEntry("A")
        engine.addEntry("B")
        engine.clearHistory()
        XCTAssertEqual(engine.entries.count, 0)
    }

    // MARK: - Relative Time

    func testRelativeTimeJustNow() {
        let entry = ClipboardEntry(text: "test", timestamp: Date())
        XCTAssertEqual(entry.relativeTime, "Just now")
    }

    func testTruncatedText() {
        let longText = String(repeating: "a", count: 100)
        let entry = ClipboardEntry(text: longText)
        let truncated = entry.truncated(maxLength: 10)
        XCTAssertEqual(truncated.count, 11)  // 10 + "…"
        XCTAssertTrue(truncated.hasSuffix("…"))
    }

    func testShortTextNotTruncated() {
        let entry = ClipboardEntry(text: "short")
        let result = entry.truncated(maxLength: 10)
        XCTAssertEqual(result, "short")
    }
}
