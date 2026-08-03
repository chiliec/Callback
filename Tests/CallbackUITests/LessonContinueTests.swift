import XCTest

/// TestFlight feedback on build 17 — "No way to continue." (iPhone 13 mini,
/// iOS 26.5.2), screenshotted on a finished lesson 1 of 4. The reader's "Up next"
/// card names the following lesson but was a plain `GroupedCard`: no `Button`, no
/// `NavigationLink`, nothing to tap. The only way on was Back plus a second tap
/// in the topic's lesson list.
///
/// Taps here are bare `.tap()`s, which fire at the element frame's centre — the
/// point a missing `.contentShape(Rectangle())` leaves dead — so these cover the
/// hit-testing shape as well as the missing link.
final class LessonContinueTests: XCTestCase {
    /// `topic-swift.json`, topic order 0, lessons in `order` order.
    private let swiftLessons = [
        "Value vs Reference Types",
        "Optionals & Unwrapping",
        "Protocols & Generics",
        "Closures: Capture Semantics & Escaping"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Harness

    /// The first launch of a run installs the app and seeds content into an
    /// in-memory store, which can take the best part of a minute on a cold
    /// simulator — so wait for the shell before touching anything.
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 60),
                      "the app never finished launching")
        return app
    }

    /// The screen's scrollable container, whichever kind it is: the reader is a
    /// `ScrollView`, topic detail is a `List` (a collection view), and swiping the
    /// wrong one — or a container that doesn't exist — scrolls nothing.
    private func scrollContainer(_ app: XCUIApplication) -> XCUIElement {
        for candidate in [app.scrollViews.firstMatch,
                          app.collectionViews.firstMatch,
                          app.tables.firstMatch] where candidate.exists {
            return candidate
        }
        return app.windows.firstMatch
    }

    /// Performs `action` and insists that `outcome` follows.
    ///
    /// The single retry is for the simulator, not the app: when another app is
    /// frontmost XCUITest has to re-activate ours first, and a tap synthesized
    /// during that transition is swallowed. It does not soften what's under test
    /// — the retry repeats the identical gesture, so a target that isn't
    /// hit-testable at that point still fails.
    private func insist(
        _ app: XCUIApplication,
        expecting outcome: XCUIElement,
        _ expectation: String,
        _ action: () -> Void
    ) {
        action()
        if outcome.waitForExistence(timeout: 15) { return }
        action()
        if outcome.waitForExistence(timeout: 20) { return }

        // Whatever screen we ended up on instead is the only useful evidence, and
        // it's gone by the time anyone reads the failure.
        print("=== HIERARCHY AT FAILURE (\(expectation)) ===\n\(app.debugDescription)\n=== END ===")
        XCTFail(expectation)
    }

    /// Taps `element` at its centre — the point a missing `.contentShape` leaves
    /// dead — and insists that `outcome` follows.
    private func tap(
        _ app: XCUIApplication,
        _ element: XCUIElement,
        _ what: String,
        expecting outcome: XCUIElement,
        _ expectation: String
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 45), "\(what) never appeared")

        // A longer lesson body can push the row below the fold, and a tap on a
        // non-hittable element silently does nothing.
        let scroll = scrollContainer(app)
        var scrolls = 0
        while !element.isHittable && scrolls < 6 && scroll.exists {
            scroll.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(element.isHittable, "\(what) exists but is not hittable")

        insist(app, expecting: outcome, expectation) {
            if element.exists && element.isHittable { element.tap() }
        }
    }

    /// Tab-bar taps get the same treatment: the first gesture of a freshly
    /// launched app is the likeliest one to be eaten by re-activation.
    private func selectTab(_ app: XCUIApplication, _ name: String, expecting outcome: XCUIElement) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 45), "the \(name) tab never appeared")
        insist(app, expecting: outcome, "the \(name) tab did not show its content") { tab.tap() }
    }

    private func readerTitle(_ app: XCUIApplication, _ lesson: String) -> XCUIElement {
        // The reader puts the lesson title in a `.principal` toolbar item, so the
        // navigation bar naming a lesson is the signal that its reader is up.
        app.navigationBars.staticTexts[lesson]
    }

    private func openFirstSwiftLesson(_ app: XCUIApplication) {
        selectTab(app, "Topics", expecting: app.buttons["topic-row-0"])

        tap(app, app.buttons["topic-row-0"], "the first topic row",
            expecting: app.navigationBars["Swift"],
            "the first topic row did not open topic detail")

        tap(app, app.buttons["lesson-row-0"], "the first lesson row",
            expecting: readerTitle(app, swiftLessons[0]),
            "tapping the first lesson row did not open the reader")
    }

    // MARK: - Tests

    /// The reported bug, straight through: read a lesson, tap "Up next".
    func testUpNextRowOpensTheNextLesson() throws {
        let app = launch(["--uitest", "--uitest-placement-done"])
        openFirstSwiftLesson(app)

        let upNext = app.buttons["lesson-up-next"]
        XCTAssertTrue(upNext.waitForExistence(timeout: 30),
                      "no Up next row on lesson 1 of 3 — the reader is a dead end")
        XCTAssertTrue(upNext.staticTexts[swiftLessons[1]].exists,
                      "Up next should name the following lesson")

        tap(app, upNext, "the Up next row",
            expecting: readerTitle(app, swiftLessons[1]),
            "tapping Up next did not open the next lesson — nothing to continue with")
    }

    /// The row must keep working from a *pushed* reader, not only the first one,
    /// and must not be offered on the last lesson of a topic.
    func testUpNextChainsThroughTheTopicThenStops() throws {
        let app = launch(["--uitest", "--uitest-placement-done"])
        openFirstSwiftLesson(app)

        for next in swiftLessons.dropFirst() {
            tap(app, app.buttons["lesson-up-next"], "the Up next row before \(next)",
                expecting: readerTitle(app, next),
                "Up next did not advance to \(next)")
        }

        // Last lesson: nothing left to continue to, so the row is gone rather
        // than pointing back at the start.
        XCTAssertFalse(app.buttons["lesson-up-next"].waitForExistence(timeout: 3),
                       "the last lesson of the topic should not offer an Up next row")
    }

    /// The reader is also reached from the review queue's "Covers this gap" row,
    /// which pushes through a second `Lesson` navigation destination. Guards that
    /// path — the gap row itself, and Up next once inside it.
    func testUpNextWorksFromTheReviewPath() throws {
        let app = launch(["--uitest", "--uitest-placement-done", "--demo-seed"])
        selectTab(app, "Practice", expecting: app.buttons["review-queue-row"])

        tap(app, app.buttons["review-queue-row"], "the review queue row",
            expecting: app.navigationBars["Review"],
            "the review queue row did not push the queue")

        // Not a bare `.tap()`: this button sits in a `.safeAreaInset(edge: .bottom)`
        // whose `.bar` background stretches its accessibility frame down behind
        // the tab bar, so the frame's centre is obscured and a centre tap misses.
        // The visible button is at the top of that frame.
        let startReview = app.buttons["start-review-button"]
        XCTAssertTrue(startReview.waitForExistence(timeout: 45), "the review queue is empty")
        let gapRow = app.buttons["review-covers-gap-row"]
        insist(app, expecting: gapRow, "starting the review did not show a review item") {
            if startReview.exists {
                startReview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
            }
        }

        tap(app, gapRow, "the covers-this-gap row",
            expecting: app.buttons["lesson-up-next"],
            "the covers-this-gap row did not open a lesson with a way on")

        // The row's own labels say which lesson it promises, so the assertion
        // doesn't need to know which topic the review queue happened to serve.
        let upNext = app.buttons["lesson-up-next"]
        let promised = upNext.staticTexts.allElementsBoundByIndex
            .map { $0.label }
            .filter { $0 != "Up next" }
        let nextTitle = try XCTUnwrap(promised.first, "the Up next row named no lesson")

        tap(app, upNext, "the Up next row in the review path",
            expecting: readerTitle(app, nextTitle),
            "tapping Up next from the review path did not open \(nextTitle)")
    }
}
