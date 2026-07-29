import Foundation
import SwiftData

public enum ContentLoader {
    public static func decode(_ data: Data) throws -> ContentBundle {
        try JSONDecoder().decode(ContentBundle.self, from: data)
    }

    public static func bundledContentData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "content-v1", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }

    /// Inserts the full content graph. Assumes an empty (or additive) store.
    public static func seed(_ bundle: ContentBundle, into context: ModelContext) {
        for t in bundle.topics {
            let topic = Topic(
                id: t.id, name: t.name, section: t.section,
                symbolName: t.symbolName, colorToken: t.colorToken, order: t.order
            )
            context.insert(topic)

            for l in t.lessons {
                let lesson = Lesson(
                    id: l.id, order: l.order, title: l.title,
                    estimatedMinutes: l.estimatedMinutes, body: l.body,
                    quickCheck: l.quickCheck.map(makeQuestion)
                )
                lesson.topic = topic
                topic.lessons.append(lesson)
            }

            for q in t.questions {
                let question = makeQuestion(q)
                question.topic = topic
                topic.questions.append(question)
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
            correctIndex: q.correctIndex, rubric: q.rubric,
            codeSnippet: snippet, options: options
        )
    }
}
