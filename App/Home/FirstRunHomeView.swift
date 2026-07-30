import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct FirstRunHomeView: View {
    @Query(sort: \Topic.order) private var topics: [Topic]
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dateKicker
                placeholderReadinessCard
                placementCTACard
                zeroDStats
                if !topics.isEmpty {
                    starterTopicsSection
                }
            }
            .padding(.horizontal, DSSpacing.listInset)
            .padding(.vertical, 8)
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
    }

    // MARK: Date kicker

    private var dateKicker: some View {
        Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()).uppercased())
            .font(DSFont.sectionHeader)
            .foregroundStyle(DSColor.secondaryLabel)
    }

    // MARK: Dashed readiness placeholder

    private var placeholderReadinessCard: some View {
        GroupedCard {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 7, dash: [4, 6]),
                            antialiased: true
                        )
                        .foregroundStyle(DSColor.ringTrack)
                        .frame(width: 76, height: 76)
                    Text("—")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.secondaryLabel)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Readiness")
                        .font(DSFont.headline)
                    Text("Take the placement quiz to get your score.")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.secondaryLabel)
                }
            }
        }
    }

    // MARK: Placement CTA card

    private var placementCTACard: some View {
        Button {
            coordinator.showPlacement = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Placement quiz")
                        .font(DSFont.headline)
                        .foregroundStyle(.white)
                    Text("12 quick questions · ~5 min")
                        .font(DSFont.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DSFont.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(DSSpacing.listInset)
            .background(DSColor.action)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Zeroed stats

    private var zeroDStats: some View {
        GroupedCard {
            HStack(spacing: 0) {
                statCell(value: "0", label: "Streak")
                Divider().frame(height: 32)
                statCell(value: "0", label: "Answered")
                Divider().frame(height: 32)
                statCell(value: "0%", label: "Accuracy")
            }
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DSFont.scoreHeadline)
                .monospacedDigit()
            Text(label)
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Starter topics

    private var starterTopicsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Start with")
            GroupedCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(topics.prefix(4).enumerated()), id: \.element.id) { index, topic in
                        Button {
                            coordinator.selectedTab = .topics
                        } label: {
                            HStack(spacing: 12) {
                                IconTile(
                                    systemName: topic.symbolName,
                                    color: DSColor.topic(topic.colorToken)
                                )
                                Text(topic.name)
                                    .font(DSFont.body)
                                    .foregroundStyle(DSColor.label)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(DSColor.secondaryLabel)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: DSSpacing.rowMinHeight)
                        }
                        .buttonStyle(.plain)
                        if index < min(topics.count, 4) - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FirstRunHomeView()
    }
    .modelContainer(try! AppModelContainer.make(inMemory: true))
    .environment(AppCoordinator())
}
