import SwiftUI

public struct CodeBlock: View {
    private let filename: String
    private let language: String
    private let lines: [String]

    /// Which edges have more code scrolled off-screen. Drives the fade cues so a
    /// wide snippet doesn't just clip at the border with no hint it can scroll.
    private struct ScrollEdges: Equatable { var leading = false; var trailing = false }
    @State private var edges = ScrollEdges()

    private static let fadeWidth: CGFloat = 28

    public init(filename: String, language: String, code: String) {
        self.filename = filename
        self.language = language
        self.lines = code.components(separatedBy: "\n")
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DSCode.border)
            scrollWithFades
        }
        .background(DSCode.background)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous)
                .stroke(DSCode.border, lineWidth: 1)
        )
        // Monospaced code doesn't benefit from AX sizes — clamp so layout stays usable.
        .dynamicTypeSize(.xSmall...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Code sample")
        .accessibilityValue(lines.joined(separator: "\n"))
    }

    private var codeScroll: some View {
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

    // `onScrollGeometryChange` needs iOS 18 / macOS 15. iOS is always new enough;
    // the guard is only so the package still builds on the macOS test host.
    @ViewBuilder private var scrollWithFades: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            codeScroll
                .onScrollGeometryChange(for: ScrollEdges.self) { geo in
                    let offset = geo.contentOffset.x
                    let maxOffset = geo.contentSize.width - geo.containerSize.width
                    return ScrollEdges(leading: offset > 0.5,
                                       trailing: offset < maxOffset - 0.5)
                } action: { _, new in
                    edges = new
                }
                .overlay(alignment: .leading) { edgeFade(.leading).opacity(edges.leading ? 1 : 0) }
                .overlay(alignment: .trailing) { edgeFade(.trailing).opacity(edges.trailing ? 1 : 0) }
                .animation(.easeInOut(duration: 0.15), value: edges)
        } else {
            codeScroll
        }
    }

    private func edgeFade(_ edge: HorizontalEdge) -> some View {
        LinearGradient(
            colors: [DSCode.background, DSCode.background.opacity(0)],
            startPoint: edge == .leading ? .leading : .trailing,
            endPoint: edge == .leading ? .trailing : .leading
        )
        .frame(width: Self.fadeWidth)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
        code: "let x = 42 // answer\nfunc greet(name: String, greeting: String = \"Hello\") -> String {\n    return \"\\(greeting), \\(name)! Welcome aboard.\"\n}"
    )
    .padding()
}
