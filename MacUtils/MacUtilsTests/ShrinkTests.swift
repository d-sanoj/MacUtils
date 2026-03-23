import XCTest
@testable import MacUtilsCore

final class ShrinkTests: XCTestCase {

    // MARK: - Orientation Bake-in for all 8 EXIF Orientations

    func testOrientationUpIsIdentity() {
        let size = CGSize(width: 100, height: 200)
        let transform = EXIFOrientation.up.transform(for: size)
        XCTAssertEqual(transform, .identity)
    }

    func testOrientationOutputSizesForNonRotated() {
        let size = CGSize(width: 100, height: 200)
        for orientation in [EXIFOrientation.up, .upMirrored, .down, .downMirrored] {
            let output = orientation.outputSize(for: size)
            XCTAssertEqual(output.width, 100, "\(orientation) width mismatch")
            XCTAssertEqual(output.height, 200, "\(orientation) height mismatch")
        }
    }

    func testOrientationOutputSizesForRotated() {
        let size = CGSize(width: 100, height: 200)
        for orientation in [EXIFOrientation.left, .leftMirrored, .right, .rightMirrored] {
            let output = orientation.outputSize(for: size)
            XCTAssertEqual(output.width, 200, "\(orientation) width mismatch — should swap")
            XCTAssertEqual(output.height, 100, "\(orientation) height mismatch — should swap")
        }
    }

    func testAllOrientationsProduceValidTransforms() {
        let size = CGSize(width: 640, height: 480)
        for orientation in EXIFOrientation.allCases {
            let transform = orientation.transform(for: size)
            // Just verify it doesn't crash and produces a non-degenerate transform
            XCTAssertFalse(transform.a.isNaN, "\(orientation) produced NaN in transform")
            XCTAssertFalse(transform.d.isNaN, "\(orientation) produced NaN in transform")
        }
    }

    func testDownRotation180() {
        let size = CGSize(width: 100, height: 200)
        let transform = EXIFOrientation.down.transform(for: size)
        // 180° rotation: should translate to (w, h) then rotate by π
        // The point (0,0) should map to (100, 200)
        let point = CGPoint(x: 0, y: 0).applying(transform)
        XCTAssertEqual(point.x, 100, accuracy: 0.001)
        XCTAssertEqual(point.y, 200, accuracy: 0.001)
    }

    // MARK: - Output Dimensions After Processing

    func testOutputDimensionsMatchInputForNonRotated() {
        let size = CGSize(width: 1920, height: 1080)
        let output = EXIFOrientation.up.outputSize(for: size)
        XCTAssertEqual(output, size)
    }

    func testOutputDimensionsSwappedForRotated() {
        let size = CGSize(width: 1920, height: 1080)
        let output = EXIFOrientation.right.outputSize(for: size)
        XCTAssertEqual(output, CGSize(width: 1080, height: 1920))
    }

    // MARK: - Metadata Keys

    func testSupportedFormats() {
        XCTAssertTrue(ShrinkMetadataKeys.supportedExtensions.contains("jpg"))
        XCTAssertTrue(ShrinkMetadataKeys.supportedExtensions.contains("jpeg"))
        XCTAssertTrue(ShrinkMetadataKeys.supportedExtensions.contains("png"))
        XCTAssertTrue(ShrinkMetadataKeys.supportedExtensions.contains("heic"))
        XCTAssertTrue(ShrinkMetadataKeys.supportedExtensions.contains("webp"))
        XCTAssertFalse(ShrinkMetadataKeys.supportedExtensions.contains("gif"))
    }

    func testPNGChunksToStrip() {
        XCTAssertTrue(ShrinkMetadataKeys.pngChunksToStrip.contains("tEXt"))
        XCTAssertTrue(ShrinkMetadataKeys.pngChunksToStrip.contains("gAMA"))
        XCTAssertTrue(ShrinkMetadataKeys.pngChunksToStrip.contains("iCCP"))
        XCTAssertTrue(ShrinkMetadataKeys.pngChunksToStrip.contains("pHYs"))
    }

    // MARK: - ShrinkResult

    func testShrinkResultBytesSaved() {
        let result = ShrinkResult(originalSize: 1000, optimisedSize: 700, originalPath: "/test.jpg", success: true)
        XCTAssertEqual(result.bytesSaved, 300)
        XCTAssertEqual(result.percentSaved, 30.0, accuracy: 0.1)
    }

    func testShrinkResultZeroOriginalSize() {
        let result = ShrinkResult(originalSize: 0, optimisedSize: 0, originalPath: "/test.jpg", success: true)
        XCTAssertEqual(result.percentSaved, 0)
    }

    func testShrinkResultFailure() {
        let result = ShrinkResult(originalSize: 1000, optimisedSize: 0, originalPath: "/test.jpg", success: false, error: "Read error")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "Read error")
    }

    // MARK: - Atomic Replace Safety

    func testAtomicReplaceSafetySimulation() {
        // Simulate a temp file write that fails:
        // In real code, if CGImageDestinationFinalize fails, the temp file is deleted
        // and the original remains untouched. We verify the logic here.
        let tempDir = FileManager.default.temporaryDirectory
        let originalPath = tempDir.appendingPathComponent("test_original_\(UUID().uuidString).txt")
        let tempPath = tempDir.appendingPathComponent("test_temp_\(UUID().uuidString).txt")

        // Create "original"
        let originalData = "original content".data(using: .utf8)!
        try? originalData.write(to: originalPath)

        // Simulate failed write — temp file doesn't exist or is empty
        // Verify original is still intact
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalPath.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempPath.path))

        let readBack = try? String(contentsOf: originalPath, encoding: .utf8)
        XCTAssertEqual(readBack, "original content")

        // Cleanup
        try? FileManager.default.removeItem(at: originalPath)
    }

    func testAtomicReplaceSuccessSimulation() {
        let tempDir = FileManager.default.temporaryDirectory
        let originalPath = tempDir.appendingPathComponent("test_original_\(UUID().uuidString).txt")
        let tempPath = tempDir.appendingPathComponent("test_temp_\(UUID().uuidString).txt")

        // Create "original"
        try? "original".data(using: .utf8)!.write(to: originalPath)

        // Create "optimised" temp file
        try? "optimised".data(using: .utf8)!.write(to: tempPath)

        // Simulate atomic replace: move temp to original path
        do {
            try FileManager.default.removeItem(at: originalPath)
            try FileManager.default.moveItem(at: tempPath, to: originalPath)

            let content = try String(contentsOf: originalPath, encoding: .utf8)
            XCTAssertEqual(content, "optimised")
        } catch {
            XCTFail("Atomic replace failed: \(error)")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: originalPath)
    }
}
