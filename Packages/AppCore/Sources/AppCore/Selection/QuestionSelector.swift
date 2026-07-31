import Foundation

/// Chooses the questions for a session. Pure and RNG-injected so selection is
/// unit-testable and `--demo-seed` screenshots are reproducible.
///
/// Drill eligibility is *derived* from a question's own kind rather than
/// authored separately, so a question can never claim to belong in a drill its
/// content doesn't suit.
public enum QuestionSelector {

    // MARK: Eligibility

    public static func eligible(_ questions: [Question], for kind: SessionKind) -> [Question] {
        switch kind {
        case .rapidFire:
            // Short recall questions only — nothing with code to read.
            return questions.filter { $0.kind == .multipleChoice && $0.codeSnippet == nil }
        case .codeReview:
            return questions.filter { $0.kind == .code }
        case .systemDesign:
            return questions.filter { $0.kind == .systemDesign }
        case .behavioral:
            return questions.filter { $0.kind == .behavioral }
        case .mock:
            return questions
        }
    }

    /// Whether a drill can run at all. Deliberately level-agnostic: `select`
    /// widens across levels, so a non-empty eligible pool always yields a
    /// session. Callers use this to enable/disable a drill.
    public static func availableCount(in pool: [Question], for kind: SessionKind) -> Int {
        eligible(pool, for: kind).count
    }

    // MARK: Selection

    public static func select(
        from pool: [Question],
        kind: SessionKind,
        level: Level,
        count: Int,
        lastSeenAt: [String: Date] = [:],
        using generator: inout some RandomNumberGenerator
    ) -> [Question] {
        guard count > 0 else { return [] }
        let candidates = eligible(pool, for: kind)
        var chosen: [Question] = []
        var usedIDs = Set<String>()

        // Exact level first, then progressively wider bands. A short pool
        // degrades to a smaller valid session rather than an empty one.
        for tier in levelTiers(for: level) {
            guard chosen.count < count else { break }
            let tierLevels = Set(tier)
            let tierQuestions = candidates.filter {
                tierLevels.contains($0.level) && !usedIDs.contains($0.id)
            }
            let picked = roundRobinByTopic(
                tierQuestions, limit: count - chosen.count,
                lastSeenAt: lastSeenAt, using: &generator)
            chosen.append(contentsOf: picked)
            usedIDs.formUnion(picked.map(\.id))
        }
        return chosen
    }

    /// Widening order. Mid widens to both neighbours at once because they are
    /// equidistant; junior and senior walk outward one band at a time.
    private static func levelTiers(for level: Level) -> [[Level]] {
        switch level {
        case .junior: return [[.junior], [.mid], [.senior]]
        case .mid:    return [[.mid], [.junior, .senior]]
        case .senior: return [[.senior], [.mid], [.junior]]
        }
    }

    /// One question per topic per round, topics in `Topic.order`. Keeps a
    /// 12-question mock spread across the syllabus instead of landing five
    /// questions on one topic by chance. Within a topic, order is by freshness.
    private static func roundRobinByTopic(
        _ questions: [Question],
        limit: Int,
        lastSeenAt: [String: Date],
        using generator: inout some RandomNumberGenerator
    ) -> [Question] {
        guard limit > 0, !questions.isEmpty else { return [] }

        let grouped = Dictionary(grouping: questions) { $0.topic?.id ?? "" }
        // Sort by the topic's order, falling back to id so grouping is stable
        // for questions whose topic relationship is nil.
        let orderedKeys = grouped.keys.sorted { lhs, rhs in
            let lo = grouped[lhs]?.first?.topic?.order ?? Int.max
            let ro = grouped[rhs]?.first?.topic?.order ?? Int.max
            return lo == ro ? lhs < rhs : lo < ro
        }
        // Not `map`: `generator` is `inout` and cannot be captured by a closure.
        var buckets: [[Question]] = []
        buckets.reserveCapacity(orderedKeys.count)
        for key in orderedKeys {
            buckets.append(orderedByFreshness(
                grouped[key]!, lastSeenAt: lastSeenAt, using: &generator))
        }

        var result: [Question] = []
        var round = 0
        while result.count < limit {
            var addedThisRound = false
            for i in buckets.indices where result.count < limit {
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

    /// Never-seen first, then least-recently-seen, RNG breaking exact ties.
    ///
    /// A question with no `lastSeenAt` entry sorts as `.distantPast`, which is
    /// what puts never-answered questions first without a special case. The
    /// random `tie` value makes the comparator a total order, so the result does
    /// not depend on `sorted` being stable — which Swift does not guarantee.
    ///
    /// With an empty `lastSeenAt` every question ties, so this reduces to a
    /// shuffle. That is the pre-amendment behaviour, and no test in this file
    /// asserts an exact shuffle order, so the substitution is safe.
    private static func orderedByFreshness(
        _ questions: [Question],
        lastSeenAt: [String: Date],
        using generator: inout some RandomNumberGenerator
    ) -> [Question] {
        var keyed: [(question: Question, seen: Date, tie: UInt64)] = []
        keyed.reserveCapacity(questions.count)
        for q in questions {
            keyed.append((q, lastSeenAt[q.id] ?? .distantPast, generator.next()))
        }
        return keyed
            .sorted { $0.seen == $1.seen ? $0.tie < $1.tie : $0.seen < $1.seen }
            .map(\.question)
    }

    // MARK: Placement

    /// The placement quiz *estimates* the user's level, so it must not filter by
    /// a level the user picked. It samples one `mid` question per topic as a
    /// fixed baseline, and is fully deterministic — no RNG — so a given content
    /// bundle always produces the same quiz.
    public static func placementQuestions(from topics: [Topic], count: Int = 12) -> [Question] {
        let sortedTopics = topics.sorted { $0.order < $1.order }
        let buckets: [[Question]] = sortedTopics.map { topic in
            let mid = topic.questions.filter { $0.level == .mid }
            let source = mid.isEmpty ? topic.questions : mid
            return source.sorted { $0.id < $1.id }
        }
        let target = min(count, buckets.reduce(0) { $0 + $1.count })

        var result: [Question] = []
        var round = 0
        while result.count < target {
            var addedThisRound = false
            for i in buckets.indices where result.count < target {
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
