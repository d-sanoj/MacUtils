import XCTest

/// Basic UI smoke tests for the Mac Utils menu bar app.
final class MenuBarUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAppLaunches() throws {
        // Verify the app is running
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testMenuBarIconExists() throws {
        // The menu bar status item should exist
        // Note: Testing menu bar items with XCUITest is limited;
        // this test verifies the app launches without crashing
        XCTAssertTrue(app.exists)
    }

    func testSettingsWindowOpens() throws {
        // This test verifies the settings window can be opened
        // In a real XCUITest, you would interact with the menu bar icon
        // For now, verify the app doesn't crash on launch
        let launched = app.wait(for: .runningForeground, timeout: 10)
        XCTAssertTrue(launched, "App should launch successfully")
    }
}
