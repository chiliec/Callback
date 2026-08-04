import Testing
import Foundation
@testable import AppCore

/// Invariants over the *real* bundled content. These are the acceptance gate for
/// every authoring batch — a malformed topic file fails here, not on a device.
@Suite("Content validation")
struct ContentValidationTests {

    private func bundle() throws -> ContentBundle { try ContentLoader.bundledContent() }

    /// Both authored banks: the drill-eligible questions and the lesson quick
    /// checks. Quick checks never reach a drill, but they are still content and
    /// still have to be well-formed.
    private func allQuestions() throws -> [QuestionDTO] {
        try bundle().topics.flatMap { topic in
            topic.questions + topic.lessons.compactMap(\.quickCheck)
        }
    }

    @Test func idsAreGloballyUnique() throws {
        let b = try bundle()
        var seen = Set<String>()
        var duplicates: [String] = []
        var everyID: [String] = b.topics.map(\.id)
        everyID += b.topics.flatMap { $0.lessons.map(\.id) }
        everyID += b.topics.flatMap { $0.questions.map(\.id) }
        everyID += b.topics.flatMap { $0.lessons.compactMap { $0.quickCheck?.id } }
        for id in everyID {
            if !seen.insert(id).inserted { duplicates.append(id) }
        }
        #expect(duplicates.isEmpty, "duplicate ids: \(duplicates)")
    }

    @Test func gradableQuestionsHaveAnAnswerableKey() throws {
        for q in try allQuestions() where !q.kind.isSelfRated {
            #expect(q.options.count >= 2, "\(q.id) has \(q.options.count) options")
            guard let correct = q.correctIndex else {
                Issue.record("\(q.id) is gradable but has no correctIndex"); continue
            }
            #expect(q.options.indices.contains(correct),
                    "\(q.id) correctIndex \(correct) is out of range")
        }
    }

    @Test func selfRatedQuestionsHaveGuidanceAndNoKey() throws {
        for q in try allQuestions() where q.kind.isSelfRated {
            #expect(q.correctIndex == nil, "\(q.id) is self-rated but has a correctIndex")
            #expect(q.options.isEmpty, "\(q.id) is self-rated but has options")
            let rubric = q.rubric?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            #expect(!rubric.isEmpty, "\(q.id) is self-rated but has no rubric")
        }
    }

    @Test func codeQuestionsCarryASnippet() throws {
        for q in try allQuestions() where q.kind == .code {
            #expect(q.codeSnippet != nil, "\(q.id) is a code question with no snippet")
        }
    }

    @Test func promptsAndExplanationsAreNonEmpty() throws {
        for q in try allQuestions() {
            #expect(!q.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(q.id) has an empty prompt")
            #expect(!q.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(q.id) has an empty explanation")
        }
    }

    @Test func lessonsHaveBodiesAndSaneEstimates() throws {
        for topic in try bundle().topics {
            for lesson in topic.lessons {
                #expect(!lesson.title.isEmpty, "\(lesson.id) has no title")
                #expect(lesson.body.count > 200, "\(lesson.id) body is suspiciously short")
                #expect((1...15).contains(lesson.estimatedMinutes),
                        "\(lesson.id) estimate \(lesson.estimatedMinutes) is implausible")
            }
        }
    }

    @Test func orderValuesAreContiguous() throws {
        let b = try bundle()
        #expect(b.topics.map(\.order).sorted() == Array(0..<b.topics.count),
                "topic order values are not 0..<\(b.topics.count)")
        for topic in b.topics {
            #expect(topic.lessons.map(\.order).sorted() == Array(0..<topic.lessons.count),
                    "\(topic.id) lesson order values are not contiguous")
        }
    }

    /// The DTO tolerates a missing `level` (defaults to `.mid`) so fixtures stay
    /// terse. Authored content gets no such latitude — assert on the raw JSON.
    @Test func everyAuthoredQuestionDeclaresALevelExplicitly() throws {
        let manifestData = try #require(
            ContentLoader.resourceBundle.url(forResource: "content-manifest",
                                            withExtension: "json")
                .flatMap { try? Data(contentsOf: $0) })
        let manifest = try JSONDecoder().decode(ContentManifest.self, from: manifestData)

        var missing: [String] = []
        for topicID in manifest.topics {
            let url = try #require(
                ContentLoader.resourceBundle.url(forResource: "topic-\(topicID)",
                                                withExtension: "json"))
            let raw = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
            let topic = try #require(raw as? [String: Any])

            for q in (topic["questions"] as? [[String: Any]]) ?? [] {
                if q["level"] == nil { missing.append((q["id"] as? String) ?? "?") }
            }
            for lesson in (topic["lessons"] as? [[String: Any]]) ?? [] {
                guard let qc = lesson["quickCheck"] as? [String: Any] else { continue }
                if qc["level"] == nil { missing.append((qc["id"] as? String) ?? "?") }
            }
        }
        #expect(missing.isEmpty, "questions missing an explicit level: \(missing)")
    }

    @Test func everyTopicHasQuestionsAtEveryLevel() throws {
        for topic in try bundle().topics {
            let levels = Set(topic.questions.map(\.level))
            #expect(levels == Set(Level.allCases),
                    "\(topic.id) covers only \(levels.map(\.rawValue).sorted())")
        }
    }

    /// Gradable questions in a topic's bank, including lesson quick-checks.
    private func gradable(_ topic: TopicDTO) -> [QuestionDTO] {
        (topic.questions + topic.lessons.compactMap(\.quickCheck))
            .filter { !$0.kind.isSelfRated && !$0.options.isEmpty }
    }

    /// Systemic position tell: the older topics only ever placed the correct
    /// answer at index 0 or 1. No single index may hold >40% of a topic's
    /// gradable answers once the bank is large enough to measure.
    @Test func answerPositionsAreNotClustered() throws {
        for topic in try bundle().topics {
            let g = gradable(topic)
            guard g.count >= 12 else { continue }
            var counts: [Int: Int] = [:]
            for q in g { if let i = q.correctIndex { counts[i, default: 0] += 1 } }
            let maxShare = Double(counts.values.max() ?? 0) / Double(g.count)
            #expect(maxShare <= 0.40,
                    "\(topic.id): a correctIndex holds \(Int(maxShare * 100))% of \(g.count) answers (max 40%) — \(counts.sorted { $0.key < $1.key })")
        }
    }

    /// Systemic length tell: the correct option must not be the strictly-longest
    /// option in more than 40% of a topic's gradable questions (chance ~25%).
    @Test func correctOptionIsNotSystematicallyLongest() throws {
        for topic in try bundle().topics {
            let g = gradable(topic)
            guard g.count >= 12 else { continue }
            var longest = 0
            for q in g {
                guard let ci = q.correctIndex, q.options.indices.contains(ci) else { continue }
                let lengths = q.options.map { $0.text.count }
                let maxLen = lengths.max() ?? 0
                if lengths[ci] == maxLen && lengths.filter({ $0 == maxLen }).count == 1 {
                    longest += 1
                }
            }
            let share = Double(longest) / Double(g.count)
            #expect(share <= 0.40,
                    "\(topic.id): correct answer is the longest option in \(Int(share * 100))% of \(g.count) questions (max 40%)")
        }
    }

    /// Sequential position tell, which the aggregate clustering check above is
    /// blind to: `0,1,2,3,0,1,2,3,…` spreads answers perfectly evenly across the
    /// four indices — 25% each, well inside the 40% cap — while being completely
    /// predictable to anyone two questions in. `topic-persistence` shipped exactly
    /// that, and `swift`/`memory`/`swiftui` shipped period-4 cycles in their
    /// authored array order.
    ///
    /// Measured in `QuestionOrder.practice` order, because the drill regroups the
    /// bank by band before presenting it — that reshuffle is what the learner
    /// sees, and it happens to defuse a cycle authored in array order.
    ///
    /// Threshold is deliberately loose. Chance is 25% and with ~23 comparisons the
    /// standard deviation is ~9 points, so a clean bank can legitimately reach the
    /// low 40s (`testing` sits at 44% for one lag); 50% is ~2.8σ — high enough not
    /// to fire on noise, low enough to catch a real cycle, which scores 57–100%.
    @Test func answerPositionsAreNotSequentiallyPredictable() throws {
        for topic in try bundle().topics {
            let bank = QuestionOrder.practiceSorted(
                topic.questions.filter { !$0.kind.isSelfRated && !$0.options.isEmpty },
                level: \.level,
                id: \.id
            )
            let seq = bank.compactMap(\.correctIndex)
            guard seq.count >= 12 else { continue }
            for lag in 1...6 where seq.count > lag {
                let comparisons = seq.count - lag
                let repeats = (0..<comparisons).count { seq[$0] == seq[$0 + lag] }
                let share = Double(repeats) / Double(comparisons)
                #expect(share < 0.50,
                        "\(topic.id): correctIndex repeats at lag \(lag) in \(Int(share * 100))% of \(comparisons) pairs (max 50%, chance 25%) — sequence \(seq.map(String.init).joined())")
            }
        }
    }

    /// `OptionRow` renders a monospaced option as a plain code token — it does
    /// not parse Markdown. A backtick in a monospaced option therefore reaches the
    /// screen verbatim. Backticks belong to prose options, which render inline
    /// Markdown; a monospaced option carrying one is a mis-flagged prose answer.
    @Test func monospacedOptionsAreNotBacktickedProse() throws {
        var offenders: [String] = []
        for q in try allQuestions() {
            for o in q.options where o.isMonospaced && o.text.contains("`") {
                offenders.append("\(q.id): \(o.text)")
            }
        }
        #expect(offenders.isEmpty,
                "monospaced options must not contain backticks: \(offenders)")
    }

    /// Uniform option count: every gradable question offers exactly 4 options.
    @Test func gradableQuestionsHaveFourOptions() throws {
        for topic in try bundle().topics {
            for q in gradable(topic) {
                #expect(q.options.count == 4,
                        "\(q.id) has \(q.options.count) options, expected 4")
            }
        }
    }
}
