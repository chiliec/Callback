import Foundation

public enum BodySegment {
    case prose(String)
    case code(filename: String?, language: String, body: String)
    case keyIdea(String)
    case heading(String)
    case bulletList([String])
    case numberedList([String])
}

/// Parses the lesson body dialect. Deliberately not full markdown: prose runs
/// through `AttributedString(markdown:)` for inline formatting, and everything
/// with block structure is an explicit segment so the reader can style it.
public struct LessonBodyParser {
    public static func parse(_ markdown: String) -> [BodySegment] {
        var segments: [BodySegment] = []
        var proseLines: [String] = []
        var listItems: [String] = []
        var listIsNumbered = false
        var inCode = false
        var codeLang = ""
        var codeLines: [String] = []

        func flushProse() {
            let block = proseLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !block.isEmpty { segments.append(.prose(block)) }
            proseLines = []
        }

        func flushList() {
            guard !listItems.isEmpty else { return }
            segments.append(listIsNumbered ? .numberedList(listItems) : .bulletList(listItems))
            listItems = []
        }

        /// Any non-list line ends an open list; any non-prose line flushes prose.
        func flushAll() {
            flushProse()
            flushList()
        }

        for line in markdown.components(separatedBy: "\n") {
            if inCode {
                if line.hasPrefix("```") {
                    var filename: String? = nil
                    var body = codeLines
                    if let first = body.first, first.hasPrefix("// "), first.hasSuffix(".swift") {
                        filename = String(first.dropFirst(3))
                        body = Array(body.dropFirst())
                    }
                    segments.append(.code(filename: filename, language: codeLang,
                                          body: body.joined(separator: "\n")))
                    codeLines = []
                    inCode = false
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if line.hasPrefix("```") {
                flushAll()
                codeLang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if codeLang.isEmpty { codeLang = "swift" }
                inCode = true
            } else if line.hasPrefix("> KEY:") {
                flushAll()
                segments.append(.keyIdea(
                    String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)))
            } else if let title = headingTitle(line) {
                flushAll()
                segments.append(.heading(title))
            } else if let item = bulletItem(line) {
                flushProse()
                if !listItems.isEmpty && listIsNumbered { flushList() }
                listIsNumbered = false
                listItems.append(item)
            } else if let item = numberedItem(line) {
                flushProse()
                if !listItems.isEmpty && !listIsNumbered { flushList() }
                listIsNumbered = true
                listItems.append(item)
            } else {
                flushList()
                proseLines.append(line)
            }
        }
        if inCode {
            // Unterminated fence — keep the text rather than dropping it.
            segments.append(.code(filename: nil, language: codeLang,
                                  body: codeLines.joined(separator: "\n")))
        }
        flushAll()
        return segments
    }

    // MARK: Line classifiers

    private static func headingTitle(_ line: String) -> String? {
        for marker in ["### ", "## ", "# "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func bulletItem(_ line: String) -> String? {
        for marker in ["- ", "* "] where line.hasPrefix(marker) {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// Matches `1. `, `12. ` etc. The authored number is discarded — the reader
    /// numbers from position, so non-contiguous authoring still renders correctly.
    private static func numberedItem(_ line: String) -> String? {
        guard let dot = line.firstIndex(of: "."),
              line.index(after: dot) < line.endIndex,
              line[line.index(after: dot)] == " " else { return nil }
        let digits = line[line.startIndex..<dot]
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        return String(line[line.index(dot, offsetBy: 2)...])
            .trimmingCharacters(in: .whitespaces)
    }
}
