import SwiftData

@Model
public final class Topic {
    @Attribute(.unique) public var id: String
    public var name: String
    public var sectionRaw: String
    public var symbolName: String
    public var colorToken: String
    public var order: Int
    public var mastery: Int
    public var isSaved: Bool

    @Relationship(deleteRule: .cascade, inverse: \Lesson.topic)
    public var lessons: [Lesson]
    @Relationship(deleteRule: .cascade, inverse: \Question.topic)
    public var questions: [Question]

    public var section: TopicSection {
        get { TopicSection(rawValue: sectionRaw) ?? .fundamentals }
        set { sectionRaw = newValue.rawValue }
    }

    /// Weak below the offer target (65). Spec §4.
    public var isWeak: Bool { mastery < 65 }
    public var questionCount: Int { questions.count }

    public init(
        id: String,
        name: String,
        section: TopicSection,
        symbolName: String,
        colorToken: String,
        order: Int,
        mastery: Int = 0,
        isSaved: Bool = false,
        lessons: [Lesson] = [],
        questions: [Question] = []
    ) {
        self.id = id
        self.name = name
        self.sectionRaw = section.rawValue
        self.symbolName = symbolName
        self.colorToken = colorToken
        self.order = order
        self.mastery = mastery
        self.isSaved = isSaved
        self.lessons = lessons
        self.questions = questions
    }
}
