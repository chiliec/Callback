// App/Session/SessionResultsView.swift
import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct SessionResultsView: View {
    let result: MockCompletion.Result
    let onDone: () -> Void

    @Query(sort: \Topic.order) private var topics: [Topic]

    private var session: Session { result.session }

    private var topicBreakdown: [(topic: Topic, correct: Int, total: Int)] {
        let topicMap = Dictionary(uniqueKeysWithValues: topics.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: session.answers, by: \.topicID)
        return grouped.compactMap { topicID, records in
            guard let topic = topicMap[topicID] else { return nil }
            let correct = records.filter { $0.isCorrect }.count
            return (topic: topic, correct: correct, total: records.count)
        }.sorted { $0.topic.order < $1.topic.order }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreSection
                chipsRow
                if !topicBreakdown.isEmpty {
                    topicBreakdownSection
                }
                ctaButtons
            }
            .padding(DSSpacing.sessionInset)
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDone() }
                    .font(DSFont.headline)
            }
        }
    }

    // MARK: Score section

    private var scoreSection: some View {
        VStack(spacing: 12) {
            ProgressRing(value: session.score, size: 100, stroke: 8)
            Text("\(session.correctCount) of \(session.answers.count) correct")
                .font(DSFont.scoreHeadline)
                .monospacedDigit()
            Text(metaLine)
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
    }

    private var metaLine: String {
        "\(session.level.rawValue.capitalized) · \(sessionKindLabel)"
    }

    private var sessionKindLabel: String {
        switch session.kind {
        case .mock:         return "Mock Interview"
        case .rapidFire:    return "Rapid Fire"
        case .codeReview:   return "Code Review"
        case .systemDesign: return "System Design"
        }
    }

    // MARK: Chips

    private var chipsRow: some View {
        HStack(spacing: 12) {
            chip(
                icon: "arrow.up",
                text: "+\(result.readinessDelta) readiness",
                color: DSColor.green,
                textColor: DSColor.greenText
            )
            chip(
                icon: "list.bullet",
                text: "\(result.toReviewCount) to review",
                color: DSColor.orange,
                textColor: DSColor.orangeText
            )
        }
    }

    private func chip(icon: String, text: String, color: Color, textColor: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .font(DSFont.footnote)
                .monospacedDigit()
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: Topic breakdown

    private var topicBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("By Topic")
            GroupedCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(topicBreakdown.enumerated()), id: \.offset) { index, row in
                        topicRow(row)
                        if index < topicBreakdown.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    private func topicRow(_ row: (topic: Topic, correct: Int, total: Int)) -> some View {
        let pct: Double = row.total > 0 ? Double(row.correct) / Double(row.total) : 0
        let isWeak = row.topic.mastery < 65
        return HStack(spacing: 12) {
            IconTile(
                systemName: row.topic.symbolName,
                color: DSColor.topic(row.topic.colorToken)
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(row.topic.name)
                    .font(DSFont.footnote)
                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(DSColor.ringTrack)
                            .frame(height: 4)
                            .clipShape(Capsule())
                        Rectangle()
                            .fill(isWeak ? DSColor.orange : DSColor.action)
                            .frame(width: geo.size.width * pct, height: 4)
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 4)
            }
            Text("\(row.correct)/\(row.total)")
                .font(DSFont.footnote)
                .foregroundStyle(isWeak ? DSColor.orangeText : DSColor.secondaryLabel)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: DSSpacing.rowMinHeight)
    }

    // MARK: CTA buttons

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            if result.toReviewCount > 0 {
                Button("Review \(result.toReviewCount) questions") { onDone() }
                    .font(DSFont.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DSColor.action)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
            }
            Button("Back to practice") { onDone() }
                .font(DSFont.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DSColor.actionTint)
                .foregroundStyle(DSColor.action)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
        }
    }
}

#Preview {
    let container = try! AppModelContainer.make(inMemory: true)
    let context = container.mainContext
    let swift = Topic(id: "swift", name: "Swift", section: .fundamentals,
                      symbolName: "swift", colorToken: "swift", order: 0)
    let q1 = Question(id: "q1", kind: .multipleChoice, prompt: "Q1",
                      explanation: "E1", correctIndex: 0,
                      options: [Option(text: "A", isMonospaced: false, order: 0)])
    q1.topic = swift
    swift.questions = [q1]
    let profile = UserProfile()
    context.insert(swift)
    context.insert(profile)
    let session = Session(kind: .mock, level: .mid, startedAt: Date(), durationSeconds: 2700)
    let record = AnswerRecord(questionID: "q1", topicID: "swift",
                              pickedIndex: 0, isCorrect: true, isFlagged: false, answeredAt: Date())
    record.session = session
    context.insert(session)
    context.insert(record)
    try! context.save()
    let result = MockCompletion.Result(session: session, readinessDelta: 4, toReviewCount: 3)
    return NavigationStack {
        SessionResultsView(result: result, onDone: {})
    }
    .modelContainer(container)
}
