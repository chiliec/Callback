import Testing
import SwiftData
import Foundation
@testable import AppCore

/// The topic Practice drill used to run `topic.questions.sorted { $0.id < $1.id }`,
/// which for a 27-question bank is `q1, q10 … q19, q2, q20 … q9` — bands
/// interleaved, and every drill ending on `q9`.
@Suite("Question order")
struct QuestionOrderTests {

    @MainActor
    private func questions(_ spec: [(String, Level)], in context: ModelContext) -> [Question] {
        spec.map { id, level in
            let q = Question(id: id, kind: .multipleChoice, prompt: "P", explanation: "E",
                             correctIndex: 0, level: level,
                             options: [Option(text: "a", isMonospaced: false, order: 0),
                                       Option(text: "b", isMonospaced: false, order: 1)])
            context.insert(q)
            return q
        }
    }

    @MainActor
    @Test func easiestBandFirst() throws {
        let context = ModelContext(try AppModelContainer.make(inMemory: true))
        let qs = questions([("t-q1", .senior), ("t-q2", .junior), ("t-q3", .mid)], in: context)
        #expect(QuestionOrder.practice(qs).map(\.id) == ["t-q2", "t-q3", "t-q1"])
    }

    /// The actual regression: within a band, `q2` has to precede `q10`.
    @MainActor
    @Test func questionNumbersSortNumericallyNotLexicographically() throws {
        let context = ModelContext(try AppModelContainer.make(inMemory: true))
        let ids = ["t-q1", "t-q2", "t-q9", "t-q10", "t-q11", "t-q20"]
        let qs = questions(ids.map { ($0, .mid) }, in: context)
        #expect(QuestionOrder.practice(qs.shuffled()).map(\.id) == ids)
    }

    @MainActor
    @Test func bandsAreGroupedAndRampUp() throws {
        let context = ModelContext(try AppModelContainer.make(inMemory: true))
        let qs = questions([("t-q1", .junior), ("t-q2", .mid), ("t-q3", .senior),
                            ("t-q11", .junior), ("t-q12", .mid), ("t-q13", .senior)],
                           in: context)
        #expect(QuestionOrder.practice(qs).map(\.id)
                == ["t-q1", "t-q11", "t-q2", "t-q12", "t-q3", "t-q13"])
    }

    /// An id with no numeric suffix must not sort in front of `q1`, which is what
    /// falling back to 0 would do.
    @MainActor
    @Test func idsWithoutAQuestionNumberSortLastInTheirBand() throws {
        let context = ModelContext(try AppModelContainer.make(inMemory: true))
        let qs = questions([("t-extra", .junior), ("t-q1", .junior), ("t-q2", .junior)],
                           in: context)
        #expect(QuestionOrder.practice(qs).map(\.id) == ["t-q1", "t-q2", "t-extra"])
    }

    @Test func numberReadsTheTrailingDigitRun() {
        #expect(QuestionOrder.number(in: "swift-q17") == 17)
        #expect(QuestionOrder.number(in: "sysdesign-l1-qc") == Int.max)
        #expect(QuestionOrder.number(in: "topic-2-q3") == 3)
    }

    @Test func levelRankIsEasyToHard() {
        #expect(Level.allCases.map(\.rank) == [0, 1, 2])
        #expect(Level.junior.rank < Level.mid.rank && Level.mid.rank < Level.senior.rank)
    }

    /// Over the real content: every topic's drill starts junior, ends senior and
    /// never steps back down a band.
    @MainActor
    @Test func realContentDrillsRampFromJuniorToSenior() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        ContentLoader.seed(try ContentLoader.bundledContent(), into: context)
        let topics = try context.fetch(FetchDescriptor<Topic>())
        #expect(topics.count == 11)

        for topic in topics {
            let ranks = QuestionOrder.practice(topic.questions).map(\.level.rank)
            #expect(ranks.count == 27, "\(topic.id) has \(ranks.count) questions")
            #expect(ranks == ranks.sorted(), "\(topic.id) drill order steps back a band")
            #expect(ranks.first == Level.junior.rank, "\(topic.id) doesn't start junior")
            #expect(ranks.last == Level.senior.rank, "\(topic.id) doesn't end senior")
        }
    }
}
