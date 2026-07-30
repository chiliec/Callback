import XCTest

/// Captures App Store screenshots against the `--demo-seed` progress state.
/// Writes PNGs to SCREENSHOT_DIR, which the Callback scheme's test action points
/// at `docs/store-assets/ios`. Run via `scripts/capture-screenshots.sh`.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var outputDir: URL?

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Fail loudly rather than passing with zero files written: the whole point
        // of this test is the PNGs.
        let path = try XCTUnwrap(
            ProcessInfo.processInfo.environment["SCREENSHOT_DIR"],
            "SCREENSHOT_DIR unset — it comes from the Callback scheme's test action"
        )
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        outputDir = dir
        app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-placement-done", "--demo-seed"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Identifier lookup that does not care which element type SwiftUI chose —
    /// `home-root` lands on a List, which is not an `otherElements` match.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func snap(_ name: String) throws {
        // Let ring/bar animations and the navigation-bar title transition settle.
        // At 1s the Topics large title was still mid-fade and the tab bar showed
        // ghosted content from the outgoing tab.
        Thread.sleep(forTimeInterval: 2.5)
        let shot = XCUIScreen.main.screenshot()
        let dir = try XCTUnwrap(outputDir)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }

    func testCaptureStoreScreenshots() throws {
        // 01 — Home: readiness ring, streak, continue card.
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20))
        XCTAssertTrue(element("home-readiness-ring").waitForExistence(timeout: 10))
        try snap("01-home")

        // 02 — Topics list with per-topic mastery.
        // Note: iOS 18+ Tab(value:) does not propagate .accessibilityIdentifier to
        // UITabBarItem in XCTest — tabs are queried by label text.
        app.tabBars.buttons["Topics"].tap()
        let firstTopicRow = app.buttons["topic-row-0"]
        XCTAssertTrue(firstTopicRow.waitForExistence(timeout: 10))
        try snap("02-topics")

        // 03 — Topic detail: mastery ring, lessons, question counts.
        firstTopicRow.tap()
        let practiceCTA = app.buttons["topic-practice-cta"]
        XCTAssertTrue(practiceCTA.waitForExistence(timeout: 10))
        try snap("03-topic-detail")

        // 04 — Question player, unanswered.
        practiceCTA.tap()
        let optionA = app.buttons["option-A"]
        XCTAssertTrue(optionA.waitForExistence(timeout: 10))
        try snap("04-question")

        // 05 — Answered state: verdict chip + explanation.
        optionA.tap()
        XCTAssertTrue(app.staticTexts["verdict-chip"].waitForExistence(timeout: 10))
        try snap("05-verdict")

        // 06 — Profile: weekly activity chart and session history.
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        try snap("06-profile")
    }
}
