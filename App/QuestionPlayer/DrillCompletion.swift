import Foundation
import SwiftData
import AppCore

enum DrillCompletion {
    @MainActor
    static func save(
        session: DrillSession,
        topic: Topic,
        profile: UserProfile,
        context: ModelContext
    ) throws {
        let now = Date()
        let engine = ScoringEngine()

        // 1. Insert AnswerRecords for every question in the session.
        for (i, question) in session.questions.enumerated() {
            let picked = session.picks.indices.contains(i) ? session.picks[i] : nil
            let rating = session.ratings.indices.contains(i) ? session.ratings[i] : nil
            let isCorrect = Grading.isCorrect(question: question, pickedIndex: picked, selfRating: rating)
            let record = AnswerRecord(
                questionID: question.id,
                topicID: topic.id,
                pickedIndex: picked,
                isCorrect: isCorrect,
                isFlagged: false,
                // Sub-second offsets keep the in-drill order intact for the
                // chronological sort below; one shared `now` makes it arbitrary.
                answeredAt: now.addingTimeInterval(Double(i) / 1000),
                selfRating: rating
            )
            context.insert(record)
        }

        // 2. Recompute topic mastery from all its AnswerRecords (includes new inserts).
        let topicID = topic.id
        let topicRecords = (try? context.fetch(
            FetchDescriptor<AnswerRecord>(predicate: #Predicate { $0.topicID == topicID })
        )) ?? []
        let credits = topicRecords
            .sorted { $0.answeredAt < $1.answeredAt }
            .map { $0.credit }
        topic.mastery = engine.mastery(fromChronologicalCredit: credits)

        // 3. Recompute overall readiness from all topics.
        let allTopics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []
        let allRecords = (try? context.fetch(FetchDescriptor<AnswerRecord>())) ?? []
        let countsByTopic = Dictionary(grouping: allRecords, by: \.topicID)
            .mapValues { $0.count }
        let inputs = allTopics.map { t in
            ScoringEngine.TopicReadinessInput(
                mastery: t.mastery,
                answeredCount: countsByTopic[t.id] ?? 0
            )
        }
        let newReadiness = engine.readiness(topics: inputs)
        profile.readinessDelta = newReadiness - profile.readiness
        profile.readiness = newReadiness

        // 4. Update profile stats.
        let totalAnswered = allRecords.count
        let totalCorrect = allRecords.filter { $0.isCorrect }.count
        profile.answeredCount = totalAnswered
        profile.accuracy = engine.accuracy(correct: totalCorrect, answered: totalAnswered)
        profile.streakDays = engine.streakDays(
            answerDates: allRecords.map { $0.answeredAt },
            now: now,
            calendar: .current
        )

        try context.save()
    }
}
