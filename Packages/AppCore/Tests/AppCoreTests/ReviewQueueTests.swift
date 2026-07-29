import Testing
import Foundation
@testable import AppCore

private func rec(_ q: String, wrong: Bool, flagged: Bool, at t: TimeInterval) -> AnswerRecord {
    AnswerRecord(questionID: q, topicID: "swift", pickedIndex: 0,
                 isCorrect: !wrong, isFlagged: flagged,
                 answeredAt: Date(timeIntervalSince1970: t))
}

@Test func queueDedupesToLatestPerQuestion() {
    // q1 answered wrong then later correct -> latest is correct & not flagged -> excluded
    let answers = [
        rec("q1", wrong: true, flagged: false, at: 100),
        rec("q1", wrong: false, flagged: false, at: 200),
        rec("q2", wrong: true, flagged: false, at: 150)
    ]
    let items = ReviewQueue.build(from: answers, filter: .all)
    #expect(items.map(\.questionID) == ["q2"])
}

@Test func queueIncludesFlaggedEvenWhenCorrect() {
    let answers = [rec("q1", wrong: false, flagged: true, at: 100)]
    let items = ReviewQueue.build(from: answers, filter: .all)
    #expect(items.count == 1)
    #expect(items[0].isFlagged == true)
}

@Test func queueFiltersWrongOnly() {
    let answers = [
        rec("q1", wrong: true, flagged: false, at: 100),
        rec("q2", wrong: false, flagged: true, at: 100)
    ]
    let items = ReviewQueue.build(from: answers, filter: .wrong)
    #expect(items.map(\.questionID) == ["q1"])
}

@Test func queueSortsNewestFirst() {
    let answers = [
        rec("q1", wrong: true, flagged: false, at: 100),
        rec("q2", wrong: true, flagged: false, at: 300)
    ]
    let items = ReviewQueue.build(from: answers, filter: .all)
    #expect(items.map(\.questionID) == ["q2", "q1"])
}
