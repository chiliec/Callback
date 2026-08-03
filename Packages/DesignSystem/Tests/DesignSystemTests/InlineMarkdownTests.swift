import Foundation
import Testing
@testable import DesignSystem

/// The content JSON wraps code terms in backticks throughout. Every question
/// surface used to render them literally — the whole point of this type is that
/// they don't survive to the screen.
@Test func codeSpansLoseTheirBackticks() {
    let attributed = InlineMarkdown.attributed("A `weak var` needs `: AnyObject`.")
    #expect(!String(attributed.characters).contains("`"))
    #expect(String(attributed.characters) == "A weak var needs : AnyObject.")
}

@Test func codeSpansCarryTheCodeIntent() {
    let attributed = InlineMarkdown.attributed("Swift's default is `internal`.")
    let codeRuns = attributed.runs.filter { $0.inlinePresentationIntent == .code }
    #expect(codeRuns.count == 1)
    #expect(codeRuns.map { String(attributed[$0.range].characters) } == ["internal"])
}

@Test func emphasisIsParsed() {
    let attributed = InlineMarkdown.attributed("This is **important** to know.")
    #expect(!String(attributed.characters).contains("*"))
    #expect(attributed.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
}

/// Rubrics run several paragraphs; the default (block-collapsing) parsing option
/// would join them into one wall of text.
@Test func newlinesSurviveParsing() {
    let attributed = InlineMarkdown.attributed("First line.\nSecond line.")
    #expect(String(attributed.characters) == "First line.\nSecond line.")
}

/// Prose is full of apostrophes, dashes and brackets that mean something to a
/// Markdown parser. Text with no markup must come through untouched.
@Test func plainProseIsUnchanged() {
    let prose = "ARC's retain count — [see docs] — drops to 0 (eventually)."
    #expect(String(InlineMarkdown.attributed(prose).characters) == prose)
}

/// Content is data, not a format string: a stray `%@` must stay literal rather
/// than being treated as a placeholder the way `LocalizedStringKey` would.
@Test func formatSpecifiersStayLiteral() {
    let prose = "Throughput dropped 40%, and %@ was never substituted."
    #expect(String(InlineMarkdown.attributed(prose).characters) == prose)
}
