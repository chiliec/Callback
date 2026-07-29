import SwiftUI

public struct CodeBlock: View {
    private let filename: String
    private let language: String
    private let lines: [String]

    public init(filename: String, language: String, code: String) {
        self.filename = filename
        self.language = language
        self.lines = code.components(separatedBy: "\n")
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DSCode.border)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(DSCode.gutter)
                                .frame(minWidth: 20, alignment: .trailing)
                            highlighted(line)
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(DSCode.background)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous)
                .stroke(DSCode.border, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Text(filename)
            Spacer()
            Text(language)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(DSCode.header)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func highlighted(_ line: String) -> Text {
        let mono = Font.system(size: 13, design: .monospaced)
        let tokens = SwiftSyntaxHighlighter.tokenize(line)
        guard !tokens.isEmpty else { return Text(" ").font(mono) }
        var result = Text("")
        for token in tokens {
            result = result + Text(token.text)
                .font(mono)
                .foregroundColor(SwiftSyntaxHighlighter.color(for: token.kind))
        }
        return result
    }
}

#Preview {
    CodeBlock(
        filename: "main.swift",
        language: "swift",
        code: "let x = 42 // answer\nfunc greet() {\n    print(\"hi\")\n}"
    )
    .padding()
}
