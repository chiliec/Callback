import XCTest

// Covers the phase-1 vertical slice: the System Design drill had no content at
// all before `topic-sysdesign.json`, so the row read "Coming soon" and there was
// nothing to serve. Asserts the drill is now offered and that a `systemDesign`
// question answers through the self-rating path — reveal guidance, rate, advance
// — with no multiple-choice options anywhere in it.
final class SystemDesignDrillTests: XCTestCase {
    var app: XCUIApplication!

    /// `DrillSpec(kind: .systemDesign, ..., maxQuestions: 6)` in `PracticeView`.
    private let expectedQuestionCount = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-placement-done"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSystemDesignDrillIsOfferedAndCompletesEndToEnd() throws {
        app.tabBars.buttons["Practice"].tap()

        let drillRow = app.buttons["drill-row-systemDesign"]
        XCTAssertTrue(drillRow.waitForExistence(timeout: 10))
        XCTAssertTrue(drillRow.isEnabled, "System Design drill is still gated — no eligible questions")
        XCTAssertTrue(drillRow.staticTexts["20 min"].exists,
                      "drill row should show its duration, not 'Coming soon'")

        drillRow.tap()
        XCTAssertTrue(app.buttons["Pause session"].waitForExistence(timeout: 10),
                      "tapping the System Design drill did not open a session")

        for i in 0..<expectedQuestionCount {
            // Only a self-rated question shows the reveal card. If `.systemDesign`
            // ever dropped out of `QuestionKind.isSelfRated`, `MockSessionView`
            // would render an empty option list here and this would fail.
            let revealButton = app.buttons["reveal-guidance-button"]
            XCTAssertTrue(revealButton.waitForExistence(timeout: 10),
                          "reveal button missing at question \(i) — is this question gradable by mistake?")
            revealButton.tap()

            // Solid on every question, so the results screen must read 6 of 6 —
            // which also proves self-rating credit reaches the score.
            let rateStrong = app.buttons["self-rate-2"]
            XCTAssertTrue(rateStrong.waitForExistence(timeout: 5), "rate button missing at question \(i)")
            rateStrong.tap()

            // `MockSessionView` advances with a plain `Button("Next")` — no
            // identifier — and its `.bar` background stretches the accessibility
            // frame toward the home indicator, so tap near the frame's top.
            let next = app.buttons["Next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5), "Next button missing at question \(i)")
            next.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        }

        XCTAssertTrue(app.staticTexts["\(expectedQuestionCount) of \(expectedQuestionCount) correct"]
                        .waitForExistence(timeout: 10),
                      "session did not finish with all \(expectedQuestionCount) questions rated Solid")
    }
}
