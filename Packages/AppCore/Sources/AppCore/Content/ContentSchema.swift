import Foundation

public struct ContentBundle: Codable, Sendable {
    public let version: Int
    public let topics: [TopicDTO]
}

public struct TopicDTO: Codable, Sendable {
    public let id: String
    public let name: String
    public let section: TopicSection
    public let symbolName: String
    public let colorToken: String
    public let order: Int
    public let lessons: [LessonDTO]
    public let questions: [QuestionDTO]
}

public struct LessonDTO: Codable, Sendable {
    public let id: String
    public let order: Int
    public let title: String
    public let estimatedMinutes: Int
    public let body: String
    public let quickCheck: QuestionDTO?
}

public struct QuestionDTO: Codable, Sendable {
    public let id: String
    public let kind: QuestionKind
    public let prompt: String
    public let explanation: String
    public let correctIndex: Int?
    public let rubric: String?
    public let codeSnippet: CodeSnippetDTO?
    public let options: [OptionDTO]
}

public struct OptionDTO: Codable, Sendable {
    public let text: String
    public let isMonospaced: Bool
}

public struct CodeSnippetDTO: Codable, Sendable {
    public let filename: String
    public let language: String
    public let code: String
}
