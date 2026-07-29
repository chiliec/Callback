import SwiftData

public enum AppModelContainer {
    public static let models: [any PersistentModel.Type] = [
        Topic.self, Lesson.self, Question.self, CodeSnippet.self,
        Option.self, Session.self, AnswerRecord.self, UserProfile.self
    ]

    public static func makeSchema() -> Schema { Schema(models) }

    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: makeSchema(), configurations: config)
    }
}
