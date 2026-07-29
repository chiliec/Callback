import Testing
import SwiftData
@testable import Callback
import AppCore

// Consolidated SwiftData tests in a single serialized suite to prevent concurrent ModelContainer crashes.
// All SwiftData-dependent tests must run in the same process to avoid simulator crashes from concurrent initialization.

@Suite(.serialized)
@MainActor
struct SwiftDataTests {

    // MARK: - DrillCompletion Tests

    @Test("DrillCompletion::saveCreatesAnswerRecordAndUpdatesMastery")
    func drillCompletionSaveCreatesAnswerRecordAndUpdatesMastery() throws {
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

    @Test("DrillCompletion::saveRecordsWrongAnswerAndSetsMasteryToZero")
    func drillCompletionSaveRecordsWrongAnswerAndSetsMasteryToZero() throws {
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

    // MARK: - MockCompletion Tests

    private func seedTopicsAndProfile(context: ModelContext) throws -> (Topic, Topic, UserProfile) {
        let opt0 = Option(text: "A", isMonospaced: false, order: 0)
        let opt1 = Option(text: "B", isMonospaced: false, order: 1)
        let q1 = Question(id: "q1", kind: .multipleChoice, prompt: "P1",
                          explanation: "E1", correctIndex: 0, options: [opt0, opt1])
        let q2 = Question(id: "q2", kind: .multipleChoice, prompt: "P2",
                          explanation: "E2", correctIndex: 0,
                          options: [Option(text: "A", isMonospaced: false, order: 0),
                                    Option(text: "B", isMonospaced: false, order: 1)])
        let swift = Topic(id: "swift", name: "Swift", section: .fundamentals,
                          symbolName: "swift", colorToken: "swift", order: 0)
        let behavioral = Topic(id: "behavioral", name: "Behavioral", section: .craft,
                               symbolName: "message", colorToken: "behavioral", order: 1)
        q1.topic = swift
        q2.topic = behavioral
        swift.questions = [q1]
        behavioral.questions = [q2]
        let profile = UserProfile()
        context.insert(swift)
        context.insert(behavioral)
        context.insert(profile)
        try context.save()
        return (swift, behavioral, profile)
    }

    @Test("MockCompletion::saveCreatesSessionEntity")
    func mockCompletionSaveCreatesSessionEntity() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let (swift, behavioral, profile) = try seedTopicsAndProfile(context: context)
        let qs = [swift.questions[0], behavioral.questions[0]]
        let ms = MockSession(sessionKind: .mock, level: .mid, questions: qs, totalSeconds: 2700)
        ms.pick(0) // correct for q1

        let result = try MockCompletion.save(mockSession: ms, profile: profile, context: context)

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 1)
        #expect(sessions[0].kind == .mock)
        #expect(sessions[0].level == .mid)
        #expect(sessions[0].durationSeconds == 2700)
        _ = result  // suppress warning
    }

    @Test("MockCompletion::saveInsertsLinkedAnswerRecords")
    func mockCompletionSaveInsertsLinkedAnswerRecords() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let (swift, behavioral, profile) = try seedTopicsAndProfile(context: context)
        let qs = [swift.questions[0], behavioral.questions[0]]
        let ms = MockSession(sessionKind: .mock, level: .mid, questions: qs, totalSeconds: 2700)
        ms.pick(0) // correct for q1
        ms.advance()
        ms.pick(1) // wrong for q2 (correct is 0)

        let result = try MockCompletion.save(mockSession: ms, profile: profile, context: context)

        let records = try context.fetch(FetchDescriptor<AnswerRecord>())
        #expect(records.count == 2)
        let correct = records.filter { $0.isCorrect }
        #expect(correct.count == 1)
        #expect(result.session.answers.count == 2)
    }

    @Test("MockCompletion::saveReturnsCorrectToReviewCount")
    func mockCompletionSaveReturnsCorrectToReviewCount() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let (swift, behavioral, profile) = try seedTopicsAndProfile(context: context)
        let qs = [swift.questions[0], behavioral.questions[0]]
        let ms = MockSession(sessionKind: .mock, level: .mid, questions: qs, totalSeconds: 2700)
        ms.pick(1) // wrong for q1
        ms.advance()
        ms.pick(1) // wrong for q2

        let result = try MockCompletion.save(mockSession: ms, profile: profile, context: context)
        #expect(result.toReviewCount == 2)
    }

    @Test("MockCompletion::saveFlaggedQuestionCountedInToReview")
    func mockCompletionSaveFlaggedQuestionCountedInToReview() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let (swift, _, profile) = try seedTopicsAndProfile(context: context)
        let qs = [swift.questions[0]]
        let ms = MockSession(sessionKind: .mock, level: .mid, questions: qs, totalSeconds: 2700)
        ms.pick(0)   // correct
        ms.toggleFlag()  // but flagged

        let result = try MockCompletion.save(mockSession: ms, profile: profile, context: context)
        #expect(result.toReviewCount == 1)  // flagged counts for review
    }

    @Test("MockCompletion::saveUpdatesProfileReadiness")
    func mockCompletionSaveUpdatesProfileReadiness() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let (swift, _, profile) = try seedTopicsAndProfile(context: context)
        let qs = [swift.questions[0]]
        let ms = MockSession(sessionKind: .mock, level: .mid, questions: qs, totalSeconds: 2700)
        ms.pick(0) // correct

        let result = try MockCompletion.save(mockSession: ms, profile: profile, context: context)
        #expect(profile.readiness > 0)
        _ = result
    }

    @Test("MockCompletion::saveReturnsReadinessDelta")
    func mockCompletionSaveReturnsReadinessDelta() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let (swift, _, profile) = try seedTopicsAndProfile(context: context)
        profile.readiness = 40  // pre-set baseline
        let qs = [swift.questions[0]]
        let ms = MockSession(sessionKind: .mock, level: .mid, questions: qs, totalSeconds: 2700)
        ms.pick(0) // correct

        let result = try MockCompletion.save(mockSession: ms, profile: profile, context: context)
        #expect(result.readinessDelta == profile.readiness - 40)
    }
}
