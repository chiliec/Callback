import SwiftData
import Foundation

@Model
public final class UserProfile {
    public var readiness: Int
    public var streakDays: Int
    public var answeredCount: Int
    public var accuracy: Double
    public var weeklyActivity: [Int]      // trailing 12 weeks
    public var targetRole: String
    public var levelRaw: String
    public var targetDate: Date?
    public var dailyGoal: Int             // 5...50, step 5
    public var notificationsEnabled: Bool
    public var reminderTime: Date?
    public var hasCompletedPlacement: Bool
    public var contentVersion: Int        // guards re-seeding

    public var level: Level {
        get { Level(rawValue: levelRaw) ?? .mid }
        set { levelRaw = newValue.rawValue }
    }

    public init(
        readiness: Int = 0,
        streakDays: Int = 0,
        answeredCount: Int = 0,
        accuracy: Double = 0,
        weeklyActivity: [Int] = Array(repeating: 0, count: 12),
        targetRole: String = "iOS Engineer",
        level: Level = .mid,
        targetDate: Date? = nil,
        dailyGoal: Int = 15,
        notificationsEnabled: Bool = false,
        reminderTime: Date? = nil,
        hasCompletedPlacement: Bool = false,
        contentVersion: Int = 0
    ) {
        self.readiness = readiness
        self.streakDays = streakDays
        self.answeredCount = answeredCount
        self.accuracy = accuracy
        self.weeklyActivity = weeklyActivity
        self.targetRole = targetRole
        self.levelRaw = level.rawValue
        self.targetDate = targetDate
        self.dailyGoal = dailyGoal
        self.notificationsEnabled = notificationsEnabled
        self.reminderTime = reminderTime
        self.hasCompletedPlacement = hasCompletedPlacement
        self.contentVersion = contentVersion
    }
}
