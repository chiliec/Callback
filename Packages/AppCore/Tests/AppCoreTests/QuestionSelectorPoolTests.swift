import Testing
import SwiftData
import Foundation
@testable import AppCore

/// Pool-coverage invariant over the *real* bundled content: every drill must be
/// able to fill a full session at every level from questions of exactly that
/// level, with `QuestionSelector`'s level-widening fallback never firing.
///
/// The fallback exists so a thin pool degrades to a smaller valid session instead
/// of an empty one — it is a safety net, not a plan. When it fires, a learner who
/// picked "junior" silently gets senior material. That failure is invisible at
/// runtime, so it has to be a test.
///
/// This is the acceptance gate for content volume: it cannot pass until every
/// topic carries enough questions of every kind at every band, which is why it
/// only landed once all 11 topics were authored.
///
/// Headroom at 11 topics, eligible-per-level against the target:
/// `mock` 100–136/12, `rapidFire` 41–108/10, `systemDesign` 9/6, `behavioral`
/// 10–11/6 — and `codeReview` **9/8 at junior**. That last one is the binding
/// constraint: retiring two junior `.code` questions breaks Code Review for
/// junior learners, so add before you remove.
@Suite("Question selector pool coverage")
struct QuestionSelectorPoolTests {

    /// The bundled content, seeded into an in-memory store so the assertions run
    /// against the same `Question` models a drill selects from.
    private func seededQuestions() throws -> [Question] {
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        ContentLoader.seed(try ContentLoader.bundledContent(), into: context)
        try context.save()
        return try context.fetch(FetchDescriptor<Question>())
    }

    @Test func everyDrillFillsAFullSessionAtEveryLevelWithoutWidening() throws {
        let pool = try seededQuestions()
        #expect(!pool.isEmpty, "bundled content seeded no questions")

        for kind in SessionKind.allCases {
            let target = kind.targetQuestionCount
            let eligible = QuestionSelector.eligible(pool, for: kind)

            for level in Level.allCases {
                let atLevel = eligible.filter { $0.level == level }
                #expect(atLevel.count >= target,
                        "\(kind.rawValue) at \(level.rawValue): pool holds \(atLevel.count) eligible questions, needs \(target)")

                // The end-to-end check: a real selection must come back full and
                // entirely on-band. Anything else means a wider tier was tapped.
                var rng = SeededRandomNumberGenerator(seed: 20260804)
                let picked = QuestionSelector.select(
                    from: pool, kind: kind, level: level, count: target, using: &rng)
                #expect(picked.count == target,
                        "\(kind.rawValue) at \(level.rawValue): selected \(picked.count) of \(target)")
                let offBand = picked.filter { $0.level != level }.map(\.id)
                #expect(offBand.isEmpty,
                        "\(kind.rawValue) at \(level.rawValue): widening fired, pulled off-band \(offBand)")
            }
        }
    }
}
