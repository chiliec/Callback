import Testing
import SwiftData
import Foundation
@testable import AppCore

@Test func seededGeneratorIsReproducible() {
    var a = SeededRandomNumberGenerator(seed: 42)
    var b = SeededRandomNumberGenerator(seed: 42)
    let left = (0..<8).map { _ in a.next() }
    let right = (0..<8).map { _ in b.next() }
    #expect(left == right)
}

@Test func seededGeneratorDiffersBySeed() {
    var a = SeededRandomNumberGenerator(seed: 1)
    var b = SeededRandomNumberGenerator(seed: 2)
    #expect(a.next() != b.next())
}

// MARK: Fixtures

@MainActor
private func makeTopic(
    id: String, order: Int, kinds: [(QuestionKind, Level)], in context: ModelContext
) -> Topic {
    let topic = Topic(id: id, name: id.capitalized, section: .fundamentals,
                      symbolName: "swift", colorToken: id, order: order)
    context.insert(topic)
    for (i, pair) in kinds.enumerated() {
        let (kind, level) = pair
        let q = Question(
            id: "\(id)-q\(i)", kind: kind, prompt: "P\(i)", explanation: "E",
            correctIndex: kind.isSelfRated ? nil : 0,
            rubric: kind.isSelfRated ? "R" : nil,
            level: level,
            codeSnippet: kind == .code
                ? CodeSnippet(filename: "F.swift", language: "swift", code: "let x = 1")
                : nil,
            options: kind.isSelfRated
                ? []
                : [Option(text: "a", isMonospaced: false, order: 0),
                   Option(text: "b", isMonospaced: false, order: 1)]
        )
        q.topic = topic
        topic.questions.append(q)
    }
    return topic
}

// MARK: Eligibility

@MainActor
@Test func rapidFireTakesOnlyMultipleChoiceWithoutSnippet() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0, kinds: [
        (.multipleChoice, .mid), (.code, .mid), (.behavioral, .mid), (.systemDesign, .mid)
    ], in: context)
    let eligible = QuestionSelector.eligible(t.questions, for: .rapidFire)
    #expect(eligible.count == 1)
    #expect(eligible.allSatisfy { $0.kind == .multipleChoice && $0.codeSnippet == nil })
}

@MainActor
@Test func codeReviewTakesOnlyCodeQuestions() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0, kinds: [
        (.multipleChoice, .mid), (.code, .mid), (.behavioral, .mid)
    ], in: context)
    let eligible = QuestionSelector.eligible(t.questions, for: .codeReview)
    #expect(eligible.map(\.kind) == [.code])
}

@MainActor
@Test func systemDesignDrillTakesOnlySystemDesignQuestions() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "sysdesign", order: 0, kinds: [
        (.multipleChoice, .mid), (.behavioral, .mid), (.systemDesign, .mid)
    ], in: context)
    let eligible = QuestionSelector.eligible(t.questions, for: .systemDesign)
    #expect(eligible.map(\.kind) == [.systemDesign])
}

@MainActor
@Test func mockTakesEveryKind() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0, kinds: [
        (.multipleChoice, .mid), (.code, .mid), (.behavioral, .mid), (.systemDesign, .mid)
    ], in: context)
    #expect(QuestionSelector.eligible(t.questions, for: .mock).count == 4)
}

// MARK: Level filtering and widening

@MainActor
@Test func selectPrefersExactLevel() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0, kinds: [
        (.multipleChoice, .junior), (.multipleChoice, .mid),
        (.multipleChoice, .senior), (.multipleChoice, .senior)
    ], in: context)
    var rng = SeededRandomNumberGenerator(seed: 7)
    let picked = QuestionSelector.select(
        from: t.questions, kind: .rapidFire, level: .senior, count: 2, using: &rng)
    #expect(picked.count == 2)
    #expect(picked.allSatisfy { $0.level == .senior })
}

@MainActor
@Test func selectWidensToAdjacentLevelWhenPoolIsShort() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0, kinds: [
        (.multipleChoice, .senior), (.multipleChoice, .mid), (.multipleChoice, .junior)
    ], in: context)
    var rng = SeededRandomNumberGenerator(seed: 7)
    let picked = QuestionSelector.select(
        from: t.questions, kind: .rapidFire, level: .senior, count: 2, using: &rng)
    #expect(picked.count == 2)
    #expect(picked.first?.level == .senior)          // exact tier first
    #expect(picked.last?.level == .mid)              // then the adjacent tier
}

@MainActor
@Test func selectReturnsShortSessionRatherThanEmptyWhenPoolIsTiny() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0, kinds: [(.multipleChoice, .junior)], in: context)
    var rng = SeededRandomNumberGenerator(seed: 7)
    let picked = QuestionSelector.select(
        from: t.questions, kind: .rapidFire, level: .senior, count: 10, using: &rng)
    #expect(picked.count == 1)
}

@MainActor
@Test func selectNeverRepeatsAQuestion() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0, kinds: Array(repeating: (.multipleChoice, .mid), count: 5), in: context)
    var rng = SeededRandomNumberGenerator(seed: 3)
    let picked = QuestionSelector.select(
        from: t.questions, kind: .rapidFire, level: .mid, count: 5, using: &rng)
    #expect(Set(picked.map(\.id)).count == picked.count)
}

@MainActor
@Test func selectReturnsEmptyForZeroCount() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0, kinds: [(.multipleChoice, .mid)], in: context)
    var rng = SeededRandomNumberGenerator(seed: 1)
    #expect(QuestionSelector.select(
        from: t.questions, kind: .rapidFire, level: .mid, count: 0, using: &rng).isEmpty)
}

// MARK: Topic spread

@MainActor
@Test func selectSpreadsAcrossTopicsBeforeRepeatingOne() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let a = makeTopic(id: "aaa", order: 0,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 5), in: context)
    let b = makeTopic(id: "bbb", order: 1,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 5), in: context)
    let c = makeTopic(id: "ccc", order: 2,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 5), in: context)
    var rng = SeededRandomNumberGenerator(seed: 11)
    let picked = QuestionSelector.select(
        from: a.questions + b.questions + c.questions,
        kind: .mock, level: .mid, count: 3, using: &rng)
    #expect(Set(picked.compactMap { $0.topic?.id }) == ["aaa", "bbb", "ccc"])
}

@MainActor
@Test func selectIsDeterministicUnderTheSameSeed() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 10), in: context)
    var r1 = SeededRandomNumberGenerator(seed: 99)
    var r2 = SeededRandomNumberGenerator(seed: 99)
    let first = QuestionSelector.select(from: t.questions, kind: .rapidFire,
                                        level: .mid, count: 4, using: &r1)
    let second = QuestionSelector.select(from: t.questions, kind: .rapidFire,
                                         level: .mid, count: 4, using: &r2)
    #expect(first.map(\.id) == second.map(\.id))
}

// MARK: Freshness

@MainActor
@Test func selectPrefersNeverSeenQuestions() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 3), in: context)
    let now = Date(timeIntervalSince1970: 1_780_000_000)
    var rng = SeededRandomNumberGenerator(seed: 5)
    let picked = QuestionSelector.select(
        from: t.questions, kind: .rapidFire, level: .mid, count: 1,
        lastSeenAt: ["swift-q0": now, "swift-q1": now], using: &rng)
    #expect(picked.map(\.id) == ["swift-q2"])   // the only one never answered
}

@MainActor
@Test func selectPrefersLeastRecentlySeenAmongSeen() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 3), in: context)
    let now = Date(timeIntervalSince1970: 1_780_000_000)
    let day = 86_400.0
    var rng = SeededRandomNumberGenerator(seed: 5)
    let picked = QuestionSelector.select(
        from: t.questions, kind: .rapidFire, level: .mid, count: 1,
        lastSeenAt: ["swift-q0": now,
                     "swift-q1": now.addingTimeInterval(-10 * day),
                     "swift-q2": now.addingTimeInterval(-day)],
        using: &rng)
    #expect(picked.map(\.id) == ["swift-q1"])   // 10 days stale beats 1 day stale
}

@MainActor
@Test func selectAppliesFreshnessWithinEachTopicBucket() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let a = makeTopic(id: "aaa", order: 0,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 2), in: context)
    let b = makeTopic(id: "bbb", order: 1,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 2), in: context)
    let now = Date(timeIntervalSince1970: 1_780_000_000)
    var rng = SeededRandomNumberGenerator(seed: 5)
    // q0 of each topic is freshly answered; q1 of each has never been seen.
    let picked = QuestionSelector.select(
        from: a.questions + b.questions, kind: .mock, level: .mid, count: 2,
        lastSeenAt: ["aaa-q0": now, "bbb-q0": now], using: &rng)
    #expect(Set(picked.map(\.id)) == ["aaa-q1", "bbb-q1"])
}

@MainActor
@Test func freshnessOrderingIsDeterministicUnderTheSameSeed() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 8), in: context)
    let now = Date(timeIntervalSince1970: 1_780_000_000)
    let seen = ["swift-q0": now, "swift-q1": now]   // a tie the RNG must break
    var r1 = SeededRandomNumberGenerator(seed: 77)
    var r2 = SeededRandomNumberGenerator(seed: 77)
    let first = QuestionSelector.select(from: t.questions, kind: .rapidFire, level: .mid,
                                        count: 5, lastSeenAt: seen, using: &r1)
    let second = QuestionSelector.select(from: t.questions, kind: .rapidFire, level: .mid,
                                         count: 5, lastSeenAt: seen, using: &r2)
    #expect(first.map(\.id) == second.map(\.id))
}

@MainActor
@Test func omittingLastSeenSelectsWithoutFreshnessBias() throws {
    // The default `[:]` makes every question equally stale, so selection reduces
    // to the shuffle the other tests in this file rely on.
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 4), in: context)
    var rng = SeededRandomNumberGenerator(seed: 5)
    let picked = QuestionSelector.select(
        from: t.questions, kind: .rapidFire, level: .mid, count: 4, using: &rng)
    #expect(Set(picked.map(\.id)).count == 4)
}

// MARK: availableCount

@MainActor
@Test func availableCountIgnoresLevelBecauseSelectionWidens() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0, kinds: [
        (.code, .junior), (.multipleChoice, .mid)
    ], in: context)
    #expect(QuestionSelector.availableCount(in: t.questions, for: .codeReview) == 1)
    #expect(QuestionSelector.availableCount(in: t.questions, for: .systemDesign) == 0)
}

// MARK: Placement

@MainActor
@Test func placementTakesOneMidQuestionPerTopicInOrder() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let b = makeTopic(id: "bbb", order: 1, kinds: [(.multipleChoice, .mid)], in: context)
    let a = makeTopic(id: "aaa", order: 0, kinds: [(.multipleChoice, .mid)], in: context)
    let picked = QuestionSelector.placementQuestions(from: [b, a], count: 12)
    #expect(picked.compactMap { $0.topic?.id } == ["aaa", "bbb"])  // Topic.order, not argument order
}

@MainActor
@Test func placementFallsBackWhenATopicHasNoMidQuestion() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0, kinds: [(.multipleChoice, .senior)], in: context)
    let picked = QuestionSelector.placementQuestions(from: [t], count: 12)
    #expect(picked.count == 1)
}

@MainActor
@Test func placementIsCappedAtCount() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 30), in: context)
    #expect(QuestionSelector.placementQuestions(from: [t], count: 12).count == 12)
}

@MainActor
@Test func placementIsDeterministic() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "swift", order: 0,
                      kinds: Array(repeating: (.multipleChoice, .mid), count: 20), in: context)
    let first = QuestionSelector.placementQuestions(from: [t], count: 12).map(\.id)
    let second = QuestionSelector.placementQuestions(from: [t], count: 12).map(\.id)
    #expect(first == second)
}

@MainActor
@Test func behavioralDrillTakesOnlyBehavioralQuestions() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "behavioral", order: 0, kinds: [
        (.multipleChoice, .mid), (.behavioral, .mid), (.systemDesign, .mid)
    ], in: context)
    let eligible = QuestionSelector.eligible(t.questions, for: .behavioral)
    #expect(eligible.map(\.kind) == [.behavioral])
}

@MainActor
@Test func behavioralDrillIsAvailableFromTheExistingPool() throws {
    // The 10 shipped behavioral questions already exceed the drill's 6-question
    // draw, so the drill must not render as "Coming soon" in phase 1.
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let t = makeTopic(id: "behavioral", order: 0,
                      kinds: Array(repeating: (.behavioral, .mid), count: 10), in: context)
    #expect(QuestionSelector.availableCount(in: t.questions, for: .behavioral) >= 6)
}
