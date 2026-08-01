import Foundation

/// Where a lesson sits inside its topic, and what the reader can offer next.
public struct LessonPosition {
    /// 1-based, for "Lesson 2 of 4".
    public let index: Int
    public let total: Int
    /// The following lesson in `order`, or `nil` on the last one.
    public let next: Lesson?

    public init(index: Int, total: Int, next: Lesson?) {
        self.index = index
        self.total = total
        self.next = next
    }
}

public extension Lesson {
    /// Both reader entry points — topic detail and the review queue's "Covers
    /// this gap" row — need this, and each grew its own copy. The reader's "Up
    /// next" row is driven by `next`, and that row being inert is what build 17's
    /// "No way to continue." feedback was about, so it gets one definition with
    /// tests instead of two without.
    var positionInTopic: LessonPosition {
        let siblings = (topic?.lessons ?? []).sorted { $0.order < $1.order }
        guard let idx = siblings.firstIndex(where: { $0.id == id }) else {
            // Detached from its topic, or not yet inserted: a lesson of one, with
            // nothing after it. Better a reader with no "Up next" row than one
            // offering an unrelated lesson.
            return LessonPosition(index: 1, total: 1, next: nil)
        }
        return LessonPosition(
            index: idx + 1,
            total: siblings.count,
            next: siblings.indices.contains(idx + 1) ? siblings[idx + 1] : nil
        )
    }
}
