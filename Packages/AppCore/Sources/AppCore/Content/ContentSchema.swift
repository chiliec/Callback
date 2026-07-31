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
    /// Absent decodes to `.mid`. `ContentValidationTests` enforces the key's
    /// presence in authored JSON, so the default only ever applies to fixtures.
    public let level: Level

    enum CodingKeys: String, CodingKey {
        case id, kind, prompt, explanation, correctIndex, rubric, codeSnippet, options, level
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(QuestionKind.self, forKey: .kind)
        prompt = try c.decode(String.self, forKey: .prompt)
        explanation = try c.decode(String.self, forKey: .explanation)
        correctIndex = try c.decodeIfPresent(Int.self, forKey: .correctIndex)
        rubric = try c.decodeIfPresent(String.self, forKey: .rubric)
        codeSnippet = try c.decodeIfPresent(CodeSnippetDTO.self, forKey: .codeSnippet)
        options = try c.decodeIfPresent([OptionDTO].self, forKey: .options) ?? []
        level = try c.decodeIfPresent(Level.self, forKey: .level) ?? .mid
    }
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
