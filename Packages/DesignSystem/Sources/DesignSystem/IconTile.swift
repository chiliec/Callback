import SwiftUI

public struct IconTile: View {
    private let systemName: String
    private let color: Color
    private let size: CGFloat
    private let cornerRadius: CGFloat

    public init(systemName: String, color: Color, size: CGFloat = 30,
                cornerRadius: CGFloat = DSRadius.tile) {
        self.systemName = systemName
        self.color = color
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.5, weight: .regular))
                    .foregroundStyle(.white)
            )
    }
}

#Preview {
    HStack {
        IconTile(systemName: "swift", color: DSColor.topic("swift"))
        IconTile(systemName: "message", color: DSColor.topic("behavioral"))
        IconTile(systemName: "curlybraces", color: DSColor.action, size: 36, cornerRadius: DSRadius.tileLarge)
    }
    .padding()
}
