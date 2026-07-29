import SwiftUI

public struct SectionHeader: View {
    private let title: String
    public init(_ title: String) { self.title = title }

    public var body: some View {
        Text(title.uppercased())
            .font(DSFont.sectionHeader)
            .foregroundStyle(DSColor.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SectionHeader("Fundamentals").padding()
}
