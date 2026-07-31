import Foundation

public struct ScoringEngine: Sendable {
    /// Number of answered questions in a topic that yields full coverage weight.
    public let coverageTarget: Int
    /// Recency decay per answer age.
    public let decay: Double

    public init(coverageTarget: Int = 5, decay: Double = 0.9) {
        self.coverageTarget = coverageTarget
        self.decay = decay
    }

    /// Recency-weighted accuracy → 0...100. `correctness` is chronological (oldest first).
    public func mastery(fromChronological correctness: [Bool]) -> Int {
        mastery(fromChronologicalCredit: correctness.map { $0 ? 1 : 0 })
    }

    /// Recency-weighted credit → 0...100. `credits` (each 0...1) is chronological (oldest first).
    public func mastery(fromChronologicalCredit credits: [Double]) -> Int {
        guard !credits.isEmpty else { return 0 }
        let n = credits.count
        var weighted = 0.0
        var total = 0.0
        for (i, credit) in credits.enumerated() {
            let age = Double(n - 1 - i)          // newest has age 0
            let w = pow(decay, age)
            total += w
            weighted += w * credit
        }
        return Int((weighted / total * 100).rounded())
    }

    public struct TopicReadinessInput: Sendable {
        public let mastery: Int
        public let answeredCount: Int
        public init(mastery: Int, answeredCount: Int) {
            self.mastery = mastery
            self.answeredCount = answeredCount
        }
    }

    /// Coverage-aware weighted mean of topic masteries → 0...100.
    public func readiness(topics: [TopicReadinessInput]) -> Int {
        var weighted = 0.0
        var totalCoverage = 0.0
        for t in topics {
            let coverage = min(1.0, Double(t.answeredCount) / Double(coverageTarget))
            totalCoverage += coverage
            weighted += coverage * Double(t.mastery)
        }
        guard totalCoverage > 0 else { return 0 }
        return Int((weighted / totalCoverage).rounded())
    }

    public func accuracy(correct: Int, answered: Int) -> Double {
        guard answered > 0 else { return 0 }
        return Double(correct) / Double(answered)
    }

    /// Consecutive calendar days with ≥1 answer, ending on `now`'s day.
    /// Zero if there is no answer on `now`'s day.
    public func streakDays(answerDates: [Date], now: Date, calendar: Calendar) -> Int {
        let answeredDays = Set(answerDates.map { calendar.startOfDay(for: $0) })
        var streak = 0
        var day = calendar.startOfDay(for: now)
        while answeredDays.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}
