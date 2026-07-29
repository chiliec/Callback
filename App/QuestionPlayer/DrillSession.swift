import Foundation
import AppCore

@Observable final class DrillSession: Identifiable, Hashable {
    let id = UUID()
    let questions: [Question]
    init(questions: [Question]) { self.questions = questions }
    static func == (lhs: DrillSession, rhs: DrillSession) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
