import SwiftData
import Foundation

@Model
public final class Session {
    public var kindRaw: String
    public var levelRaw: String
    public var startedAt: Date
    public var durationSeconds: Int
    public var elapsedSeconds: Int

    @Relationship(deleteRule: .cascade, inverse: \AnswerRecord.session)
    public var answers: [AnswerRecord]

    public var kind: SessionKind {
        get { SessionKind(rawValue: kindRaw) ?? .mock }
        set { kindRaw = newValue.rawValue }
    }
    public var level: Level {
        get { Level(rawValue: levelRaw) ?? .mid }
        set { levelRaw = newValue.rawValue }
    }

    /// Correct answers in this session.
    public var correctCount: Int { answers.filter(\.isCorrect).count }
    /// Percentage score 0–100 (rounded). Zero-answer sessions score 0.
    public var score: Int {
        guard !answers.isEmpty else { return 0 }
        return Int((Double(correctCount) / Double(answers.count) * 100).rounded())
    }

    public init(
        kind: SessionKind,
        level: Level,
        startedAt: Date,
        durationSeconds: Int,
        elapsedSeconds: Int = 0,
        answers: [AnswerRecord] = []
    ) {
        self.kindRaw = kind.rawValue
        self.levelRaw = level.rawValue
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.elapsedSeconds = elapsedSeconds
        self.answers = answers
    }
}
