import SwiftData

@Model
public final class Question {
    public var id: String
    public var kindRaw: String
    public var prompt: String
    public var explanation: String
    /// Correct option index for multipleChoice/code. Nil for self-rated kinds.
    public var correctIndex: Int?
    /// Model-answer guidance for self-rated kinds. Nil otherwise.
    public var rubric: String?
    /// Difficulty band, used by `QuestionSelector` to honour the Level picker.
    public var levelRaw: String = Level.mid.rawValue

    @Relationship(deleteRule: .cascade) public var codeSnippet: CodeSnippet?
    @Relationship(deleteRule: .cascade) public var options: [Option]
    public var topic: Topic?

    public var kind: QuestionKind {
        get { QuestionKind(rawValue: kindRaw) ?? .multipleChoice }
        set { kindRaw = newValue.rawValue }
    }

    public var level: Level {
        get { Level(rawValue: levelRaw) ?? .mid }
        set { levelRaw = newValue.rawValue }
    }

    public init(
        id: String,
        kind: QuestionKind,
        prompt: String,
        explanation: String,
        correctIndex: Int?,
        rubric: String? = nil,
        level: Level = .mid,
        codeSnippet: CodeSnippet? = nil,
        options: [Option] = []
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.prompt = prompt
        self.explanation = explanation
        self.correctIndex = correctIndex
        self.rubric = rubric
        self.levelRaw = level.rawValue
        self.codeSnippet = codeSnippet
        self.options = options
    }
}
