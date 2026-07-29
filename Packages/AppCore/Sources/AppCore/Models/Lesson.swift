import SwiftData
import Foundation

@Model
public final class Lesson {
    public var id: String
    public var order: Int
    public var title: String
    public var estimatedMinutes: Int
    public var body: String
    public var isComplete: Bool
    public var completedAt: Date?

    @Relationship(deleteRule: .cascade) public var quickCheck: Question?
    public var topic: Topic?

    public init(
        id: String,
        order: Int,
        title: String,
        estimatedMinutes: Int,
        body: String,
        quickCheck: Question? = nil,
        isComplete: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.body = body
        self.quickCheck = quickCheck
        self.isComplete = isComplete
        self.completedAt = completedAt
    }
}
