import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct HomeView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \Topic.order) private var topics: [Topic]
    @Environment(AppCoordinator.self) private var coordinator

    private var profile: UserProfile? { profiles.first }
    private var weakTopics: [Topic] { topics.filter { $0.isWeak } }

    var body: some View {
        @Bindable var coordinator = coordinator
        Group {
            if profile?.hasCompletedPlacement == true {
                normalHomeContent
            } else {
                FirstRunHomeView()
            }
        }
        .navigationTitle("Home")
        .fullScreenCover(isPresented: $coordinator.showPlacement) {
            PlacementQuizView(
                session: PlacementSession(
                    questions: PlacementSession.makeQuestions(from: topics)
                )
            )
            .environment(coordinator)
        }
    }

    private var normalHomeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dateKicker
                readinessCard
                continueCard
                if !weakTopics.isEmpty {
                    weakAreasSection
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

    // MARK: Readiness card

    private var readinessCard: some View {
        GroupedCard {
            HStack(alignment: .top, spacing: 16) {
                ProgressRing(
                    value: profile?.readiness ?? 0,
                    size: 76,
                    stroke: 7
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text("Readiness")
                        .font(DSFont.headline)
                    let delta = profile?.readinessDelta ?? 0
                    Text(delta >= 0 ? "+\(delta) this week" : "\(delta) this week")
                        .font(DSFont.footnote)
                        .foregroundStyle(delta >= 0 ? DSColor.greenText : DSColor.orangeText)
                        .monospacedDigit()
                    Divider()
                    statsGrid
                }
            }
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 0) {
            statCell(value: "\(profile?.streakDays ?? 0)", label: "Streak")
            Divider().frame(height: 32)
            statCell(value: "\(profile?.answeredCount ?? 0)", label: "Answered")
            Divider().frame(height: 32)
            let pct = Int((profile?.accuracy ?? 0) * 100)
            statCell(value: "\(pct)%", label: "Accuracy")
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

    // MARK: Continue card

    private var continueCard: some View {
        Button {
            coordinator.selectedTab = .topics
        } label: {
            GroupedCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Continue")
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.label)
                        Text("Pick a topic to drill")
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.secondaryLabel)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.secondaryLabel)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Weak areas

    private var weakAreasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Weak Areas")
            GroupedCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(weakTopics.enumerated()), id: \.element.id) { index, topic in
                        Button {
                            coordinator.topicsFilter = .weak
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
                                Text("\(topic.mastery)%")
                                    .font(DSFont.footnote)
                                    .foregroundStyle(DSColor.orangeText)
                                    .monospacedDigit()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(DSColor.secondaryLabel)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: DSSpacing.rowMinHeight)
                        }
                        .buttonStyle(.plain)
                        if index < weakTopics.count - 1 {
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
        HomeView()
    }
    .modelContainer(try! AppModelContainer.make(inMemory: true))
    .environment(AppCoordinator())
}
