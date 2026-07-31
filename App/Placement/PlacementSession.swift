import Foundation
import AppCore

@Observable final class PlacementSession: Identifiable {
    let id = UUID()
    let questions: [Question]
    private(set) var currentIndex = 0
    private(set) var picks: [Int?]
    private(set) var ratings: [SelfRating?]
    private(set) var revealedGuidance: Set<Int> = []

    init(questions: [Question]) {
        self.questions = questions
        self.picks = Array(repeating: nil, count: questions.count)
        self.ratings = Array(repeating: nil, count: questions.count)
    }

    var current: Question? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var rating: SelfRating? { ratings.indices.contains(currentIndex) ? ratings[currentIndex] : nil }

    var isGuidanceRevealed: Bool { revealedGuidance.contains(currentIndex) }

    var progress: Double {
        questions.isEmpty ? 0 : Double(currentIndex + 1) / Double(questions.count)
    }

    var isComplete: Bool { currentIndex >= questions.count }

    func pick(_ index: Int) {
        guard questions.indices.contains(currentIndex) else { return }
        picks[currentIndex] = index
    }

    func revealGuidance() {
        revealedGuidance.insert(currentIndex)
    }

    func rate(_ rating: SelfRating) {
        guard questions.indices.contains(currentIndex) else { return }
        ratings[currentIndex] = rating
    }

    func skip() {
        guard questions.indices.contains(currentIndex) else { return }
        picks[currentIndex] = nil
        ratings[currentIndex] = nil
        _ = advance()
    }

    /// Returns false when past the last question (complete).
    @discardableResult
    func advance() -> Bool {
        currentIndex += 1
        return currentIndex < questions.count
    }

    // MARK: Adaptive question selection

    /// Delegates to `QuestionSelector` so there is one round-robin
    /// implementation, not two. See `QuestionSelector.placementQuestions`.
    static func makeQuestions(from topics: [Topic]) -> [Question] {
        QuestionSelector.placementQuestions(from: topics, count: 12)
    }
}
