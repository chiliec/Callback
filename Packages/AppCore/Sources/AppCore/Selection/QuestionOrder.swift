import Foundation

/// Deterministic ordering for a topic's whole question bank.
///
/// The topic Practice drill runs the bank end to end, so its order *is* the
/// study experience. Sorting by `id` — which is what it did through build 21 —
/// is lexicographic: `swift-q1`, `swift-q10`, … `swift-q19`, `swift-q2`, so the
/// difficulty bands arrive interleaved and every drill of a 27-question topic
/// ends on `q9`. `QuestionSelector` already tiers by level for the generated
/// sessions; this is the same idea for the one drill that takes the lot.
public enum QuestionOrder {
    /// Easiest band first, then by the question number authored into the id.
    public static func practice(_ questions: [Question]) -> [Question] {
        questions.sorted { lhs, rhs in
            if lhs.level != rhs.level { return lhs.level.rank < rhs.level.rank }
            let (l, r) = (number(in: lhs.id), number(in: rhs.id))
            return l == r ? lhs.id < rhs.id : l < r
        }
    }

    /// The trailing digits of an id like `swift-q17`.
    ///
    /// An id with no numeric suffix sorts last within its band — falling back to
    /// 0 would instead pile every such question in front of `q1`.
    static func number(in id: String) -> Int {
        let digits = String(id.reversed().prefix { $0.isNumber }.reversed())
        guard !digits.isEmpty, let value = Int(digits) else { return Int.max }
        return value
    }
}
