import SwiftData

@Model
public final class Question {
    public var id: String
    public var kindRaw: String
    public var prompt: String
    public var explanation: String
    /// Correct option index for multipleChoice/code. Nil for behavioral.
    public var correctIndex: Int?
    /// Model-answer guidance for behavioral questions. Nil otherwise.
    public var rubric: String?

    @Relationship(deleteRule: .cascade) public var codeSnippet: CodeSnippet?
    @Relationship(deleteRule: .cascade) public var options: [Option]
    public var topic: Topic?

    public var kind: QuestionKind {
        get { QuestionKind(rawValue: kindRaw) ?? .multipleChoice }
        set { kindRaw = newValue.rawValue }
    }

    public init(
        id: String,
        kind: QuestionKind,
        prompt: String,
        explanation: String,
        correctIndex: Int?,
        rubric: String? = nil,
        codeSnippet: CodeSnippet? = nil,
        options: [Option] = []
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.prompt = prompt
        self.explanation = explanation
        self.correctIndex = correctIndex
        self.rubric = rubric
        self.codeSnippet = codeSnippet
        self.options = options
    }
}
