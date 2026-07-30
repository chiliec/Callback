import Foundation
import AppCore

@Observable final class PlacementSession: Identifiable {
    let id = UUID()
    let questions: [Question]
    private(set) var currentIndex = 0
    private(set) var picks: [Int?]

    init(questions: [Question]) {
        self.questions = questions
        self.picks = Array(repeating: nil, count: questions.count)
    }

    var current: Question? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var progress: Double {
        questions.isEmpty ? 0 : Double(currentIndex + 1) / Double(questions.count)
    }

    var isComplete: Bool { currentIndex >= questions.count }

    func pick(_ index: Int) {
        guard questions.indices.contains(currentIndex) else { return }
        picks[currentIndex] = index
    }

    func skip() {
        guard questions.indices.contains(currentIndex) else { return }
        picks[currentIndex] = nil
        _ = advance()
    }

    /// Returns false when past the last question (complete).
    @discardableResult
    func advance() -> Bool {
        currentIndex += 1
        return currentIndex < questions.count
    }

    // MARK: Adaptive question selection

    /// Round-robin one question per topic, ordered by Topic.order, until min(12, total).
    static func makeQuestions(from topics: [Topic]) -> [Question] {
        let sortedTopics = topics.sorted { $0.order < $1.order }
        let buckets: [[Question]] = sortedTopics.map { topic in
            topic.questions.enumerated().sorted { $0.offset < $1.offset }.map { $0.element }
        }
        let totalAvailable = buckets.reduce(0) { $0 + $1.count }
        let target = min(12, totalAvailable)
        var result: [Question] = []
        var round = 0
        while result.count < target {
            var addedThisRound = false
            for i in 0..<buckets.count {
                guard result.count < target else { break }
                if round < buckets[i].count {
                    result.append(buckets[i][round])
                    addedThisRound = true
                }
            }
            if !addedThisRound { break }
            round += 1
        }
        return result
    }
}
