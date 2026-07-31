import Testing
import Foundation
@testable import AppCore

private let engine = ScoringEngine()   // coverageTarget = 5

@Test func masteryAllCorrectIs100() {
    #expect(engine.mastery(fromChronological: [true, true, true]) == 100)
}

@Test func masteryAllWrongIs0() {
    #expect(engine.mastery(fromChronological: [false, false]) == 0)
}

@Test func masteryEmptyIs0() {
    #expect(engine.mastery(fromChronological: []) == 0)
}

// [wrong(old), correct(new)] -> weights 0.9, 1.0 -> 100*1.0/1.9 = 52.63 -> 53
@Test func masteryRecencyWeighted() {
    #expect(engine.mastery(fromChronological: [false, true]) == 53)
}

@Test func readinessIgnoresUntouchedTopics() {
    let input = [
        ScoringEngine.TopicReadinessInput(mastery: 80, answeredCount: 5),
        ScoringEngine.TopicReadinessInput(mastery: 40, answeredCount: 0)
    ]
    #expect(engine.readiness(topics: input) == 80)
}

@Test func readinessAveragesCoveredTopics() {
    let input = [
        ScoringEngine.TopicReadinessInput(mastery: 80, answeredCount: 5),
        ScoringEngine.TopicReadinessInput(mastery: 40, answeredCount: 5)
    ]
    #expect(engine.readiness(topics: input) == 60)
}

@Test func readinessPartialCoverageWeightsDown() {
    // topic A: mastery 100, answered 5 -> coverage 1.0
    // topic B: mastery 0,   answered 1 -> coverage 0.2
    // (100*1.0 + 0*0.2) / 1.2 = 83.33 -> 83
    let input = [
        ScoringEngine.TopicReadinessInput(mastery: 100, answeredCount: 5),
        ScoringEngine.TopicReadinessInput(mastery: 0, answeredCount: 1)
    ]
    #expect(engine.readiness(topics: input) == 83)
}

@Test func readinessNoCoverageIs0() {
    let input = [ScoringEngine.TopicReadinessInput(mastery: 90, answeredCount: 0)]
    #expect(engine.readiness(topics: input) == 0)
}

@Test func masteryCreditAllWeakIs0() {
    #expect(engine.mastery(fromChronologicalCredit: [0, 0, 0]) == 0)
}

@Test func masteryCreditAllStrongIs100() {
    #expect(engine.mastery(fromChronologicalCredit: [1, 1, 1]) == 100)
}

@Test func masteryCreditAllOkIs50() {
    #expect(engine.mastery(fromChronologicalCredit: [0.5, 0.5, 0.5]) == 50)
}

@Test func masteryCreditAgreesWithBoolVersionOnPureZeroOne() {
    let bools = [false, true, true, false, true]
    let credits = bools.map { $0 ? 1.0 : 0.0 }
    #expect(engine.mastery(fromChronological: bools) == engine.mastery(fromChronologicalCredit: credits))
}

@Test func accuracyGuardsZero() {
    #expect(engine.accuracy(correct: 0, answered: 0) == 0)
    #expect(engine.accuracy(correct: 3, answered: 4) == 0.75)
}

@Test func streakCountsConsecutiveDaysEndingToday() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed instant
    let day: TimeInterval = 86_400
    // answers today, yesterday, two-days-ago, then a gap (skip 3 days ago), then 4 days ago
    let dates = [now, now - day, now - 2*day, now - 4*day]
    #expect(engine.streakDays(answerDates: dates, now: now, calendar: cal) == 3)
}

@Test func streakZeroWhenNoAnswerToday() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let day: TimeInterval = 86_400
    #expect(engine.streakDays(answerDates: [now - day], now: now, calendar: cal) == 0)
}
