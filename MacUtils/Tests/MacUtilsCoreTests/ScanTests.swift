import XCTest
@testable import MacUtilsCore

final class ScanTests: XCTestCase {

    let reconstructor = ScanTextReconstructor(averageCharWidth: 8.0)

    // MARK: - Indentation Reconstruction from Bounding Box X-Positions

    func testIndentationFromXPositions() {
        let observations = [
            TextObservation(text: "def main():", boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20)),
            TextObservation(text: "print(\"hello\")", boundingBox: CGRect(x: 32, y: 25, width: 120, height: 20)),
            TextObservation(text: "return 0", boundingBox: CGRect(x: 32, y: 50, width: 80, height: 20)),
        ]

        let result = reconstructor.reconstruct(observations: observations)
        let lines = result.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], "def main():")  // No indent (x=0)
        XCTAssertTrue(lines[1].hasPrefix("    "))  // 32/8 = 4 spaces
        XCTAssertTrue(lines[2].hasPrefix("    "))  // 32/8 = 4 spaces
    }

    func testNoIndentationWhenAllSameX() {
        let observations = [
            TextObservation(text: "Line 1", boundingBox: CGRect(x: 50, y: 0, width: 100, height: 20)),
            TextObservation(text: "Line 2", boundingBox: CGRect(x: 50, y: 25, width: 100, height: 20)),
            TextObservation(text: "Line 3", boundingBox: CGRect(x: 50, y: 50, width: 100, height: 20)),
        ]

        let result = reconstructor.reconstruct(observations: observations)
        let lines = result.split(separator: "\n").map(String.init)

        // All lines should have no leading spaces since they all share the same x
        for line in lines {
            XCTAssertFalse(line.hasPrefix(" "), "Line '\(line)' should not have leading spaces")
        }
    }

    // MARK: - Output String Matching for Known Observations

    func testOutputMatchesExpected() {
        let observations = [
            TextObservation(text: "Hello", boundingBox: CGRect(x: 0, y: 0, width: 50, height: 15)),
            TextObservation(text: "World", boundingBox: CGRect(x: 0, y: 20, width: 50, height: 15)),
        ]

        let result = reconstructor.reconstruct(observations: observations)
        XCTAssertEqual(result, "Hello\nWorld")
    }

    func testSingleObservation() {
        let observations = [
            TextObservation(text: "Single line", boundingBox: CGRect(x: 10, y: 10, width: 100, height: 20)),
        ]

        let result = reconstructor.reconstruct(observations: observations)
        XCTAssertEqual(result, "Single line")
    }

    // MARK: - Empty Region Handling

    func testEmptyObservationsReturnsEmptyString() {
        let result = reconstructor.reconstruct(observations: [])
        XCTAssertEqual(result, "")
    }

    // MARK: - Sorting

    func testObservationsAreSortedByY() {
        let observations = [
            TextObservation(text: "Third", boundingBox: CGRect(x: 0, y: 50, width: 50, height: 15)),
            TextObservation(text: "First", boundingBox: CGRect(x: 0, y: 0, width: 50, height: 15)),
            TextObservation(text: "Second", boundingBox: CGRect(x: 0, y: 25, width: 50, height: 15)),
        ]

        let result = reconstructor.reconstruct(observations: observations)
        XCTAssertEqual(result, "First\nSecond\nThird")
    }

    // MARK: - Normalized Coordinates

    func testReconstructFromNormalized() {
        let observations = [
            TextObservation(text: "Left", boundingBox: CGRect(x: 0.0, y: 0, width: 0.2, height: 0.1)),
            TextObservation(text: "Indented", boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1)),
        ]

        let result = reconstructor.reconstructFromNormalized(observations: observations, imageWidth: 800)
        let lines = result.split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], "Left")
        // 0.1 * 800 = 80 pixels, 80/8 = 10 spaces
        XCTAssertTrue(lines[1].hasPrefix(String(repeating: " ", count: 10)))
    }

    // MARK: - Custom Character Width

    func testCustomAverageCharWidth() {
        let customReconstructor = ScanTextReconstructor(averageCharWidth: 16.0)
        let observations = [
            TextObservation(text: "Base", boundingBox: CGRect(x: 0, y: 0, width: 50, height: 15)),
            TextObservation(text: "Indented", boundingBox: CGRect(x: 32, y: 25, width: 80, height: 15)),
        ]

        let result = customReconstructor.reconstruct(observations: observations)
        let lines = result.split(separator: "\n").map(String.init)

        // 32 / 16 = 2 spaces
        XCTAssertEqual(lines[1], "  Indented")
    }
}
