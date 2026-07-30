import SwiftUI
import AppCore
import DesignSystem

struct PlacementResultsView: View {
    let result: PlacementResult
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                readinessSection
                if !result.solidTopics.isEmpty {
                    topicChipsSection(
                        title: "Looking solid",
                        topics: result.solidTopics,
                        fill: DSColor.green.opacity(0.12),
                        text: DSColor.greenText
                    )
                }
                if !result.focusTopics.isEmpty {
                    topicChipsSection(
                        title: "Focus here first",
                        topics: result.focusTopics,
                        fill: DSColor.orange.opacity(0.12),
                        text: DSColor.orangeText
                    )
                }
                weekPlanSection
            }
            .padding(DSSpacing.sessionInset)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Start day 1") {
                coordinator.showPlacement = false
            }
            .font(DSFont.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DSColor.action)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
            .padding(DSSpacing.sessionInset)
            .background(.bar)
        }
        .navigationTitle("Your results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background(DSColor.groupedBackground.ignoresSafeArea())
    }

    // MARK: Readiness ring

    private var readinessSection: some View {
        GroupedCard {
            HStack(spacing: 20) {
                ProgressRing(value: result.readiness, size: 100, stroke: 8)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Readiness")
                        .font(DSFont.headline)
                    Text("\(result.readiness)%")
                        .font(DSFont.scoreHeadline)
                        .monospacedDigit()
                    Text("Based on your placement answers")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.secondaryLabel)
                }
            }
        }
    }

    // MARK: Topic chips

    private func topicChipsSection(
        title: String,
        topics: [Topic],
        fill: Color,
        text: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title)
            FlowLayout(spacing: 8) {
                ForEach(topics, id: \.id) { topic in
                    topicChip(topic, fill: fill, text: text)
                }
            }
        }
    }

    private func topicChip(_ topic: Topic, fill: Color, text: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: topic.symbolName)
                .font(DSFont.footnote)
            Text(topic.name)
                .font(DSFont.footnote)
        }
        .foregroundStyle(text)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(fill)
        .clipShape(Capsule())
    }

    // MARK: Week plan

    private var weekPlanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Your first week")
            GroupedCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(result.weekPlan.enumerated()), id: \.offset) { i, item in
                        HStack(spacing: 12) {
                            Text("\(i + 1)")
                                .font(DSFont.headline)
                                .monospacedDigit()
                                .foregroundStyle(DSColor.action)
                                .frame(width: 24, alignment: .center)
                            Text(item)
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.label)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: DSSpacing.rowMinHeight)
                        if i < result.weekPlan.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        PlacementResultsView(result: PlacementResult(
            readiness: 62,
            solidTopics: [],
            focusTopics: [],
            weekPlan: ["Day 1 — Swift lesson", "Day 2 — Drill Swift",
                       "Day 3 — Behavioral lesson", "Day 4 — Drill Behavioral",
                       "Day 5 — Mock interview"]
        ))
    }
    .modelContainer(try! AppModelContainer.make(inMemory: true))
    .environment(AppCoordinator())
}
