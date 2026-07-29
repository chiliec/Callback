import SwiftUI

/// 12-week activity bars. Current week highlighted blue, others gray.
public struct WeeklyBarChart: View {
    private let values: [Int]
    private let currentIndex: Int

    public init(values: [Int], currentIndex: Int) {
        self.values = values
        self.currentIndex = currentIndex
    }

    public var body: some View {
        let maxValue = max(values.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(index == currentIndex ? DSColor.action : DSColor.ringTrack)
                    .frame(height: max(4, CGFloat(value) / CGFloat(maxValue) * 80))
            }
        }
        .frame(height: 80)
    }
}

#Preview {
    WeeklyBarChart(values: [2, 5, 3, 8, 1, 6, 4, 7, 9, 2, 5, 6], currentIndex: 11)
        .padding()
}
