import Foundation
import SwiftUI

/// Inline-Markdown parsing for authored *content* strings — question prompts,
/// explanations, rubrics — as opposed to string literals written in Swift.
///
/// `Text("some `code`")` renders the backticks because a literal resolves to
/// `LocalizedStringKey`, which parses Markdown; `Text(someString)` resolves to
/// the `StringProtocol` overload, which does not. Content arrives as `String`,
/// so every content string has to be parsed explicitly.
public enum InlineMarkdown {
    /// Parses `content` as inline Markdown, falling back to the literal text.
    ///
    /// `.inlineOnlyPreservingWhitespace` is deliberate: the default option
    /// collapses block structure, so a two-paragraph rubric would lose its
    /// newlines and run together.
    public static func attributed(_ content: String) -> AttributedString {
        (try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(content)
    }
}

public extension Text {
    /// `Text` over an authored content string, with its inline Markdown rendered.
    ///
    /// Wrapping code terms in backticks is house style throughout the content
    /// JSON; this is what turns them into monospaced runs instead of literal
    /// backticks on screen.
    init(inlineMarkdown content: String) {
        self.init(InlineMarkdown.attributed(content))
    }
}
