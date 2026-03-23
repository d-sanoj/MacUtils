import XCTest
@testable import MacUtilsCore

final class TyleTests: XCTestCase {

    // Known screen rect simulating a 1920×1080 display with menu bar (25px) and dock (70px)
    let fullWidth: CGFloat = 1920
    let fullHeight: CGFloat = 1080
    let menuBarHeight: CGFloat = 25
    let dockHeight: CGFloat = 70

    var calculator: TyleCalculator!

    override func setUp() {
        super.setUp()
        // Usable area: 1920 × (1080 - 25 - 70) = 1920 × 985, origin at (0, 70)
        calculator = TyleCalculator(
            fullWidth: fullWidth,
            fullHeight: fullHeight,
            menuBarHeight: menuBarHeight,
            dockHeight: dockHeight
        )
    }

    override func tearDown() {
        calculator = nil
        super.tearDown()
    }

    // MARK: - Snap Position Calculations

    func testLeftHalf() {
        let frame = calculator.frame(for: .leftHalf)
        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, 70)
        XCTAssertEqual(frame.width, 960)
        XCTAssertEqual(frame.height, 985)
    }

    func testRightHalf() {
        let frame = calculator.frame(for: .rightHalf)
        XCTAssertEqual(frame.origin.x, 960)
        XCTAssertEqual(frame.origin.y, 70)
        XCTAssertEqual(frame.width, 960)
        XCTAssertEqual(frame.height, 985)
    }

    func testTopHalf() {
        let frame = calculator.frame(for: .topHalf)
        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, 70)
        XCTAssertEqual(frame.width, 1920)
        XCTAssertEqual(frame.height, 492.5)
    }

    func testBottomHalf() {
        let frame = calculator.frame(for: .bottomHalf)
        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, 70 + 492.5)
        XCTAssertEqual(frame.width, 1920)
        XCTAssertEqual(frame.height, 492.5)
    }

    func testTopLeft() {
        let frame = calculator.frame(for: .topLeft)
        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, 70)
        XCTAssertEqual(frame.width, 960)
        XCTAssertEqual(frame.height, 492.5)
    }

    func testTopRight() {
        let frame = calculator.frame(for: .topRight)
        XCTAssertEqual(frame.origin.x, 960)
        XCTAssertEqual(frame.origin.y, 70)
        XCTAssertEqual(frame.width, 960)
        XCTAssertEqual(frame.height, 492.5)
    }

    func testBottomLeft() {
        let frame = calculator.frame(for: .bottomLeft)
        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, 70 + 492.5)
        XCTAssertEqual(frame.width, 960)
        XCTAssertEqual(frame.height, 492.5)
    }

    func testBottomRight() {
        let frame = calculator.frame(for: .bottomRight)
        XCTAssertEqual(frame.origin.x, 960)
        XCTAssertEqual(frame.origin.y, 70 + 492.5)
        XCTAssertEqual(frame.width, 960)
        XCTAssertEqual(frame.height, 492.5)
    }

    // MARK: - Menu Bar + Dock Inset Logic

    func testMenuBarAndDockInsets() {
        // Usable height should be fullHeight - menuBar - dock
        let usableHeight = fullHeight - menuBarHeight - dockHeight
        XCTAssertEqual(calculator.screenRect.height, usableHeight)
        XCTAssertEqual(calculator.screenRect.origin.y, dockHeight)
    }

    func testNoDockScreen() {
        let noDock = TyleCalculator(fullWidth: 1920, fullHeight: 1080, menuBarHeight: 25, dockHeight: 0)
        let frame = noDock.frame(for: .leftHalf)
        XCTAssertEqual(frame.origin.y, 0)
        XCTAssertEqual(frame.height, 1055)
    }

    func testCustomScreenSize() {
        let retina = TyleCalculator(fullWidth: 2560, fullHeight: 1440, menuBarHeight: 25, dockHeight: 70)
        let frame = retina.frame(for: .rightHalf)
        XCTAssertEqual(frame.origin.x, 1280)
        XCTAssertEqual(frame.width, 1280)
        XCTAssertEqual(frame.height, 1345)
    }

    // MARK: - Bounds Checking

    func testNoSnapRectExceedsScreenBounds() {
        for position in SnapPosition.allCases {
            let frame = calculator.frame(for: position)
            XCTAssertTrue(
                calculator.isWithinBounds(frame),
                "\(position.displayName) rect \(frame) exceeds screen bounds \(calculator.screenRect)"
            )
        }
    }

    func testSnapRectsCoversFullScreen() {
        // Left + Right should cover full width
        let left = calculator.frame(for: .leftHalf)
        let right = calculator.frame(for: .rightHalf)
        XCTAssertEqual(left.width + right.width, calculator.screenRect.width)

        // Top + Bottom should cover full height
        let top = calculator.frame(for: .topHalf)
        let bottom = calculator.frame(for: .bottomHalf)
        XCTAssertEqual(top.height + bottom.height, calculator.screenRect.height)
    }

    func testQuartersCoverFullScreen() {
        let tl = calculator.frame(for: .topLeft)
        let tr = calculator.frame(for: .topRight)
        let bl = calculator.frame(for: .bottomLeft)
        let br = calculator.frame(for: .bottomRight)

        // All four quarters should tile the full usable area
        XCTAssertEqual(tl.width + tr.width, calculator.screenRect.width)
        XCTAssertEqual(tl.height + bl.height, calculator.screenRect.height)
        XCTAssertEqual(bl.width + br.width, calculator.screenRect.width)
        XCTAssertEqual(tr.height + br.height, calculator.screenRect.height)
    }

    // MARK: - Direct CGRect Initializer

    func testDirectRectInitializer() {
        let rect = CGRect(x: 100, y: 50, width: 1820, height: 1000)
        let calc = TyleCalculator(screenRect: rect)
        let frame = calc.frame(for: .leftHalf)
        XCTAssertEqual(frame.origin.x, 100)
        XCTAssertEqual(frame.origin.y, 50)
        XCTAssertEqual(frame.width, 910)
        XCTAssertEqual(frame.height, 1000)
    }
}
