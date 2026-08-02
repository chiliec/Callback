import XCTest

/// A `.navigationTitle` in the default large style, next to a pinned
/// `.safeAreaInset(edge: .top)`, lays the title out but never paints it: the
/// bar keeps the string for identification, the static text reports a normal
/// on-screen frame, and nothing is drawn. `TopicsView` hit this and fixed it
/// with `.navigationBarTitleDisplayMode(.inline)`; `ReviewQueueView` shipped in
/// build 18 without it, showing a blank band above the All/Wrong/Flagged filter.
///
/// Existence and frame assertions both pass on the broken screen — the two bars
/// are indistinguishable in the accessibility tree — so this samples the pixels
/// inside the title's own frame and insists something was actually drawn there.
final class NavigationTitleTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--uitest-placement-done", "--demo-seed"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 60),
                      "the app never finished launching")
        return app
    }

    /// The first gesture after launch is the one XCUITest most often loses to
    /// app re-activation, so a tab tap gets one identical retry.
    private func selectTab(_ app: XCUIApplication, _ name: String, expecting outcome: XCUIElement) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 45), "the \(name) tab never appeared")
        tab.tap()
        if outcome.waitForExistence(timeout: 20) { return }
        tab.tap()
        XCTAssertTrue(outcome.waitForExistence(timeout: 30),
                      "the \(name) tab did not show its content")
    }

    // MARK: - Pixel probe

    /// The fraction of pixels in `rect` that are markedly darker than the
    /// lightest pixel there. Title glyphs are near-black on a light bar, so an
    /// empty strip scores ~0 and a drawn title scores a few percent.
    ///
    /// `rect` is in points. The screenshot's own `scale` is not usable for the
    /// conversion — it reports 1.0 while `size` is in pixels — so the factor
    /// comes from the window: pixels wide ÷ points wide.
    private func inkCoverage(of rect: CGRect, in app: XCUIApplication) throws -> Double {
        let cgImage = try XCTUnwrap(XCUIScreen.main.screenshot().image.cgImage,
                                    "no CGImage in the screenshot")
        let pointsWide = app.windows.firstMatch.frame.width
        XCTAssertGreaterThan(pointsWide, 0, "the app window has no width")
        let scale = CGFloat(cgImage.width) / pointsWide

        let pixelRect = CGRect(x: rect.minX * scale, y: rect.minY * scale,
                               width: rect.width * scale, height: rect.height * scale)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        XCTAssertFalse(pixelRect.isEmpty, "the title's frame is off-screen")

        let cropped = try XCTUnwrap(cgImage.cropping(to: pixelRect), "could not crop the title rect")
        let width = cropped.width
        let height = cropped.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), "could not build a bitmap context")
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))

        var luminances: [Double] = []
        luminances.reserveCapacity(width * height)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[index]), g = Double(pixels[index + 1]), b = Double(pixels[index + 2])
            luminances.append(0.299 * r + 0.587 * g + 0.114 * b)
        }
        // Relative to the strip's own background, so this does not assume a
        // light appearance or a particular bar material.
        let lightest = try XCTUnwrap(luminances.max())
        let inked = luminances.filter { lightest - $0 > 60 }.count
        return Double(inked) / Double(luminances.count)
    }

    private func assertTitleIsDrawn(
        _ app: XCUIApplication,
        _ bar: XCUIElement,
        _ title: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertTrue(bar.waitForExistence(timeout: 30), "the \(title) bar never appeared",
                      file: file, line: line)
        let label = bar.staticTexts[title]
        XCTAssertTrue(label.waitForExistence(timeout: 10), "the bar has no \(title) title element",
                      file: file, line: line)
        // The large-title transition fades in; sample after it settles.
        Thread.sleep(forTimeInterval: 1.5)
        let coverage = try inkCoverage(of: label.frame, in: app)
        XCTAssertGreaterThan(coverage, 0.01,
                             "\"\(title)\" occupies a frame in the navigation bar but nothing is "
                             + "painted there (ink coverage \(String(format: "%.4f", coverage))) "
                             + "— an empty title strip",
                             file: file, line: line)
    }

    // MARK: - Tests

    /// The review queue: `.navigationTitle` + a pinned top inset, the pairing
    /// that swallows the title.
    func testReviewQueueDrawsItsTitle() throws {
        let app = launch()
        selectTab(app, "Practice", expecting: app.buttons["review-queue-row"])

        let queueRow = app.buttons["review-queue-row"]
        queueRow.tap()

        try assertTitleIsDrawn(app, app.navigationBars["Review"], "Review")
    }

    /// Topic detail is the control: the same push with no top inset, whose large
    /// title has always rendered. Guards the probe against scoring everything as
    /// blank — if this one fails, the measurement is wrong, not the screen.
    func testTopicDetailDrawsItsTitle() throws {
        let app = launch()
        selectTab(app, "Topics", expecting: app.buttons["topic-row-0"])

        app.buttons["topic-row-0"].tap()

        try assertTitleIsDrawn(app, app.navigationBars["Swift"], "Swift")
    }
}
