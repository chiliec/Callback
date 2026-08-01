import Testing
import SwiftData
import Foundation
@testable import AppCore

/// `Lesson.positionInTopic` feeds the reader's "Lesson n of m" progress line and
/// its "Up next" row. Before this it lived twice, inline in two SwiftUI
/// `navigationDestination` closures, where only a simulator run could reach it.
@Suite("Lesson position")
struct LessonPositionTests {

    @MainActor
    private func makeTopic(lessonOrders: [Int], in context: ModelContext) -> Topic {
        let topic = Topic(id: "swift", name: "Swift", section: .fundamentals,
                          symbolName: "swift", colorToken: "swift", order: 0)
        context.insert(topic)
        for order in lessonOrders {
            let lesson = Lesson(id: "l\(order)", order: order, title: "Lesson \(order)",
                                estimatedMinutes: 5, body: "Body")
            lesson.topic = topic
            topic.lessons.append(lesson)
        }
        return topic
    }

    @MainActor
    private func lesson(_ id: String, in topic: Topic) throws -> Lesson {
        try #require(topic.lessons.first(where: { $0.id == id }))
    }

    @MainActor
    @Test func firstLessonPointsAtTheSecond() throws {
        let context = ModelContext(try AppModelContainer.make(inMemory: true))
        let topic = makeTopic(lessonOrders: [0, 1, 2], in: context)

        let position = try lesson("l0", in: topic).positionInTopic
        #expect(position.index == 1)
        #expect(position.total == 3)
        #expect(position.next?.id == "l1")
    }

    @MainActor
    @Test func lastLessonHasNothingNext() throws {
        let context = ModelContext(try AppModelContainer.make(inMemory: true))
        let topic = makeTopic(lessonOrders: [0, 1, 2], in: context)

        let position = try lesson("l2", in: topic).positionInTopic
        #expect(position.index == 3)
        #expect(position.total == 3)
        #expect(position.next == nil, "the last lesson must not offer an Up next row")
    }

    /// SwiftData hands back relationships unordered, so position has to come from
    /// `order` — not from however `topic.lessons` happens to be arranged.
    @MainActor
    @Test func positionFollowsOrderNotInsertionOrder() throws {
        let context = ModelContext(try AppModelContainer.make(inMemory: true))
        let topic = makeTopic(lessonOrders: [2, 0, 1], in: context)

        let first = try lesson("l0", in: topic).positionInTopic
        #expect(first.index == 1)
        #expect(first.next?.id == "l1")

        let middle = try lesson("l1", in: topic).positionInTopic
        #expect(middle.index == 2)
        #expect(middle.next?.id == "l2")

        let last = try lesson("l2", in: topic).positionInTopic
        #expect(last.index == 3)
        #expect(last.next == nil)
    }

    /// Non-contiguous `order` values (a lesson removed from the content) still
    /// chain: the reader counts positions, it doesn't read `order` as an index.
    @MainActor
    @Test func gapsInOrderStillChain() throws {
        let context = ModelContext(try AppModelContainer.make(inMemory: true))
        let topic = makeTopic(lessonOrders: [0, 7, 9], in: context)

        let position = try lesson("l7", in: topic).positionInTopic
        #expect(position.index == 2)
        #expect(position.total == 3)
        #expect(position.next?.id == "l9")
    }

    @MainActor
    @Test func aSoleLessonIsOneOfOneWithNothingNext() throws {
        let context = ModelContext(try AppModelContainer.make(inMemory: true))
        let topic = makeTopic(lessonOrders: [0], in: context)

        let position = try lesson("l0", in: topic).positionInTopic
        #expect(position.index == 1)
        #expect(position.total == 1)
        #expect(position.next == nil)
    }

    /// A lesson with no topic must not claim to be "Lesson 1 of 0" or crash the
    /// reader; it degrades to a standalone lesson.
    @MainActor
    @Test func aDetachedLessonDegradesGracefully() throws {
        let lesson = Lesson(id: "orphan", order: 3, title: "Orphan",
                            estimatedMinutes: 5, body: "Body")

        let position = lesson.positionInTopic
        #expect(position.index == 1)
        #expect(position.total == 1)
        #expect(position.next == nil)
    }

    /// Every bundled topic must chain end to end: each lesson but the last points
    /// at the one after it, and no lesson points at itself.
    @MainActor
    @Test func bundledTopicsChainToTheirLastLesson() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        ContentLoader.seed(try ContentLoader.bundledContent(), into: context)

        let topics = try context.fetch(FetchDescriptor<Topic>())
        #expect(!topics.isEmpty, "nothing seeded — the rest of this test would be vacuous")

        for topic in topics {
            let sorted = topic.lessons.sorted { $0.order < $1.order }
            #expect(!sorted.isEmpty, "\(topic.id) has no lessons")

            for (offset, lesson) in sorted.enumerated() {
                let position = lesson.positionInTopic
                #expect(position.index == offset + 1)
                #expect(position.total == sorted.count)
                #expect(position.next?.id != lesson.id, "\(lesson.id) points at itself")

                let isLast = offset == sorted.count - 1
                if isLast {
                    #expect(position.next == nil, "\(topic.id) offers a lesson after its last")
                } else {
                    #expect(position.next?.id == sorted[offset + 1].id,
                            "\(lesson.id) does not point at the next lesson")
                }
            }
        }
    }
}
