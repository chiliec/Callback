import XCTest

// Regression test for the P0 dead end: shipped behavioral questions carried
// `options: []`, so `pick(_:)` could never fire, `isAnswered` never flipped,
// and there was no way past `next-finish-button`. Must fail against d86cbac.
final class BehavioralDrillTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-placement-done", "--demo-seed"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testBehavioralDrillCanBeCompletedEndToEnd() throws {
        app.tabBars.buttons["Topics"].tap()

        // Behavioral is order 5 (last of 6 topics) in the shipping content bundle.
        let behavioralRow = app.buttons["topic-row-5"]
        XCTAssertTrue(behavioralRow.waitForExistence(timeout: 10))
        behavioralRow.tap()

        let practiceCTA = app.buttons["topic-practice-cta"]
        XCTAssertTrue(practiceCTA.waitForExistence(timeout: 10))
        practiceCTA.tap()

        for i in 0..<10 {
            let revealButton = app.buttons["reveal-guidance-button"]
            XCTAssertTrue(revealButton.waitForExistence(timeout: 10), "reveal button missing at question \(i)")
            revealButton.tap()

            let rateStrong = app.buttons["self-rate-2"]
            XCTAssertTrue(rateStrong.waitForExistence(timeout: 5), "rate button missing at question \(i)")
            rateStrong.tap()

            let nextFinish = app.buttons["next-finish-button"]
            XCTAssertTrue(nextFinish.waitForExistence(timeout: 5), "next/finish button missing at question \(i)")
            // The element's accessibility frame includes the `.bar` background
            // that extends behind the safe area, so its center sits near the
            // tab bar rather than on the visible button — tap near the top instead.
            nextFinish.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        }

        XCTAssertTrue(app.staticTexts["Drill complete"].waitForExistence(timeout: 10))
    }
}
