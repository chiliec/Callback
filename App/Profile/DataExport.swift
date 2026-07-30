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
    }

    struct AnswerSnapshot: Codable {
        let questionID: String
        let topicID: String
        let pickedIndex: Int?
        let isCorrect: Bool
        let isFlagged: Bool
        let answeredAt: Date
    }

    struct SessionSnapshot: Codable {
        let kind: String
        let level: String
        let startedAt: Date
        let durationSeconds: Int
        let score: Int
    }

    let profile: ProfileSnapshot
    let answers: [AnswerSnapshot]
    let sessions: [SessionSnapshot]
}

enum DataExporter {
    @MainActor
    static func makeJSON(context: ModelContext) throws -> Data {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let answers = (try? context.fetch(FetchDescriptor<AnswerRecord>())) ?? []
        let sessions = (try? context.fetch(
            FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt)])
        )) ?? []

        let profileSnap: DataExport.ProfileSnapshot
        if let p = profiles.first {
            profileSnap = DataExport.ProfileSnapshot(
                targetRole: p.targetRole,
                level: p.levelRaw,
                dailyGoal: p.dailyGoal,
                readiness: p.readiness,
                answeredCount: p.answeredCount,
                accuracy: p.accuracy,
                streakDays: p.streakDays
            )
        } else {
            profileSnap = DataExport.ProfileSnapshot(
                targetRole: "", level: "", dailyGoal: 0,
                readiness: 0, answeredCount: 0, accuracy: 0, streakDays: 0
            )
        }

        let answerSnaps = answers.map {
            DataExport.AnswerSnapshot(
                questionID: $0.questionID,
                topicID: $0.topicID,
                pickedIndex: $0.pickedIndex,
                isCorrect: $0.isCorrect,
                isFlagged: $0.isFlagged,
                answeredAt: $0.answeredAt
            )
        }

        let sessionSnaps = sessions.map {
            DataExport.SessionSnapshot(
                kind: $0.kindRaw,
                level: $0.levelRaw,
                startedAt: $0.startedAt,
                durationSeconds: $0.durationSeconds,
                score: $0.score
            )
        }

        let export = DataExport(profile: profileSnap, answers: answerSnaps, sessions: sessionSnaps)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }
}
