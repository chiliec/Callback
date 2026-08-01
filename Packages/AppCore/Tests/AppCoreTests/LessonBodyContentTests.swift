import Testing
import Foundation
@testable import AppCore

/// Invariants over the *real* lesson bodies, run through `LessonBodyParser`.
///
/// `LessonBodyParserTests` proves the parser handles the dialect; this proves the
/// authored content stays inside that dialect. It exists because the two lesson
/// rendering bugs that shipped were both authoring-side — the parser was fine and
/// the fixtures passed, but real bodies used shapes the reader silently mangles:
/// `AttributedString(markdown:)` discards block structure and falls back to raw
/// text when markdown is malformed, so the failure mode is a wall of collapsed
/// paragraphs or visible `**asterisks**` rather than a crash. No automated suite
/// saw either one.
@Suite("Lesson body content")
struct LessonBodyContentTests {

    private struct Body {
        let lessonID: String
        let title: String
        let markdown: String
        let segments: [BodySegment]
    }

    private func bodies() throws -> [Body] {
        try ContentLoader.bundledContent().topics.flatMap { topic in
            topic.lessons.map {
                Body(lessonID: $0.id, title: $0.title, markdown: $0.body,
                     segments: LessonBodyParser.parse($0.body))
            }
        }
    }

    /// Every text the reader hands to `AttributedString(markdown:)`: prose,
    /// headings and list items. Code and key ideas are rendered verbatim.
    private func markdownTexts(_ body: Body) -> [String] {
        body.segments.flatMap { segment -> [String] in
            switch segment {
            case .prose(let text):          return [text]
            case .heading(let title):       return [title]
            case .bulletList(let items):    return items
            case .numberedList(let items):  return items
            case .code, .keyIdea:           return []
            }
        }
    }

    @Test func everyLessonParsesIntoSegments() throws {
        let bodies = try bodies()

        // Non-vacuity guard: every expectation here iterates the bundled lessons,
        // so an empty (or accidentally unbundled) content set would turn the whole
        // suite green while checking nothing.
        #expect(bodies.count >= 20, "only \(bodies.count) lessons loaded — is the content bundled?")

        for body in bodies {
            // One segment for a whole lesson means the reader shows an unstructured
            // blob: no headings, no snippets, no key idea.
            #expect(body.segments.count >= 2,
                    "\(body.lessonID) parsed into \(body.segments.count) segment(s)")
        }
    }

    /// The classifiers match on a raw prefix, so an indented `  - item` or
    /// ` ## Heading` never becomes a list or heading — it lands in prose and the
    /// marker is rendered literally.
    @Test func noBlockMarkerHidesInsideProse() throws {
        let markers = ["#", "##", "###", "-", "*", ">"]
        for body in try bodies() {
            for case .prose(let text) in body.segments {
                for line in text.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed != line else { continue }   // unindented: already classified
                    let firstWord = trimmed.components(separatedBy: " ").first ?? ""
                    #expect(!markers.contains(firstWord),
                            "\(body.lessonID) has an indented block marker rendered as prose: \(line)")
                }
            }
        }
    }

    /// An odd number of fences means one is unterminated, which the parser
    /// tolerates by emitting the rest of the lesson as code.
    @Test func codeFencesAreBalanced() throws {
        for body in try bodies() {
            let fences = body.markdown.components(separatedBy: "\n")
                .filter { $0.hasPrefix("```") }
                .count
            #expect(fences % 2 == 0,
                    "\(body.lessonID) has \(fences) code fences — one is unterminated")
        }
    }

    @Test func everyMarkdownTextIsWellFormed() throws {
        for body in try bodies() {
            for text in markdownTexts(body) {
                #expect(throws: Never.self,
                        "\(body.lessonID) has markdown the reader would fall back to raw text on: \(text)") {
                    try AttributedString(markdown: text)
                }
            }
        }
    }

    @Test func noSegmentIsEmpty() throws {
        for body in try bodies() {
            for segment in body.segments {
                switch segment {
                case .prose(let text):
                    #expect(!text.isEmpty, "\(body.lessonID) has an empty prose segment")
                case .heading(let title):
                    #expect(!title.isEmpty, "\(body.lessonID) has a heading with no title")
                case .keyIdea(let idea):
                    #expect(!idea.isEmpty, "\(body.lessonID) has an empty key idea")
                case .code(_, let language, let code):
                    #expect(!language.isEmpty, "\(body.lessonID) has a code block with no language")
                    #expect(!code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            "\(body.lessonID) has an empty code block")
                case .bulletList(let items), .numberedList(let items):
                    #expect(!items.isEmpty, "\(body.lessonID) has an empty list")
                    for item in items {
                        #expect(!item.isEmpty, "\(body.lessonID) has an empty list item")
                    }
                }
            }
        }
    }

    /// The filename comment is only lifted out of a snippet when it reads exactly
    /// `// Name.swift`. Any other spelling stays in the code and shows up as a
    /// stray comment above the first real line.
    @Test func codeSnippetFilenameCommentsAreLiftedOut() throws {
        for body in try bodies() {
            for case .code(_, _, let code) in body.segments {
                let first = code.components(separatedBy: "\n").first ?? ""
                let looksLikeAFilename = first.hasPrefix("//")
                    && first.trimmingCharacters(in: .whitespaces).hasSuffix(".swift")
                #expect(!looksLikeAFilename,
                        "\(body.lessonID) code starts with \(first) — write it as `// Name.swift` so it becomes the snippet header")
            }
        }
    }

    /// A single prose segment this long is a paragraph break that never got
    /// authored: the reader renders it as an unbroken wall of text.
    @Test func noProseSegmentIsAWallOfText() throws {
        for body in try bodies() {
            for case .prose(let text) in body.segments {
                #expect(text.count < 1000,
                        "\(body.lessonID) has a \(text.count)-character paragraph — split it with a blank line")
            }
        }
    }

    /// Headings are styled as headings; a sentence-length one is really prose that
    /// happens to start with `##`.
    @Test func headingsReadAsHeadings() throws {
        for body in try bodies() {
            for case .heading(let title) in body.segments {
                #expect(title.count <= 80, "\(body.lessonID) heading is a sentence: \(title)")
                #expect(!title.hasSuffix("."), "\(body.lessonID) heading ends in a full stop: \(title)")
            }
        }
    }
}
