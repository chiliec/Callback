import SwiftUI

public struct ProgressRing: View {
    private let value: Int
    private let size: CGFloat
    private let stroke: CGFloat
    private let tint: Color
    private let showsValue: Bool
    private let accessibilityLabel: String

    public init(value: Int, size: CGFloat, stroke: CGFloat,
                tint: Color = DSColor.action, showsValue: Bool = true,
                accessibilityLabel: String = "Progress") {
        self.value = value
        self.size = size
        self.stroke = stroke
        self.tint = tint
        self.showsValue = showsValue
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(DSColor.ringTrack, lineWidth: stroke)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, value))) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsValue {
                Text("\(value)")
                    .font(.system(size: size * 0.32, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(DSColor.label)
                    .dynamicTypeSize(.xSmall...DynamicTypeSize.accessibility3)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(value) percent")
    }
}

#Preview {
    HStack(spacing: 20) {
        ProgressRing(value: 76, size: 76, stroke: 7)
        ProgressRing(value: 54, size: 68, stroke: 7, tint: DSColor.orange)
        ProgressRing(value: 67, size: 100, stroke: 8, tint: DSColor.green)
    }
    .padding()
}
