import SwiftUI

public struct GroupedCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSColor.card)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }
}

#Preview {
    GroupedCard { Text("Card content").font(DSFont.headline) }
        .padding()
        .background(DSColor.groupedBackground)
}
