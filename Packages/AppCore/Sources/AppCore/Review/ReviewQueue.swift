import Foundation

public enum ReviewFilter: Sendable { case all, wrong, flagged }

public struct ReviewItem: Sendable, Identifiable {
    public let questionID: String
    public let topicID: String
    public let pickedIndex: Int?
    public let wasWrong: Bool
    public let isFlagged: Bool
    public let answeredAt: Date
    public var id: String { questionID }
}

public enum ReviewQueue {
    public static func build(from answers: [AnswerRecord], filter: ReviewFilter) -> [ReviewItem] {
        // Latest record per question.
        var latest: [String: AnswerRecord] = [:]
        for a in answers {
            if let existing = latest[a.questionID] {
                if a.answeredAt > existing.answeredAt { latest[a.questionID] = a }
            } else {
                latest[a.questionID] = a
            }
        }

        // Keep only wrong OR flagged.
        let candidates = latest.values.filter { !$0.isCorrect || $0.isFlagged }

        let items = candidates.map {
            ReviewItem(questionID: $0.questionID, topicID: $0.topicID,
                       pickedIndex: $0.pickedIndex,
                       wasWrong: !$0.isCorrect, isFlagged: $0.isFlagged,
                       answeredAt: $0.answeredAt)
        }

        let filtered: [ReviewItem]
        switch filter {
        case .all:     filtered = items
        case .wrong:   filtered = items.filter(\.wasWrong)
        case .flagged: filtered = items.filter(\.isFlagged)
        }

        return filtered.sorted { $0.answeredAt > $1.answeredAt }
    }
}
