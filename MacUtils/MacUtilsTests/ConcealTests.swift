import XCTest
@testable import MacUtilsCore

final class ConcealTests: XCTestCase {

    var engine: ConcealEngine!

    override func setUp() {
        super.setUp()
        engine = ConcealEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - UF_HIDDEN Flag

    func testSetHiddenFlagOnRealFile() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("conceal_test_\(UUID().uuidString).txt")

        // Create a test file
        try? "test content".data(using: .utf8)!.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }

        // Set hidden
        let setResult = ConcealEngine.setHiddenFlag(at: testFile.path, hidden: true)
        XCTAssertTrue(setResult)

        // Verify it's hidden
        let isHidden = ConcealEngine.isFileHidden(at: testFile.path)
        XCTAssertEqual(isHidden, true)
    }

    func testToggleHiddenState() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("conceal_toggle_\(UUID().uuidString).txt")

        try? "test".data(using: .utf8)!.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }

        // Initially not hidden
        let initialState = ConcealEngine.isFileHidden(at: testFile.path)
        XCTAssertEqual(initialState, false)

        // Hide
        ConcealEngine.setHiddenFlag(at: testFile.path, hidden: true)
        XCTAssertEqual(ConcealEngine.isFileHidden(at: testFile.path), true)

        // Unhide
        ConcealEngine.setHiddenFlag(at: testFile.path, hidden: false)
        XCTAssertEqual(ConcealEngine.isFileHidden(at: testFile.path), false)
    }

    func testSetHiddenOnNonexistentFile() {
        let result = ConcealEngine.setHiddenFlag(at: "/nonexistent/path/file.txt", hidden: true)
        XCTAssertFalse(result)
    }

    func testIsFileHiddenOnNonexistentFile() {
        let result = ConcealEngine.isFileHidden(at: "/nonexistent/path/file.txt")
        XCTAssertNil(result)
    }

    // MARK: - Hidden File Log

    func testRecordHidden() {
        let date = Date()
        engine.recordHidden(path: "/Users/test/file.txt", date: date)

        XCTAssertTrue(engine.isHidden(path: "/Users/test/file.txt"))
        XCTAssertEqual(engine.hiddenFiles.count, 1)
    }

    func testRecordUnhidden() {
        engine.recordHidden(path: "/Users/test/file.txt")
        engine.recordUnhidden(path: "/Users/test/file.txt")

        XCTAssertFalse(engine.isHidden(path: "/Users/test/file.txt"))
        XCTAssertEqual(engine.hiddenFiles.count, 0)
    }

    func testAllHiddenPaths() {
        engine.recordHidden(path: "/b/file2.txt")
        engine.recordHidden(path: "/a/file1.txt")
        engine.recordHidden(path: "/c/file3.txt")

        let paths = engine.allHiddenPaths
        XCTAssertEqual(paths, ["/a/file1.txt", "/b/file2.txt", "/c/file3.txt"])  // Sorted
    }

    func testUnhideAll() {
        engine.recordHidden(path: "/a/file1.txt")
        engine.recordHidden(path: "/b/file2.txt")

        let paths = engine.unhideAll()
        XCTAssertEqual(paths.count, 2)
        XCTAssertEqual(engine.hiddenFiles.count, 0)
    }

    // MARK: - Persistence

    func testHiddenFileLogPersistsAndRestores() {
        engine.recordHidden(path: "/Users/test/file1.txt", date: Date(timeIntervalSince1970: 1000))
        engine.recordHidden(path: "/Users/test/file2.txt", date: Date(timeIntervalSince1970: 2000))

        let encoded = engine.encode()

        let restored = ConcealEngine(hiddenFiles: encoded)
        XCTAssertEqual(restored.hiddenFiles.count, 2)
        XCTAssertTrue(restored.isHidden(path: "/Users/test/file1.txt"))
        XCTAssertTrue(restored.isHidden(path: "/Users/test/file2.txt"))
    }

    func testEncodeFormat() {
        let date = Date(timeIntervalSince1970: 1234567890)
        engine.recordHidden(path: "/test/path.txt", date: date)

        let encoded = engine.encode()
        XCTAssertEqual(encoded["/test/path.txt"], 1234567890)
    }

    // MARK: - Finder Toggle

    func testFinderShowsHiddenFilesRead() {
        // This is a read-only test — just verify it doesn't crash
        let _ = ConcealEngine.finderShowsHiddenFiles()
    }

    func testSetFinderShowHiddenFiles() {
        // Test that the setter returns true (doesn't crash)
        // We don't actually want to toggle Finder in tests,
        // but we can verify the API works
        let currentState = ConcealEngine.finderShowsHiddenFiles()
        let result = ConcealEngine.setFinderShowHiddenFiles(currentState)
        XCTAssertTrue(result)
    }
}
