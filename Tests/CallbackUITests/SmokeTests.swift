import XCTest

// Smoke test — verifies the core drill loop end-to-end.
// Green run requires a simulator runtime; marked as carry-forward until one is installed.
final class SmokeTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-placement-done"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testCoreDrillLoop() throws {
        // Home tab should be visible
        let homeTab = app.tabBars.buttons["home-tab"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))

        // Navigate to Topics tab
        let topicsTab = app.tabBars.buttons["topics-tab"]
        XCTAssertTrue(topicsTab.waitForExistence(timeout: 5))
        topicsTab.tap()

        // Tap the first topic row
        let firstTopicRow = app.cells["topic-row-0"]
        XCTAssertTrue(firstTopicRow.waitForExistence(timeout: 5))
        firstTopicRow.tap()

        // Tap Practice CTA on TopicDetail
        let practiceCTA = app.buttons["topic-practice-cta"]
        XCTAssertTrue(practiceCTA.waitForExistence(timeout: 5))
        practiceCTA.tap()

        // Tap the first answer option
        let optionA = app.buttons["option-A"]
        XCTAssertTrue(optionA.waitForExistence(timeout: 5))
        optionA.tap()

        // Verdict chip should appear
        let verdictChip = app.staticTexts["verdict-chip"]
        XCTAssertTrue(verdictChip.waitForExistence(timeout: 5))

        // Tap Next or Finish
        let nextButton = app.buttons["next-finish-button"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()
    }
}
