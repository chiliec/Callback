import XCTest

/// Two defects found by the build-21 dogfood walk.
///
/// 1. Every question surface rendered authored content with plain
///    `Text(String)`, so the backticks the content JSON wraps code terms in
///    (85 prompts, 45 explanations, 19 rubrics) showed up on screen verbatim.
///    Only the lesson reader *body* ever parsed Markdown.
/// 2. The reader's quick-check card had no self-rated branch, so all four
///    Behavioral lessons ended in a prompt with nothing to interact with and an
///    unreachable rubric.
final class QuestionTextRenderingTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Harness

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-placement-done"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 90),
                      "the app never finished launching")
        return app
    }

    private func scrollContainer(_ app: XCUIApplication) -> XCUIElement {
        for candidate in [app.scrollViews.firstMatch,
                          app.collectionViews.firstMatch,
                          app.tables.firstMatch] where candidate.exists {
            return candidate
        }
        return app.windows.firstMatch
    }

    private func tap(_ app: XCUIApplication,
                     _ element: XCUIElement,
                     _ what: String,
                     expecting outcome: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 45), "\(what) never appeared")
        let scroll = scrollContainer(app)
        var scrolls = 0
        while !element.isHittable && scrolls < 8 && scroll.exists {
            scroll.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(element.isHittable, "\(what) exists but is not hittable")
        element.tap()
        if outcome.waitForExistence(timeout: 20) { return }
        // One retry: the first gesture after app activation is the one the
        // simulator swallows.
        if element.exists && element.isHittable { element.tap() }
        XCTAssertTrue(outcome.waitForExistence(timeout: 20), "tapping \(what) led nowhere")
    }

    private func openTopic(_ app: XCUIApplication, row: Int, named title: String) {
        let topicsTab = app.tabBars.buttons["Topics"]
        XCTAssertTrue(topicsTab.waitForExistence(timeout: 45), "no Topics tab")
        topicsTab.tap()
        tap(app, app.buttons["topic-row-\(row)"], "the \(title) topic row",
            expecting: app.navigationBars[title])
    }

    /// Every static text currently on screen that contains a literal backtick.
    private func backtickedTexts(_ app: XCUIApplication) -> [String] {
        app.staticTexts.allElementsBoundByIndex
            .map { $0.label }
            .filter { $0.contains("`") }
    }

    // MARK: - Tests

    /// `swift-q1` — the first question of the first topic's drill — has three
    /// backticked code spans in its prompt, so the drill's opening screen is
    /// enough to catch a regression here.
    func testQuestionPromptRendersCodeSpansRatherThanBackticks() throws {
        let app = launch()
        openTopic(app, row: 0, named: "Swift")
        tap(app, app.buttons["topic-practice-cta"], "the Swift practice CTA",
            expecting: app.buttons["option-A"])

        // The prompt is on screen: assert on its content, so a silently empty
        // screen can't pass this test.
        let prompt = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'access level'")
        ).firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 20), "the prompt never rendered")
        XCTAssertTrue(prompt.label.contains("struct Point"),
                      "expected swift-q1's code span in the prompt, got: \(prompt.label)")
        XCTAssertEqual(backtickedTexts(app), [],
                       "authored Markdown is rendering as literal backticks")

        // Answering reveals the explanation, which is backticked too.
        app.buttons["option-A"].tap()
        XCTAssertTrue(app.staticTexts["verdict-chip"].waitForExistence(timeout: 20),
                      "no verdict after answering")
        XCTAssertEqual(backtickedTexts(app), [],
                       "the explanation is rendering as literal backticks")
    }

    /// Behavioral quick checks are `kind: behavioral` with `options: []`: the
    /// card has to offer the rubric and a self-rating, and the rating has to
    /// land in the store — a single "Decent" (credit 0.5) on an otherwise
    /// untouched topic is exactly 50% mastery.
    func testBehavioralQuickCheckCanBeSelfRated() throws {
        let app = launch()
        openTopic(app, row: 5, named: "Behavioral")

        tap(app, app.buttons["lesson-row-0"], "the first Behavioral lesson row",
            expecting: app.scrollViews.firstMatch)

        // The quick check is the last thing in the reader.
        let reveal = app.buttons["reveal-guidance-button"]
        let reader = scrollContainer(app)
        var scrolls = 0
        while !(reveal.exists && reveal.isHittable) && scrolls < 15 {
            reader.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(reveal.exists && reveal.isHittable,
                      "the Behavioral quick check offers no way to check yourself")

        reveal.tap()
        let rateDecent = app.buttons["self-rate-1"]
        XCTAssertTrue(rateDecent.waitForExistence(timeout: 20),
                      "revealing the guidance offered no self-rating")
        XCTAssertTrue(app.staticTexts["Guidance"].exists, "the rubric never appeared")

        rateDecent.tap()
        XCTAssertTrue(rateDecent.isSelected, "the chosen rating is not reflected back")

        // Back out to the topic list and check the rating was actually saved.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Behavioral"].waitForExistence(timeout: 20))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let behavioralRow = app.buttons["topic-row-5"]
        XCTAssertTrue(behavioralRow.waitForExistence(timeout: 20))
        XCTAssertTrue(behavioralRow.staticTexts["50%"].waitForExistence(timeout: 20),
                      "a Decent self-rating should score the topic at 50% mastery, row reads: "
                      + behavioralRow.label)
    }
}
