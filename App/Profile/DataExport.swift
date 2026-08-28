import Foundation
import SwiftData
import AppCore

struct DataExport: Codable {
    struct ProfileSnapshot: Codable {
        let targetRole: String
        let level: String
        let dailyGoal: Int
        let readiness: Int
        let answeredCount: Int
        let accuracy: Double
        let streakDays: Int

        init(_ p: UserProfile) {
            targetRole = p.targetRole
            level = p.levelRaw
            dailyGoal = p.dailyGoal
            readiness = p.readiness
            answeredCount = p.answeredCount
            accuracy = p.accuracy
            streakDays = p.streakDays
        }
    }

    struct AnswerSnapshot: Codable {
        let questionID: String
        let topicID: String
        let pickedIndex: Int?
        let isCorrect: Bool
        let isFlagged: Bool
        let answeredAt: Date

        init(_ a: AnswerRecord) {
            questionID = a.questionID
            topicID = a.topicID
            pickedIndex = a.pickedIndex
            isCorrect = a.isCorrect
            isFlagged = a.isFlagged
            answeredAt = a.answeredAt
        }
    }

    struct SessionSnapshot: Codable {
        let kind: String
        let level: String
        let startedAt: Date
        let durationSeconds: Int
        let score: Int

        init(_ s: Session) {
            kind = s.kindRaw
            level = s.levelRaw
            startedAt = s.startedAt
            durationSeconds = s.durationSeconds
            score = s.score
        }
    }

    /// Nil when the store has no profile yet, so a consumer can distinguish
    /// "no profile" from a real all-zero user (was previously an empty snapshot).
    let profile: ProfileSnapshot?
    let answers: [AnswerSnapshot]
    let sessions: [SessionSnapshot]
}

enum DataExporter {
    @MainActor
    static func makeJSON(context: ModelContext) throws -> Data {
        // Propagate fetch failures instead of swallowing them with `try?`:
        // the caller shows a "Couldn't export" alert, which is better than
        // silently producing an empty or partial export file.
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let answers = try context.fetch(FetchDescriptor<AnswerRecord>())
        let sessions = try context.fetch(
            FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt)])
        )

        let export = DataExport(
            profile: profiles.first.map(DataExport.ProfileSnapshot.init),
            answers: answers.map(DataExport.AnswerSnapshot.init),
            sessions: sessions.map(DataExport.SessionSnapshot.init)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }
}