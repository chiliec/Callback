import Foundation

public enum TopicSection: String, Codable, Sendable, CaseIterable {
    case fundamentals, frameworks, craft
}

public enum QuestionKind: String, Codable, Sendable, CaseIterable {
    case multipleChoice, code, behavioral, systemDesign

    /// Kinds with no gradable key — the user's `SelfRating` is the grade.
    /// `Grading.isCorrect` and `ScoringEngine` already handle these via
    /// `SelfRating.credit`; this exists so call sites don't enumerate kinds.
    public var isSelfRated: Bool {
        switch self {
        case .behavioral, .systemDesign: return true
        case .multipleChoice, .code: return false
        }
    }
}

public enum SessionKind: String, Codable, Sendable {
    case mock, rapidFire, codeReview, systemDesign
}

public enum Level: String, Codable, Sendable, CaseIterable {
    case junior, mid, senior
}

/// Self-assessment for behavioral questions, which have no gradable answer.
public enum SelfRating: Int, Codable, Sendable, CaseIterable {
    case weak = 0, ok = 1, strong = 2

    /// Mastery credit this rating earns, 0...1.
    public var credit: Double {
        switch self {
        case .weak: return 0
        case .ok: return 0.5
        case .strong: return 1
        }
    }

    /// Shaky answers go back in the review queue; the other two don't.
    public var countsAsCorrect: Bool { self != .weak }

    public var label: String {
        switch self {
        case .weak: return "Shaky"
        case .ok: return "Decent"
        case .strong: return "Solid"
        }
    }
}
