import Foundation
import SwiftData

public enum ContentLoader {
    public static func decode(_ data: Data) throws -> ContentBundle {
        try JSONDecoder().decode(ContentBundle.self, from: data)
    }

    public enum ContentError: Error, CustomStringConvertible {
        case missingResource(String)

        public var description: String {
            switch self {
            case .missingResource(let name):
                return "Content resource '\(name).json' is missing from the bundle."
            }
        }
    }

    /// The bundle holding the content JSON. Exposed to the module because
    /// `Bundle.module` referenced from the *test* target resolves to the test
    /// bundle, which carries no resources — `ContentValidationTests` needs this.
    static let resourceBundle = Bundle.module

    private static func resourceData(_ name: String) throws -> Data {
        guard let url = resourceBundle.url(forResource: name, withExtension: "json") else {
            throw ContentError.missingResource(name)
        }
        return try Data(contentsOf: url)
    }

    /// Assembles the bundle from the manifest plus one file per topic. A missing
    /// or malformed topic file throws rather than silently yielding a short
    /// bundle — a partial seed would look like deleted content to the user.
    public static func assembleContent(manifestName: String = "content-manifest") throws -> ContentBundle {
        let manifest = try JSONDecoder().decode(
            ContentManifest.self, from: try resourceData(manifestName))
        let decoder = JSONDecoder()
        let topics = try manifest.topics.map { id in
            try decoder.decode(TopicDTO.self, from: try resourceData("topic-\(id)"))
        }
        return ContentBundle(version: manifest.version, topics: topics)
    }

    public static func bundledContent() throws -> ContentBundle {
        try assembleContent()
    }

    /// Upserts the content graph by id. Author-owned fields are updated; user-progress
    /// (mastery, isSaved, isComplete, completedAt, AnswerRecords) is never touched.
    public static func seed(_ bundle: ContentBundle, into context: ModelContext) {
        let existingTopics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []
        var topicMap = Dictionary(uniqueKeysWithValues: existingTopics.map { ($0.id, $0) })

        let existingLessons = (try? context.fetch(FetchDescriptor<Lesson>())) ?? []
        var lessonMap = Dictionary(uniqueKeysWithValues: existingLessons.map { ($0.id, $0) })

        let existingQuestions = (try? context.fetch(FetchDescriptor<Question>())) ?? []
        var questionMap = Dictionary(uniqueKeysWithValues: existingQuestions.map { ($0.id, $0) })

        for t in bundle.topics {
            let topic: Topic
            if let existing = topicMap[t.id] {
                existing.name = t.name
                existing.sectionRaw = t.section.rawValue
                existing.symbolName = t.symbolName
                existing.colorToken = t.colorToken
                existing.order = t.order
                topic = existing
            } else {
                topic = Topic(
                    id: t.id, name: t.name, section: t.section,
                    symbolName: t.symbolName, colorToken: t.colorToken, order: t.order
                )
                context.insert(topic)
            }

            for l in t.lessons {
                if let existing = lessonMap[l.id] {
                    existing.order = l.order
                    existing.title = l.title
                    existing.estimatedMinutes = l.estimatedMinutes
                    existing.body = l.body
                    if let qcDTO = l.quickCheck {
                        if let existingQC = existing.quickCheck {
                            updateQuestion(existingQC, from: qcDTO, context: context)
                        } else {
                            existing.quickCheck = makeQuestion(qcDTO)
                        }
                    } else if let oldQC = existing.quickCheck {
                        context.delete(oldQC)
                        existing.quickCheck = nil
                    }
                } else {
                    let lesson = Lesson(
                        id: l.id, order: l.order, title: l.title,
                        estimatedMinutes: l.estimatedMinutes, body: l.body,
                        quickCheck: l.quickCheck.map(makeQuestion)
                    )
                    lesson.topic = topic
                    topic.lessons.append(lesson)
                }
            }

            for q in t.questions {
                if let existing = questionMap[q.id] {
                    updateQuestion(existing, from: q, context: context)
                } else {
                    let question = makeQuestion(q)
                    question.topic = topic
                    topic.questions.append(question)
                }
            }
        }
    }

    /// Seeds only when the bundle is newer than what the profile has seen.
    @discardableResult
    public static func seedIfNeeded(
        into context: ModelContext, profile: UserProfile, bundle: ContentBundle
    ) -> Bool {
        guard bundle.version > profile.contentVersion else { return false }
        seed(bundle, into: context)
        profile.contentVersion = bundle.version
        return true
    }

    private static func makeQuestion(_ q: QuestionDTO) -> Question {
        let options = q.options.enumerated().map { idx, o in
            Option(text: o.text, isMonospaced: o.isMonospaced, order: idx)
        }
        let snippet = q.codeSnippet.map {
            CodeSnippet(filename: $0.filename, language: $0.language, code: $0.code)
        }
        return Question(
            id: q.id, kind: q.kind, prompt: q.prompt, explanation: q.explanation,
            correctIndex: q.correctIndex, rubric: q.rubric, level: q.level,
            codeSnippet: snippet, options: options
        )
    }

    private static func updateQuestion(_ question: Question, from dto: QuestionDTO, context: ModelContext) {
        question.kindRaw = dto.kind.rawValue
        question.prompt = dto.prompt
        question.explanation = dto.explanation
        question.correctIndex = dto.correctIndex
        question.rubric = dto.rubric
        question.levelRaw = dto.level.rawValue
        // Rewrite options only when they actually differ. A version bump would
        // otherwise delete and re-insert every option in the store on the main
        // actor during launch. Order matters, so compare as ordered pairs.
        let incoming = dto.options.map { ($0.text, $0.isMonospaced) }
        let existing = question.options
            .sorted { $0.order < $1.order }
            .map { ($0.text, $0.isMonospaced) }
        if !(incoming.count == existing.count
             && zip(incoming, existing).allSatisfy { $0 == $1 }) {
            for opt in question.options { context.delete(opt) }
            question.options = dto.options.enumerated().map { idx, o in
                Option(text: o.text, isMonospaced: o.isMonospaced, order: idx)
            }
        }

        // Same reasoning for the snippet.
        let snippetChanged = question.codeSnippet?.filename != dto.codeSnippet?.filename
            || question.codeSnippet?.language != dto.codeSnippet?.language
            || question.codeSnippet?.code != dto.codeSnippet?.code
        if snippetChanged {
            if let old = question.codeSnippet { context.delete(old) }
            question.codeSnippet = dto.codeSnippet.map {
                CodeSnippet(filename: $0.filename, language: $0.language, code: $0.code)
            }
        }
    }
}
