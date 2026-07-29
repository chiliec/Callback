import SwiftUI

/// One filled action per screen. Full-width blue capsule/rounded button.
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(DSColor.action)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Secondary tinted action.
public struct TintedButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.headline)
            .foregroundStyle(DSColor.action)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(DSColor.actionTint)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
public extension ButtonStyle where Self == TintedButtonStyle {
    static var tinted: TintedButtonStyle { TintedButtonStyle() }
}

#Preview {
    VStack(spacing: 12) {
        Button("Start session") {}.buttonStyle(.primary)
        Button("Back to practice") {}.buttonStyle(.tinted)
    }
    .padding()
}
