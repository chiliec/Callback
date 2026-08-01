import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct TopicDetailView: View {
    let topic: Topic
    @Query private var profiles: [UserProfile]
    @State private var drillSession: DrillSession?

    private var profile: UserProfile? { profiles.first }

    private var sortedLessons: [Lesson] {
        topic.lessons.sorted { $0.order < $1.order }
    }

    private func questionCount(for kind: QuestionKind) -> Int {
        topic.questions.filter { $0.kind == kind }.count
    }

    var body: some View {
        List {
            masteryCard
            lessonsSection
            questionBankSection
        }
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.large)
        .background(DSColor.groupedBackground.ignoresSafeArea())
        .navigationDestination(item: $drillSession) { session in
            if let profile {
                QuestionPlayerView(session: session, topic: topic, profile: profile)
            } else {
                // Profile not yet available — pop immediately rather than showing a blank screen.
                Color.clear.onAppear { drillSession = nil }
            }
        }
        .navigationDestination(for: Lesson.self) { lesson in
            LessonReaderView(lesson: lesson)
        }
    }

    // MARK: Mastery card

    private var masteryCard: some View {
        Section {
            GroupedCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 16) {
                        ProgressRing(
                            value: topic.mastery,
                            size: 68,
                            stroke: 7,
                            tint: topic.isWeak ? DSColor.orange : DSColor.green
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.isWeak ? "Below target" : "On track")
                                .font(DSFont.headline)
                            Text("Target 65% for offers")
                                .font(DSFont.footnote)
                                .foregroundStyle(DSColor.secondaryLabel)
                        }
                        Spacer()
                    }
                    if !topic.questions.isEmpty {
                        Button {
                            let sorted = topic.questions.sorted { $0.id < $1.id }
                            drillSession = DrillSession(questions: sorted)
                        } label: {
                            Text("Practice \(topic.questions.count) question\(topic.questions.count == 1 ? "" : "s")")
                                .font(DSFont.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(DSColor.action)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(profile == nil)
                        .accessibilityIdentifier("topic-practice-cta")
                    }
                }
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
        }
    }

    // MARK: Lessons

    @ViewBuilder private var lessonsSection: some View {
        if !sortedLessons.isEmpty {
            Section(header: SectionHeader("Lessons")) {
                ForEach(Array(sortedLessons.enumerated()), id: \.element.id) { index, lesson in
                    NavigationLink(value: lesson) {
                        HStack(spacing: 12) {
                            Image(systemName: lesson.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(lesson.isComplete ? DSColor.green : DSColor.tertiaryLabel)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title).font(DSFont.body)
                                Text("\(lesson.estimatedMinutes) min")
                                    .font(DSFont.footnote)
                                    .foregroundStyle(DSColor.secondaryLabel)
                            }
                        }
                        .frame(minHeight: DSSpacing.rowMinHeight)
                    }
                    .accessibilityIdentifier("lesson-row-\(index)")
                }
            }
        }
    }

    // MARK: Question bank

    private var questionBankSection: some View {
        Section(header: SectionHeader("Question Bank")) {
            questionBankRow(kind: .multipleChoice, label: "Multiple choice",
                            symbol: "checkmark.circle")
            questionBankRow(kind: .code, label: "Code",
                            symbol: "chevron.left.forwardslash.chevron.right")
            questionBankRow(kind: .behavioral, label: "Behavioral",
                            symbol: "message")
            questionBankRow(kind: .systemDesign, label: "System design",
                            symbol: "point.3.connected.trianglepath.dotted")
        }
    }

    private func questionBankRow(kind: QuestionKind, label: String, symbol: String) -> some View {
        let count = questionCount(for: kind)
        return HStack {
            Image(systemName: symbol)
                .foregroundStyle(DSColor.secondaryLabel)
                .frame(width: 24)
            Text(label).font(DSFont.body)
            Spacer()
            Text("\(count)")
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.secondaryLabel)
                .monospacedDigit()
        }
        .frame(minHeight: DSSpacing.rowMinHeight)
        .opacity(count == 0 ? 0.4 : 1)
    }
}

#Preview {
    let topic = Topic(
        id: "swift", name: "Swift", section: .fundamentals,
        symbolName: "swift", colorToken: "swift", order: 0, mastery: 42
    )
    return NavigationStack {
        TopicDetailView(topic: topic)
    }
    .modelContainer(try! AppModelContainer.make(inMemory: true))
}
