import Foundation
import SwiftData
import AppCore

enum MockCompletion {
    struct Result: Identifiable, Hashable {
        let id = UUID()
        let session: Session
        let readinessDelta: Int
        let toReviewCount: Int

        static func == (lhs: Result, rhs: Result) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    @MainActor
    static func save(
        mockSession: MockSession,
        profile: UserProfile,
        context: ModelContext
    ) throws -> Result {
        let now = Date()
        let engine = ScoringEngine()
        let previousReadiness = profile.readiness

        // 1. Compute toReviewCount: wrong answers OR flagged questions.
        let toReviewCount = (0..<mockSession.questions.count).filter { i in
            let q = mockSession.questions[i]
            let picked = i < mockSession.picks.count ? mockSession.picks[i] : nil
            let flagged = i < mockSession.flags.count ? mockSession.flags[i] : false
            let isCorrect: Bool
            if let correct = q.correctIndex, let p = picked {
                isCorrect = p == correct
            } else {
                isCorrect = false
            }
            return !isCorrect || flagged
        }.count

        // 2. Create Session entity.
        let session = Session(
            kind: mockSession.sessionKind,
            level: mockSession.level,
            startedAt: mockSession.startedAt,
            durationSeconds: mockSession.totalSeconds,
            elapsedSeconds: mockSession.elapsedSeconds
        )
        context.insert(session)

        // 3. Insert AnswerRecords linked to the session and their topic.
        for (i, question) in mockSession.questions.enumerated() {
            let picked = i < mockSession.picks.count ? mockSession.picks[i] : nil
            let flagged = i < mockSession.flags.count ? mockSession.flags[i] : false
            let isCorrect: Bool
            if let correct = question.correctIndex, let p = picked {
                isCorrect = p == correct
            } else {
                isCorrect = false
            }
            let record = AnswerRecord(
                questionID: question.id,
                topicID: question.topic?.id ?? "",
                pickedIndex: picked,
                isCorrect: isCorrect,
                isFlagged: flagged,
                answeredAt: now
            )
            record.session = session
            context.insert(record)
        }

        // 4. Recompute mastery for each topic represented in this session.
        let sessionTopicIDs = Set(mockSession.questions.compactMap { $0.topic?.id })
        for topicID in sessionTopicIDs {
            let topicRecords = (try? context.fetch(
                FetchDescriptor<AnswerRecord>(predicate: #Predicate { $0.topicID == topicID })
            )) ?? []
            let correctness = topicRecords
                .sorted { $0.answeredAt < $1.answeredAt }
                .map { $0.isCorrect }
            let topics = (try? context.fetch(
                FetchDescriptor<Topic>(predicate: #Predicate { $0.id == topicID })
            )) ?? []
            topics.first.map { $0.mastery = engine.mastery(fromChronological: correctness) }
        }

        // 5. Recompute overall readiness from all topics.
        let allTopics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []
        let allRecords = (try? context.fetch(FetchDescriptor<AnswerRecord>())) ?? []
        let countsByTopic = Dictionary(grouping: allRecords, by: \.topicID).mapValues { $0.count }
        let inputs = allTopics.map { t in
            ScoringEngine.TopicReadinessInput(mastery: t.mastery, answeredCount: countsByTopic[t.id] ?? 0)
        }
        let newReadiness = engine.readiness(topics: inputs)
        let delta = newReadiness - previousReadiness
        profile.readiness = newReadiness
        profile.readinessDelta = delta

        // 6. Update profile stats.
        let totalCorrect = allRecords.filter { $0.isCorrect }.count
        profile.answeredCount = allRecords.count
        profile.accuracy = engine.accuracy(correct: totalCorrect, answered: allRecords.count)
        profile.streakDays = engine.streakDays(
            answerDates: allRecords.map { $0.answeredAt },
            now: now,
            calendar: .current
        )

        try context.save()

        return Result(session: session, readinessDelta: delta, toReviewCount: toReviewCount)
    }
}
