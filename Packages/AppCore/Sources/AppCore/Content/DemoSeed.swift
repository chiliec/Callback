import Foundation
import SwiftData

/// Populates a realistic, deterministic progress state for App Store screenshots.
/// Never invoked in a shipping launch path — gated behind the `--demo-seed`
/// launch argument in `CallbackApp`, which also forces an in-memory store.
public enum DemoSeed {
    /// Chronological (oldest → newest) correctness per graded topic.
    /// Deliberately uneven so Weak Areas and the by-topic breakdowns have content.
    private static let correctnessByTopic: [String: [Bool]] = [
        "swift":        [false, true,  true,  true,  true],
        "memory":       [false, true,  false, true,  true],
        "concurrency":  [false, false, true,  false, true],
        "swiftui":      [true,  false, true,  false, true],
        "uikit":        [false, true,  false, false, true],
        "networking":  [false, true,  false, true,  true],
        "persistence": [true,  false, true,  false, true],
        "testing":      [false, true,  true,  false, true],
        "architecture": [true,  false, true,  true,  false]
    ]

    /// Behavioral questions have no correct answer — the user self-rates instead.
    /// Deliberately mixed so mastery lands mid-range rather than 0% or 100%.
    private static let behavioralRatings: [SelfRating] = [.weak, .ok, .strong, .ok, .strong]

    /// Topics whose newest answer is flagged, so the review queue shows a
    /// flagged-but-not-wrong item alongside the wrong ones.
    private static let flaggedTopics: Set<String> = ["swift", "behavioral"]

    /// Twelve buckets — `ProfileView` renders `WeeklyBarChart` with `currentIndex: 11`.
    private static let weeklyActivity = [2, 4, 3, 6, 5, 7, 4, 8, 6, 9, 7, 5]

    public static func apply(to context: ModelContext) throws {
        let topics = try context.fetch(
            FetchDescriptor<Topic>(sortBy: [SortDescriptor(\.order)])
        )
        guard !topics.isEmpty else { return }

        // Idempotent: wipe any prior demo progress before re-seeding.
        for session in try context.fetch(FetchDescriptor<Session>()) { context.delete(session) }
        for record in try context.fetch(FetchDescriptor<AnswerRecord>()) { context.delete(record) }

        let engine = ScoringEngine()
        let now = Date()
        var recordsByTopic: [String: [AnswerRecord]] = [:]

        for topic in topics {
            // Self-rated topics have no graded correctness — they use ratings.
            if topic.id == "behavioral" || topic.id == "sysdesign" {
                let ratings = behavioralRatings
                let questions = topic.questions.sorted { $0.id < $1.id }.prefix(ratings.count)

                for (i, question) in questions.enumerated() {
                    let rating = ratings[i]
                    // Oldest answer first; the last one lands today so the streak is live.
                    let daysAgo = ratings.count - 1 - i
                    let isNewest = daysAgo == 0
                    let record = AnswerRecord(
                        questionID: question.id,
                        topicID: topic.id,
                        pickedIndex: nil,
                        isCorrect: Grading.isCorrect(question: question, pickedIndex: nil, selfRating: rating),
                        isFlagged: isNewest && flaggedTopics.contains(topic.id),
                        answeredAt: now.addingTimeInterval(-Double(daysAgo) * 86_400),
                        selfRating: rating
                    )
                    context.insert(record)
                    recordsByTopic[topic.id, default: []].append(record)
                }

                topic.mastery = engine.mastery(
                    fromChronologicalCredit: ratings.prefix(questions.count).map { $0.credit }
                )
                continue
            }

            let correctness = correctnessByTopic[topic.id] ?? []
            let questions = topic.questions.sorted { $0.id < $1.id }.prefix(correctness.count)

            for (i, question) in questions.enumerated() {
                let isCorrect = correctness[i]
                // Oldest answer first; the last one lands today so the streak is live.
                let daysAgo = correctness.count - 1 - i
                let isNewest = daysAgo == 0
                let record = AnswerRecord(
                    questionID: question.id,
                    topicID: topic.id,
                    pickedIndex: pickedIndex(for: question, isCorrect: isCorrect),
                    isCorrect: isCorrect,
                    isFlagged: isNewest && flaggedTopics.contains(topic.id),
                    answeredAt: now.addingTimeInterval(-Double(daysAgo) * 86_400)
                )
                context.insert(record)
                recordsByTopic[topic.id, default: []].append(record)
            }

            topic.mastery = engine.mastery(
                fromChronological: correctness.prefix(questions.count).map { $0 }
            )
        }

        // Two saved topics so the Topics tab's Saved filter has content.
        for topic in topics.prefix(2) { topic.isSaved = true }

        let allRecords = recordsByTopic.values.flatMap { $0 }
        let inputs = topics.map { topic in
            ScoringEngine.TopicReadinessInput(
                mastery: topic.mastery,
                answeredCount: recordsByTopic[topic.id]?.count ?? 0
            )
        }

        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first ?? {
            let new = UserProfile()
            context.insert(new)
            return new
        }()
        profile.hasCompletedPlacement = true
        profile.readiness = engine.readiness(topics: inputs)
        profile.readinessDelta = 4
        profile.answeredCount = allRecords.count
        profile.accuracy = engine.accuracy(
            correct: allRecords.filter(\.isCorrect).count, answered: allRecords.count
        )
        profile.streakDays = engine.streakDays(
            answerDates: allRecords.map(\.answeredAt), now: now, calendar: .current
        )
        profile.weeklyActivity = weeklyActivity

        seedSessions(recordsByTopic: recordsByTopic, now: now, into: context)

        try context.save()
    }

    /// The picked option for a graded question: the correct one, or the next
    /// index along when the answer is meant to be wrong. Nil for behavioral.
    private static func pickedIndex(for question: Question, isCorrect: Bool) -> Int? {
        guard let correct = question.correctIndex else { return nil }
        guard !isCorrect else { return correct }
        guard question.options.count > 1 else { return nil }
        return (correct + 1) % question.options.count
    }

    /// Two finished mock sessions so Practice's recent list and Profile's
    /// session history are not empty.
    private static func seedSessions(
        recordsByTopic: [String: [AnswerRecord]], now: Date, into context: ModelContext
    ) {
        let plan: [(topics: [String], daysAgo: Double, duration: Int)] = [
            (["concurrency", "swiftui"], 1, 900),
            (["swift", "memory"], 3, 600)
        ]
        for entry in plan {
            let answers = entry.topics.flatMap { recordsByTopic[$0] ?? [] }
            guard !answers.isEmpty else { continue }
            let session = Session(
                kind: .mock,
                level: .mid,
                startedAt: now.addingTimeInterval(-entry.daysAgo * 86_400),
                durationSeconds: entry.duration,
                elapsedSeconds: entry.duration,
                answers: answers
            )
            context.insert(session)
        }
    }
}
