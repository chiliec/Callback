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

    public init(
        questionID: String,
        topicID: String,
        pickedIndex: Int?,
        isCorrect: Bool,
        isFlagged: Bool,
        answeredAt: Date
    ) {
        self.questionID = questionID
        self.topicID = topicID
        self.pickedIndex = pickedIndex
        self.isCorrect = isCorrect
        self.isFlagged = isFlagged
        self.answeredAt = answeredAt
    }
}
