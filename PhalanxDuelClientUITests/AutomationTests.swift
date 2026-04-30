import XCTest

final class AutomationTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCriticalPath() {
        let app = XCUIApplication()

        // Pass environment variables to the test run
        app.launchEnvironment["PHALANX_DEBUG_LOG_PATH"] = "/Users/mike/github.com/phalanxduel/game-swiftui/.debug_session.log"
        app.launchEnvironment["PHALANX_VERBOSE_LOGGING"] = "true"

        app.launch()

        // 1. Verify Boot
        let logo = app.images["shield.righthalf.filled"]
        XCTAssertTrue(logo.waitForExistence(timeout: 5), "Logo should be visible during boot")

        // 2. Wait for ServerConnect screen (after boot)
        let probeButton = app.buttons["Probe Server"]
        XCTAssertTrue(probeButton.waitForExistence(timeout: 10), "Should reach ServerConnect screen")

        // 3. Connect to Local Direct
        app.buttons["Local Direct"].tap()

        // 4. Probe Server
        probeButton.tap()

        // 5. Verify Discovery (Check if LP 20 appears, which we saw in the logs)
        let lpInfo = app.staticTexts["20"]
        XCTAssertTrue(lpInfo.waitForExistence(timeout: 5), "Discovery should fetch server defaults (LP 20)")

        // 6. Enter name and Join
        let nameField = app.textFields["Player Name"]
        nameField.tap()
        nameField.typeText("AutomationBot")

        app.buttons["Create Match via POST /matches"].tap()

        // 7. Verify we reach the Session screen
        let sessionTitle = app.staticTexts["Game Session"]
        XCTAssertTrue(sessionTitle.waitForExistence(timeout: 10), "Should reach the Game Session screen")
    }
}
