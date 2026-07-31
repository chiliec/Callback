import XCTest

/// Full-width rows built as a bare `HStack` inside a shared `GroupedCard` have
/// no background of their own, so without `.contentShape(Rectangle())` their
/// `Spacer()` and trailing chevron are not hit-testable — only the icon and
/// title strip respond, even though the chevron advertises the whole row as
/// tappable. XCUITest still reports such a row as `exists`, `isEnabled` and
/// `isHittable`, so nothing but an actual tap catches the regression.
///
/// Every tap below is a bare `.tap()`, which fires at the element frame's
/// centre — the point that did nothing before the shapes were added.
final class RowTapTargetTests: XCTestCase {
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `HomeView.weakAreasSection`. Every topic starts at 0% mastery and
    /// `Topic.isWeak` is `mastery < 65`, so a fresh placement-done launch lists
    /// them all. Tapping one jumps to the Topics tab filtered to weak areas.
    func testWeakAreaRowRespondsToACentreTap() throws {
        let app = launch(["--uitest", "--uitest-placement-done"])

        let row = app.buttons["weak-area-row-swift"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "weak areas section not shown")
        row.tap()

        XCTAssertTrue(app.navigationBars["Topics"].waitForExistence(timeout: 10),
                      "tapping the centre of a weak-area row did not open the Topics tab")
    }

    /// `FirstRunHomeView.starterTopicsSection`, which only appears before the
    /// placement quiz is done — hence no `--uitest-placement-done` here.
    func testStarterTopicRowRespondsToACentreTap() throws {
        let app = launch(["--uitest"])

        let row = app.buttons["starter-topic-row-swift"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "starter topics section not shown")
        row.tap()

        XCTAssertTrue(app.navigationBars["Topics"].waitForExistence(timeout: 10),
                      "tapping the centre of a starter-topic row did not open the Topics tab")
    }

    /// `PracticeView.reviewQueueSection`. Needs answered questions to appear at
    /// all, which `--demo-seed` provides.
    func testReviewQueueRowRespondsToACentreTap() throws {
        let app = launch(["--uitest", "--uitest-placement-done", "--demo-seed"])
        app.tabBars.buttons["Practice"].tap()

        let row = app.buttons["review-queue-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "review queue row not shown")
        row.tap()

        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 10),
                      "tapping the centre of the review-queue row did not push the review queue")
    }
}
