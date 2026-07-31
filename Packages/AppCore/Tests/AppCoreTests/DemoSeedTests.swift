import Testing
import SwiftData
import Foundation
@testable import AppCore

@Suite("DemoSeed")
struct DemoSeedTests {
    /// Fresh in-memory store with the shipping content bundle seeded.
    private func makeSeededContext() throws -> ModelContext {
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let profile = UserProfile()
        context.insert(profile)
        let bundle = try ContentLoader.decode(try ContentLoader.bundledContentData())
        ContentLoader.seedIfNeeded(into: context, profile: profile, bundle: bundle)
        try context.save()
        return context
    }

    @Test("produces a profile with mid-range readiness and a visible streak")
    func demoSeedPopulatesProfile() throws {
        let context = try makeSeededContext()

        try DemoSeed.apply(to: context)

        let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profile.hasCompletedPlacement)
        #expect(profile.readiness > 40 && profile.readiness < 85)
        #expect(profile.streakDays >= 3)
        #expect(profile.answeredCount >= 20)
        #expect(profile.weeklyActivity.count == 12)
    }

    @Test("leaves some answers wrong so the review queue is non-empty")
    func demoSeedLeavesReviewItems() throws {
        let context = try makeSeededContext()

        try DemoSeed.apply(to: context)

        let records = try context.fetch(FetchDescriptor<AnswerRecord>())
        #expect(records.contains { !$0.isCorrect })
        #expect(records.contains { $0.isFlagged })
        #expect(ReviewQueue.build(from: records, filter: .all).count >= 3)
        #expect(ReviewQueue.build(from: records, filter: .flagged).count >= 1)
    }

    @Test("spreads mastery unevenly so Weak Areas and saved topics have content")
    func demoSeedProducesUnevenMastery() throws {
        let context = try makeSeededContext()

        try DemoSeed.apply(to: context)

        let topics = try context.fetch(FetchDescriptor<Topic>())
        #expect(topics.contains { $0.isWeak })
        #expect(topics.contains { !$0.isWeak })
        #expect(topics.filter(\.isSaved).count == 2)
        #expect(Set(topics.map(\.mastery)).count > 3)
    }

    @Test("behavioral topic gets a plausible mastery, not 0%")
    func demoSeedGivesBehavioralPlausibleMastery() throws {
        let context = try makeSeededContext()

        try DemoSeed.apply(to: context)

        let topics = try context.fetch(FetchDescriptor<Topic>())
        let behavioral = try #require(topics.first { $0.id == "behavioral" })
        #expect(behavioral.mastery > 0 && behavioral.mastery < 100)

        let records = try context.fetch(
            FetchDescriptor<AnswerRecord>(predicate: #Predicate { $0.topicID == "behavioral" })
        )
        #expect(records.allSatisfy { $0.selfRating != nil })
    }

    @Test("is idempotent — re-applying does not double-count answers")
    func demoSeedIsIdempotent() throws {
        let context = try makeSeededContext()

        try DemoSeed.apply(to: context)
        let first = try context.fetch(FetchDescriptor<AnswerRecord>()).count
        try DemoSeed.apply(to: context)
        let second = try context.fetch(FetchDescriptor<AnswerRecord>()).count

        #expect(first == second)
    }
}
