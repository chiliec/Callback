import XCTest

/// Answering a question used to leave the verdict and the "Why" card below the
/// fold: a long prompt plus four options fills the screen, and the Next button is
/// pinned over the bottom edge, so there wasn't even a scroll cue. The teaching
/// moment had to be hunted for. Both players now scroll the verdict up.
final class VerdictVisibilityTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launched at an accessibility text size on purpose. At the default size a
    /// short question can fit prompt, options *and* verdict on one screen, which
    /// would make this test pass whether or not anything scrolls; inflated text
    /// guarantees the verdict starts below the fold, which is the case the fix is
    /// for and the case a real user with large type is always in.
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-placement-done",
                              "-UIPreferredContentSizeCategoryName",
                              "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 90),
                      "the app never finished launching")
        return app
    }

    /// `isHittable` is the assertion that matters: an element scrolled past the
    /// bottom edge of the window still `exists` with a plausible frame, but it
    /// isn't hittable — which is also exactly what "the user can't see it" means.
    func testAnsweringScrollsTheExplanationIntoView() throws {
        let app = launch()

        let topicsTab = app.tabBars.buttons["Topics"]
        XCTAssertTrue(topicsTab.waitForExistence(timeout: 45), "no Topics tab")
        topicsTab.tap()

        let swiftRow = app.buttons["topic-row-0"]
        XCTAssertTrue(swiftRow.waitForExistence(timeout: 45), "no Swift topic row")
        swiftRow.tap()

        let cta = app.buttons["topic-practice-cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 30), "no practice CTA")
        cta.tap()

        let optionA = app.buttons["option-A"]
        XCTAssertTrue(optionA.waitForExistence(timeout: 30), "the drill never started")
        optionA.tap()

        let verdict = app.staticTexts["verdict-chip"]
        XCTAssertTrue(verdict.waitForExistence(timeout: 20), "no verdict after answering")

        // The scroll is animated; give it time to settle before judging position.
        Thread.sleep(forTimeInterval: 1.5)

        let why = app.staticTexts["Why"]
        XCTAssertTrue(why.waitForExistence(timeout: 10), "no \"Why\" card after answering")

        XCTAssertTrue(verdict.isHittable,
                      "the verdict is off-screen after answering (frame \(verdict.frame))")
        XCTAssertTrue(why.isHittable,
                      "the \"Why\" explanation is off-screen after answering "
                      + "(frame \(why.frame)) — it should have scrolled up")

        // And it must land above the Next button rather than behind it.
        let next = app.buttons["next-finish-button"]
        XCTAssertTrue(next.waitForExistence(timeout: 10), "no Next button")
        XCTAssertLessThan(why.frame.minY, next.frame.maxY,
                          "the explanation is below the Next button's bottom edge")
    }
}
