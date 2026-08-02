import SwiftUI
import AppCore
import DesignSystem

/// Behavioral questions have no gradable answer: reveal the rubric, then let the
/// user grade themselves against it.
struct SelfAssessCard: View {
    let rubric: String
    let isRevealed: Bool
    let selection: SelfRating?
    let onReveal: () -> Void
    let onRate: (SelfRating) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if isRevealed {
            GroupedCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Guidance")
                        .font(DSFont.headline)
                    // Primary, not secondary: this is the model answer the whole
                    // screen exists to deliver. System design rubrics run 10-14
                    // lines, and in secondary grey they read as disabled text —
                    // roughly 3.5:1 against the card, under the 4.5:1 that body
                    // copy needs.
                    Text(rubric)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.label)
                    ratingButtons
                }
            }
        } else {
            GroupedCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Answer out loud, then check yourself.")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.secondaryLabel)
                    Button("Show model answer", action: onReveal)
                        .font(DSFont.headline)
                        .accessibilityIdentifier("reveal-guidance-button")
                }
            }
        }
    }

    @ViewBuilder
    private var ratingButtons: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(SelfRating.allCases, id: \.self, content: ratingButton)
            }
        } else {
            HStack(spacing: 8) {
                ForEach(SelfRating.allCases, id: \.self, content: ratingButton)
            }
        }
    }

    private func ratingButton(_ rating: SelfRating) -> some View {
        let isSelected = selection == rating
        return Button(rating.label) { onRate(rating) }
            .font(DSFont.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? DSColor.action : DSColor.fill)
            .foregroundStyle(isSelected ? .white : DSColor.label)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
            .accessibilityIdentifier("self-rate-\(rating.rawValue)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var rating: SelfRating? = nil
    @Previewable @State var revealed = false
    return VStack(spacing: 16) {
        SelfAssessCard(
            rubric: "Look for a clear situation, the action taken, and a measurable result.",
            isRevealed: revealed,
            selection: rating,
            onReveal: { revealed = true },
            onRate: { rating = $0 }
        )
    }
    .padding()
    .background(DSColor.groupedBackground)
}
