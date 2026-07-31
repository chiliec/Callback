// App/Practice/PracticeView.swift
import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct PracticeView: View {
    @Query(sort: \Topic.order) private var topics: [Topic]
    @Query(sort: \Session.startedAt, order: .reverse) private var recentSessions: [Session]
    @Query private var answers: [AnswerRecord]

    @State private var selectedLevel: Level = .mid
    @State private var activeMockSession: MockSession? = nil

    private var reviewQueueCount: Int {
        ReviewQueue.build(from: answers, filter: .all).count
    }

    private var allQuestions: [Question] {
        topics.flatMap { $0.questions }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mockCard
                timedDrillsSection
                if reviewQueueCount > 0 {
                    reviewQueueSection
                }
                if !recentSessions.isEmpty {
                    recentSessionsSection
                }
            }
            .padding(.horizontal, DSSpacing.listInset)
            .padding(.vertical, 8)
        }
        .navigationTitle("Practice")
        .background(DSColor.groupedBackground.ignoresSafeArea())
        .fullScreenCover(item: $activeMockSession) { ms in
            MockSessionView(session: ms, onDone: { activeMockSession = nil })
        }
    }

    // MARK: Mock card

    private var mockCard: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mock Interview")
                            .font(DSFont.headline)
                        Text("45 min · \(selectedLevel.rawValue.capitalized)")
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.secondaryLabel)
                    }
                    Spacer()
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(DSColor.action)
                }
                Picker("Level", selection: $selectedLevel) {
                    ForEach(Level.allCases, id: \.self) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                Button("Start session") {
                    startSession(kind: .mock, totalSeconds: 45 * 60, maxQuestions: 12)
                }
                .font(DSFont.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(availableCount(for: .mock) == 0 ? DSColor.action.opacity(0.3) : DSColor.action)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
                .disabled(availableCount(for: .mock) == 0)
            }
        }
    }

    // MARK: Timed drills

    private struct DrillSpec {
        let kind: SessionKind
        let title: String
        let icon: String
        let minutes: Int
        let maxQuestions: Int
    }

    private let drillSpecs: [DrillSpec] = [
        DrillSpec(kind: .rapidFire, title: "Rapid Fire", icon: "bolt", minutes: 10, maxQuestions: 10),
        DrillSpec(kind: .codeReview, title: "Code Review", icon: "chevron.left.forwardslash.chevron.right", minutes: 15, maxQuestions: 8),
        DrillSpec(kind: .systemDesign, title: "System Design", icon: "point.3.connected.trianglepath.dotted", minutes: 20, maxQuestions: 6),
        DrillSpec(kind: .behavioral, title: "Behavioral", icon: "message",
                  minutes: 15, maxQuestions: 6),
    ]

    private var timedDrillsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Timed Drills")
            GroupedCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(drillSpecs.enumerated()), id: \.offset) { index, spec in
                        drillRow(spec)
                        if index < drillSpecs.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }

    // MARK: Review queue section

    private var reviewQueueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Review")
            GroupedCard(padding: 0) {
                NavigationLink(destination: ReviewQueueView()) {
                    HStack(spacing: 12) {
                        IconTile(systemName: "arrow.counterclockwise", color: DSColor.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Review queue")
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.label)
                            Text("\(reviewQueueCount) to review")
                                .font(DSFont.footnote)
                                .foregroundStyle(DSColor.secondaryLabel)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DSColor.secondaryLabel)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: DSSpacing.rowMinHeight)
                    // Same as `drillRow`: the card's background is outside this
                    // link, so the `Spacer()` and chevron need an explicit shape
                    // to be hit-testable.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("review-queue-row")
            }
        }
    }

    private func drillRow(_ spec: DrillSpec) -> some View {
        Button {
            startSession(kind: spec.kind, totalSeconds: spec.minutes * 60, maxQuestions: spec.maxQuestions)
        } label: {
            HStack(spacing: 12) {
                IconTile(systemName: spec.icon, color: DSColor.action)
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.title)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.label)
                    Text(availableCount(for: spec.kind) == 0
                         ? "Coming soon" : "\(spec.minutes) min")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.secondaryLabel)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DSColor.secondaryLabel)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: DSSpacing.rowMinHeight)
            // Without this the `Spacer()` and the chevron are not hit-testable,
            // so only the icon and the title strip respond — most of the row,
            // including the chevron that advertises it as tappable, is dead.
            .contentShape(Rectangle())
            .opacity(availableCount(for: spec.kind) == 0 ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(availableCount(for: spec.kind) == 0)
        .accessibilityIdentifier("drill-row-\(spec.kind.rawValue)")
    }

    // MARK: Recent sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Recent")
            GroupedCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(recentSessions.prefix(5).enumerated()), id: \.element.persistentModelID) { index, session in
                        recentSessionRow(session)
                        if index < min(recentSessions.count, 5) - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    private func recentSessionRow(_ session: Session) -> some View {
        HStack(spacing: 12) {
            scoreChip(session.score)
            VStack(alignment: .leading, spacing: 2) {
                Text(kindLabel(session.kind))
                    .font(DSFont.footnote)
                Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(DSFont.badge)
                    .foregroundStyle(DSColor.secondaryLabel)
            }
            Spacer()
            Text("\(session.correctCount)/\(session.answers.count)")
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.secondaryLabel)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: DSSpacing.rowMinHeight)
    }

    private func scoreChip(_ score: Int) -> some View {
        let (color, textColor): (Color, Color) = {
            if score >= 80 { return (DSColor.green, DSColor.greenText) }
            if score >= 50 { return (DSColor.orange, DSColor.orangeText) }
            return (DSColor.red, DSColor.redText)
        }()
        return Text("\(score)%")
            .font(DSFont.badge)
            .monospacedDigit()
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func kindLabel(_ kind: SessionKind) -> String {
        switch kind {
        case .mock:         return "Mock Interview"
        case .rapidFire:    return "Rapid Fire"
        case .codeReview:   return "Code Review"
        case .systemDesign: return "System Design"
        case .behavioral:   return "Behavioral"
        }
    }

    // MARK: Session factory

    /// Screenshot captures must be reproducible, so `--demo-seed` runs draw from
    /// a fixed seed instead of the system RNG.
    private static let isDemoSeed = ProcessInfo.processInfo.arguments.contains("--demo-seed")

    /// Question id → most recent answer date, so `QuestionSelector` can prefer
    /// questions the user hasn't seen lately. Derived from the `AnswerRecord`s
    /// already queried by this view rather than stored on `Question`, which keeps
    /// the selector pure and adds no schema field.
    private var lastSeenAt: [String: Date] {
        var out: [String: Date] = [:]
        for a in answers {
            if let seen = out[a.questionID] {
                if a.answeredAt > seen { out[a.questionID] = a.answeredAt }
            } else {
                out[a.questionID] = a.answeredAt
            }
        }
        return out
    }

    private func startSession(kind: SessionKind, totalSeconds: Int, maxQuestions: Int) {
        let seen = lastSeenAt
        var questions: [Question]
        if Self.isDemoSeed {
            var rng = SeededRandomNumberGenerator(seed: 20260731)
            questions = QuestionSelector.select(
                from: allQuestions, kind: kind, level: selectedLevel,
                count: maxQuestions, lastSeenAt: seen, using: &rng)
        } else {
            var rng = SystemRandomNumberGenerator()
            questions = QuestionSelector.select(
                from: allQuestions, kind: kind, level: selectedLevel,
                count: maxQuestions, lastSeenAt: seen, using: &rng)
        }
        guard !questions.isEmpty else { return }
        activeMockSession = MockSession(
            sessionKind: kind,
            level: selectedLevel,
            questions: questions,
            totalSeconds: totalSeconds
        )
    }

    private func availableCount(for kind: SessionKind) -> Int {
        QuestionSelector.availableCount(in: allQuestions, for: kind)
    }
}

#Preview {
    NavigationStack {
        PracticeView()
    }
    .modelContainer(try! AppModelContainer.make(inMemory: true))
}
