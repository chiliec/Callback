import Foundation

public enum TopicSection: String, Codable, Sendable, CaseIterable {
    case fundamentals, frameworks, craft
}

public enum QuestionKind: String, Codable, Sendable {
    case multipleChoice, code, behavioral
}

public enum SessionKind: String, Codable, Sendable {
    case mock, rapidFire, codeReview, systemDesign
}

public enum Level: String, Codable, Sendable, CaseIterable {
    case junior, mid, senior
}
