import SwiftUI

public enum SyntaxTokenKind: Sendable {
    case keyword, type, call, string, number, comment, plain
}

public struct SyntaxToken: Equatable, Sendable {
    public let text: String
    public let kind: SyntaxTokenKind
    public init(text: String, kind: SyntaxTokenKind) {
        self.text = text
        self.kind = kind
    }
}

public enum SwiftSyntaxHighlighter {
    private static let keywords: Set<String> = [
        "let", "var", "func", "return", "if", "else", "guard", "for", "while",
        "in", "switch", "case", "default", "struct", "class", "enum", "protocol",
        "extension", "import", "self", "init", "nil", "true", "false", "public",
        "private", "internal", "static", "throws", "try", "async", "await", "some",
        "where", "as", "is", "do", "catch", "defer", "final", "override", "mutating"
    ]

    /// Tokenizes one line. Concatenating `text` reproduces the line exactly.
    public static func tokenize(_ line: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        let chars = Array(line)
        var i = 0

        func appendPlain(_ s: String) {
            guard !s.isEmpty else { return }
            tokens.append(SyntaxToken(text: s, kind: .plain))
        }

        var pending = ""
        while i < chars.count {
            let c = chars[i]

            // Line comment: rest of line.
            if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                appendPlain(pending); pending = ""
                tokens.append(SyntaxToken(text: String(chars[i...]), kind: .comment))
                return tokens
            }

            // String literal.
            if c == "\"" {
                appendPlain(pending); pending = ""
                var s = "\""
                i += 1
                while i < chars.count {
                    s.append(chars[i])
                    if chars[i] == "\"" { i += 1; break }
                    i += 1
                }
                tokens.append(SyntaxToken(text: s, kind: .string))
                continue
            }

            // Identifier / number run.
            if c.isLetter || c == "_" || c.isNumber {
                appendPlain(pending); pending = ""
                var word = ""
                while i < chars.count, chars[i].isLetter || chars[i] == "_" || chars[i].isNumber {
                    word.append(chars[i]); i += 1
                }
                tokens.append(SyntaxToken(text: word, kind: classify(word)))
                continue
            }

            // Everything else accumulates as plain (whitespace, punctuation).
            pending.append(c)
            i += 1
        }
        appendPlain(pending)
        return tokens
    }

    private static func classify(_ word: String) -> SyntaxTokenKind {
        if keywords.contains(word) { return .keyword }
        if let first = word.first, first.isNumber { return .number }
        if let first = word.first, first.isUppercase { return .type }
        return .plain
    }

    public static func color(for kind: SyntaxTokenKind) -> Color {
        switch kind {
        case .keyword: return DSCode.keyword
        case .type:    return DSCode.type
        case .call:    return DSCode.call
        case .string:  return DSCode.string
        case .number:  return DSCode.number
        case .comment: return DSCode.comment
        case .plain:   return DSCode.plain
        }
    }
}
