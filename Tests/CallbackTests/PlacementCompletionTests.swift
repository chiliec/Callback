// Tests/CallbackTests/PlacementCompletionTests.swift
import Foundation
import Testing
import SwiftData
@testable import Callback
import AppCore

@Suite("PlacementCompletion")
@MainActor
struct PlacementCompletionTests {

    // MARK: Helpers

    private func makeContainer() throws -> (container: ModelContainer, context: ModelContext) {
        let container = try AppModelContainer.make(inMemory: true)
        return (container, ModelContext(container))
    }

    private func makeTopic(id: String = "t1", name: String = "Swift", order: Int = 0, context: ModelContext) -> Topic {
        let t = Topic(id: id, name: name, section: .fundamentals, symbolName: "swift", colorToken: "swift", order: order)
        context.insert(t)
        return t
    }

    private func makeQuestion(id: String = "q1", topic: Topic, correctIndex: Int = 0) -> Question {
        let q = Question(
            id: id, kind: .multipleChoice, prompt: "Q?", explanation: "E.",
            correctIndex: correctIndex,
            options: [
                Option(text: "A", isMonospaced: false, order: 0),
                Option(text: "B", isMonospaced: false, order: 1)
            ]
        )
        q.topic = topic
        return q
    }

    private func makeProfile(context: ModelContext) -> UserProfile {
        let p = UserProfile()
        context.insert(p)
        return p
    }

    // MARK: Tests

    @Test func allCorrectSeedsHighMastery() throws {
        let (container, context) = try makeContainer()
        _ = container
        let topic = makeTopic(context: context)
        let q1 = makeQuestion(id: "q1", topic: topic, correctIndex: 0)
        let q2 = makeQuestion(id: "q2", topic: topic, correctIndex: 0)
        let profile = makeProfile(context: context)

        let session = PlacementSession(questions: [q1, q2])
        session.pick(0); _ = session.advance()
        session.pick(0); _ = session.advance()

        let result = try PlacementCompletion.save(placement: session, profile: profile, context: context)

        #expect(profile.hasCompletedPlacement == true)
        #expect(topic.mastery > 0)
        #expect(result.readiness >= 0)
    }

    @Test func mixedAnswersMasteryMatchesScoringEngine() throws {
        let (container, context) = try makeContainer()
        _ = container
        let topic = makeTopic(context: context)
        let q1 = makeQuestion(id: "q1", topic: topic, correctIndex: 0)
        let q2 = makeQuestion(id: "q2", topic: topic, correctIndex: 0)
        let q3 = makeQuestion(id: "q3", topic: topic, correctIndex: 0)
        let profile = makeProfile(context: context)

        // correct, wrong, correct
        let session = PlacementSession(questions: [q1, q2, q3])
        session.pick(0); _ = session.advance()
        session.pick(1); _ = session.advance()  // wrong
        session.pick(0); _ = session.advance()

        _ = try PlacementCompletion.save(placement: session, profile: profile, context: context)

        let expected = ScoringEngine().mastery(fromChronological: [true, false, true])
        #expect(topic.mastery == expected)
    }

    @Test func skippedQuestionsInsertNoAnswerRecord() throws {
        let (container, context) = try makeContainer()
        _ = container
        let topic = makeTopic(context: context)
        let q1 = makeQuestion(id: "q1", topic: topic)
        let q2 = makeQuestion(id: "q2", topic: topic)
        let profile = makeProfile(context: context)

        let session = PlacementSession(questions: [q1, q2])
        session.skip()  // q1 skipped
        session.pick(0); _ = session.advance()  // q2 answered

        _ = try PlacementCompletion.save(placement: session, profile: profile, context: context)

        let records = try context.fetch(FetchDescriptor<AnswerRecord>())
        #expect(records.count == 1)
        #expect(records.first?.questionID == "q2")
    }

    @Test func ratedBehavioralQuestionRecordsAnAnswer() throws {
        let (container, context) = try makeContainer()
        _ = container
        let topic = makeTopic(context: context)
        let q1 = Question(id: "q1", kind: .behavioral, prompt: "Tell me about a time...",
                           explanation: "E.", correctIndex: nil, rubric: "STAR structure.")
        q1.topic = topic
        let profile = makeProfile(context: context)

        let session = PlacementSession(questions: [q1])
        session.rate(.ok)
        _ = session.advance()

        _ = try PlacementCompletion.save(placement: session, profile: profile, context: context)

        let records = try context.fetch(FetchDescriptor<AnswerRecord>())
        #expect(records.count == 1)
        #expect(records.first?.selfRating == .ok)
        #expect(records.first?.isCorrect == true)
    }

    @Test func skippedBehavioralQuestionRecordsNothing() throws {
        let (container, context) = try makeContainer()
        _ = container
        let topic = makeTopic(context: context)
        let q1 = Question(id: "q1", kind: .behavioral, prompt: "Tell me about a time...",
                           explanation: "E.", correctIndex: nil, rubric: "STAR structure.")
        q1.topic = topic
        let profile = makeProfile(context: context)

        let session = PlacementSession(questions: [q1])
        session.rate(.strong)
        session.skip()  // skip clears the rating — genuinely no record

        _ = try PlacementCompletion.save(placement: session, profile: profile, context: context)

        let records = try context.fetch(FetchDescriptor<AnswerRecord>())
        #expect(records.isEmpty)
    }

    @Test func solidFocusSplitAtSixtyFive() throws {
        let (container, context) = try makeContainer()
        _ = container
        let t1 = makeTopic(id: "t1", name: "Swift", order: 0, context: context)
        let t2 = makeTopic(id: "t2", name: "Behavioral", order: 1, context: context)

        // All correct for t1 → high mastery; no answers for t2 → mastery 0
        let q1 = makeQuestion(id: "q1", topic: t1, correctIndex: 0)
        let profile = makeProfile(context: context)

        let session = PlacementSession(questions: [q1])
        session.pick(0); _ = session.advance()

        // Seed many correct answers for t1 to push mastery above 65
        for i in 0..<10 {
            let r = AnswerRecord(questionID: "pre\(i)", topicID: "t1",
                                 pickedIndex: 0, isCorrect: true,
                                 isFlagged: false, answeredAt: Date().addingTimeInterval(Double(-100 + i)))
            context.insert(r)
        }
        t1.mastery = 80

        let result = try PlacementCompletion.save(placement: session, profile: profile, context: context)

        // t2 has no answers → mastery 0 → focus
        #expect(result.focusTopics.contains(where: { $0.id == "t2" }))
    }

    @Test func readinessEqualsScoringEngineOutput() throws {
        let (container, context) = try makeContainer()
        _ = container
        let topic = makeTopic(context: context)
        let q1 = makeQuestion(id: "q1", topic: topic, correctIndex: 0)
        let profile = makeProfile(context: context)

        let session = PlacementSession(questions: [q1])
        session.pick(0); _ = session.advance()

        let result = try PlacementCompletion.save(placement: session, profile: profile, context: context)

        let allTopics = try context.fetch(FetchDescriptor<Topic>())
        let allRecords = try context.fetch(FetchDescriptor<AnswerRecord>())
        let counts = Dictionary(grouping: allRecords, by: \.topicID).mapValues { $0.count }
        let inputs = allTopics.map {
            ScoringEngine.TopicReadinessInput(mastery: $0.mastery, answeredCount: counts[$0.id] ?? 0)
        }
        let expected = ScoringEngine().readiness(topics: inputs)
        #expect(result.readiness == expected)
    }
}
