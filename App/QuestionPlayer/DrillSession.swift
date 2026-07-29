import Foundation
import AppCore

@Observable final class DrillSession: Identifiable, Hashable {
    let id = UUID()
    let questions: [Question]
    private(set) var currentIndex: Int = 0
    private(set) var picks: [Int?]
    private(set) var isAnswered: Bool = false
    private(set) var isComplete: Bool = false

    init(questions: [Question]) {
        precondition(!questions.isEmpty, "DrillSession requires at least one question")
        self.questions = questions
        self.picks = Array(repeating: nil, count: questions.count)
    }

    var current: Question? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var pickedIndex: Int? { picks.indices.contains(currentIndex) ? picks[currentIndex] : nil }

    var progress: Double {
        questions.isEmpty ? 0 : Double(currentIndex + 1) / Double(questions.count)
    }

    func pick(_ index: Int) {
        guard !isAnswered, questions.indices.contains(currentIndex) else { return }
        picks[currentIndex] = index
        isAnswered = true
    }

    func advance() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            isAnswered = picks[currentIndex] != nil
        } else {
            isComplete = true
        }
    }

    static func == (lhs: DrillSession, rhs: DrillSession) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
