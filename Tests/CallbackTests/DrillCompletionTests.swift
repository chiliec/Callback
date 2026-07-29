import Testing
import SwiftData
@testable import Callback
import AppCore

@Suite("DrillCompletion")
@MainActor
struct DrillCompletionTests {

    @Test func saveCreatesAnswerRecordAndUpdatesMastery() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext

        let opt0 = Option(text: "struct", isMonospaced: true, order: 0)
        let opt1 = Option(text: "class", isMonospaced: false, order: 1)
        let question = Question(
            id: "q1",
            kind: .multipleChoice,
            prompt: "Which is a value type?",
            explanation: "Structs are value types.",
            correctIndex: 0,
            options: [opt0, opt1]
        )
        let topic = Topic(
            id: "swift", name: "Swift", section: .fundamentals,
            symbolName: "swift", colorToken: "swift", order: 0
        )
        question.topic = topic
        topic.questions = [question]
        let profile = UserProfile()
        context.insert(topic)
        context.insert(profile)
        try context.save()

        let session = DrillSession(questions: [question])
        session.pick(0)  // correct answer

        try DrillCompletion.save(session: session, topic: topic, profile: profile, context: context)

        let records = try context.fetch(FetchDescriptor<AnswerRecord>())
        #expect(records.count == 1)
        #expect(records[0].isCorrect == true)
        #expect(records[0].pickedIndex == 0)
        #expect(records[0].questionID == "q1")
        #expect(topic.mastery == 100)
        #expect(profile.answeredCount == 1)
        #expect(profile.accuracy == 1.0)
    }

    @Test func saveRecordsWrongAnswerAndSetsMasteryToZero() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext

        let opt0 = Option(text: "struct", isMonospaced: true, order: 0)
        let opt1 = Option(text: "class", isMonospaced: false, order: 1)
        let question = Question(
            id: "q1",
            kind: .multipleChoice,
            prompt: "Which is a value type?",
            explanation: "Structs are value types.",
            correctIndex: 0,
            options: [opt0, opt1]
        )
        let topic = Topic(
            id: "swift", name: "Swift", section: .fundamentals,
            symbolName: "swift", colorToken: "swift", order: 0
        )
        question.topic = topic
        topic.questions = [question]
        let profile = UserProfile()
        context.insert(topic)
        context.insert(profile)
        try context.save()

        let session = DrillSession(questions: [question])
        session.pick(1)  // wrong answer (correct is 0)

        try DrillCompletion.save(session: session, topic: topic, profile: profile, context: context)

        let records = try context.fetch(FetchDescriptor<AnswerRecord>())
        #expect(records.count == 1)
        #expect(records[0].isCorrect == false)
        #expect(topic.mastery == 0)
        #expect(profile.accuracy == 0.0)
    }
}
