import Foundation
import SwiftData
import AppCore

struct PlacementResult: Hashable {
    let readiness: Int
    let solidTopics: [Topic]
    let focusTopics: [Topic]
    let weekPlan: [String]

    func hash(into hasher: inout Hasher) { hasher.combine(readiness); hasher.combine(weekPlan) }
    static func == (lhs: PlacementResult, rhs: PlacementResult) -> Bool {
        lhs.readiness == rhs.readiness && lhs.weekPlan == rhs.weekPlan
    }
}

enum PlacementCompletion {
    @MainActor
    static func save(
        placement: PlacementSession,
        profile: UserProfile,
        context: ModelContext
    ) throws -> PlacementResult {
        let now = Date()
        let engine = ScoringEngine()
        let previousReadiness = profile.readiness

        // 1. Insert AnswerRecords for answered questions (skip = no record).
        for (i, question) in placement.questions.enumerated() {
            guard let picked = placement.picks.indices.contains(i) ? placement.picks[i] : nil else {
                continue  // skipped — no record
            }
            let isCorrect: Bool
            if let correct = question.correctIndex {
                isCorrect = picked == correct
            } else {
                isCorrect = false  // behavioral
            }
            let record = AnswerRecord(
                questionID: question.id,
                topicID: question.topic?.id ?? "",
                pickedIndex: picked,
                isCorrect: isCorrect,
                isFlagged: false,
                answeredAt: now
            )
            context.insert(record)
        }

        // 2. Recompute mastery for each answered topic.
        let answeredTopicIDs = Set(
            placement.questions.indices.compactMap { i -> String? in
                guard placement.picks.indices.contains(i),
                      placement.picks[i] != nil else { return nil }
                return placement.questions[i].topic?.id
            }
        )
        for topicID in answeredTopicIDs {
            let topicRecords = (try? context.fetch(
                FetchDescriptor<AnswerRecord>(predicate: #Predicate { $0.topicID == topicID })
            )) ?? []
            let correctness = topicRecords
                .sorted { $0.answeredAt < $1.answeredAt }
                .map { $0.isCorrect }
            let matchingTopics = (try? context.fetch(
                FetchDescriptor<Topic>(predicate: #Predicate { $0.id == topicID })
            )) ?? []
            matchingTopics.first.map { $0.mastery = engine.mastery(fromChronological: correctness) }
        }

        // 3. Recompute overall readiness.
        let allTopics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []
        let allRecords = (try? context.fetch(FetchDescriptor<AnswerRecord>())) ?? []
        let countsByTopic = Dictionary(grouping: allRecords, by: \.topicID).mapValues { $0.count }
        let inputs = allTopics.map {
            ScoringEngine.TopicReadinessInput(mastery: $0.mastery, answeredCount: countsByTopic[$0.id] ?? 0)
        }
        let newReadiness = engine.readiness(topics: inputs)
        profile.readinessDelta = newReadiness - previousReadiness
        profile.readiness = newReadiness

        // 4. Update profile stats.
        let totalCorrect = allRecords.filter { $0.isCorrect }.count
        profile.answeredCount = allRecords.count
        profile.accuracy = engine.accuracy(correct: totalCorrect, answered: allRecords.count)
        profile.streakDays = engine.streakDays(
            answerDates: allRecords.map { $0.answeredAt },
            now: now,
            calendar: .current
        )

        // 5. Mark placement complete.
        profile.hasCompletedPlacement = true

        try context.save()

        // 6. Build result.
        let solid = allTopics.filter { $0.mastery >= 65 }.sorted { $0.order < $1.order }
        let focus = allTopics.filter { $0.mastery < 65 }.sorted { $0.mastery < $1.mastery }
        let weekPlan = makeWeekPlan(solid: solid, focus: focus)

        return PlacementResult(
            readiness: newReadiness,
            solidTopics: solid,
            focusTopics: focus,
            weekPlan: weekPlan
        )
    }

    private static func makeWeekPlan(solid: [Topic], focus: [Topic]) -> [String] {
        let allByFocus = focus + solid
        var plan: [String] = []
        var day = 1
        for topic in allByFocus.prefix(3) {
            plan.append("Day \(day) — \(topic.name) lesson")
            day += 1
            plan.append("Day \(day) — Drill \(topic.name)")
            day += 1
            if plan.count >= 5 { break }
        }
        if plan.isEmpty {
            plan = ["Day 1 — Review your first topic", "Day 2 — Take a timed drill",
                    "Day 3 — Read a lesson", "Day 4 — Mock interview", "Day 5 — Review wrongs"]
        }
        return Array(plan.prefix(5))
    }
}
