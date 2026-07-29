import Testing
@testable import DesignSystem

@Test func tokensReconstructLine() {
    let line = "let x = 42 // note"
    let tokens = SwiftSyntaxHighlighter.tokenize(line)
    #expect(tokens.map(\.text).joined() == line)
}

@Test func classifiesKeyword() {
    let tokens = SwiftSyntaxHighlighter.tokenize("let x = 1")
    #expect(tokens.contains(SyntaxToken(text: "let", kind: .keyword)))
}

@Test func classifiesNumber() {
    let tokens = SwiftSyntaxHighlighter.tokenize("let x = 42")
    #expect(tokens.contains(SyntaxToken(text: "42", kind: .number)))
}

@Test func classifiesComment() {
    let tokens = SwiftSyntaxHighlighter.tokenize("x = 1 // hi")
    #expect(tokens.contains { $0.kind == .comment && $0.text.contains("// hi") })
}

@Test func classifiesString() {
    let tokens = SwiftSyntaxHighlighter.tokenize("let s = \"hello\"")
    #expect(tokens.contains(SyntaxToken(text: "\"hello\"", kind: .string)))
}

@Test func classifiesTypeByCapitalization() {
    let tokens = SwiftSyntaxHighlighter.tokenize("var p = Point()")
    #expect(tokens.contains(SyntaxToken(text: "Point", kind: .type)))
}
