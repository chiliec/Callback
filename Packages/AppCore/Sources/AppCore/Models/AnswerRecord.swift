import SwiftData
import Foundation

@Model
public final class AnswerRecord {
    public var questionID: String
    public var topicID: String
    public var pickedIndex: Int?
    public var isCorrect: Bool
    public var isFlagged: Bool
    public var answeredAt: Date
    public var session: Session?
    public var selfRatingRaw: Int?

    /// Self-assessment for behavioral questions. Nil for graded questions.
    public var selfRating: SelfRating? {
        get { selfRatingRaw.flatMap(SelfRating.init(rawValue:)) }
        set { selfRatingRaw = newValue?.rawValue }
    }

    /// Mastery credit this answer earns, 0...1. Falls back to `isCorrect` when there's no rating.
    public var credit: Double { selfRating?.credit ?? (isCorrect ? 1 : 0) }

    public init(
        questionID: String,
        topicID: String,
        pickedIndex: Int?,
        isCorrect: Bool,
        isFlagged: Bool,
        answeredAt: Date,
        selfRating: SelfRating? = nil
    ) {
        self.questionID = questionID
        self.topicID = topicID
        self.pickedIndex = pickedIndex
        self.isCorrect = isCorrect
        self.isFlagged = isFlagged
        self.answeredAt = answeredAt
        self.selfRatingRaw = selfRating?.rawValue
    }
}
