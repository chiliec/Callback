import Testing
import SwiftData
import Foundation
@testable import AppCore

private let sampleJSON = """
{
  "version": 1,
  "topics": [
    {
      "id": "swift",
      "name": "Swift",
      "section": "fundamentals",
      "symbolName": "swift",
      "colorToken": "swift",
      "order": 0,
      "lessons": [
        { "id": "swift-l1", "order": 0, "title": "Value vs Reference",
          "estimatedMinutes": 4, "body": "Structs are value types.",
          "quickCheck": null }
      ],
      "questions": [
        { "id": "swift-q1", "kind": "multipleChoice",
          "prompt": "Which is a value type?", "explanation": "Structs are value types.",
          "correctIndex": 0, "rubric": null, "codeSnippet": null,
          "options": [ { "text": "struct", "isMonospaced": true },
                       { "text": "class", "isMonospaced": true } ] }
      ]
    }
  ]
}
"""

@Test func decodesBundle() throws {
    let bundle = try ContentLoader.decode(Data(sampleJSON.utf8))
    #expect(bundle.version == 1)
    #expect(bundle.topics.count == 1)
    #expect(bundle.topics[0].questions[0].options.count == 2)
}

@MainActor
@Test func seedInsertsGraph() throws {
    let container = try AppModelContainer.make(inMemory: true)
    let context = container.mainContext
    let bundle = try ContentLoader.decode(Data(sampleJSON.utf8))

    ContentLoader.seed(bundle, into: context)

    let topics = try context.fetch(FetchDescriptor<Topic>())
    #expect(topics.count == 1)
    #expect(topics[0].lessons.count == 1)
    #expect(topics[0].questions.count == 1)
    #expect(topics[0].questions[0].options.count == 2)
}

@MainActor
@Test func seedIfNeededRespectsVersion() throws {
    let container = try AppModelContainer.make(inMemory: true)
    let context = container.mainContext
    let profile = UserProfile()
    context.insert(profile)
    let bundle = try ContentLoader.decode(Data(sampleJSON.utf8))

    let first = ContentLoader.seedIfNeeded(into: context, profile: profile, bundle: bundle)
    let second = ContentLoader.seedIfNeeded(into: context, profile: profile, bundle: bundle)

    #expect(first == true)
    #expect(second == false)
    #expect(profile.contentVersion == 1)
    let topics = try context.fetch(FetchDescriptor<Topic>())
    #expect(topics.count == 1)   // not double-seeded
}

@Test func bundledContentDecodes() throws {
    let bundle = try ContentLoader.bundledContent()
    #expect(bundle.version >= 1)
    #expect(bundle.topics.isEmpty == false)
}

@Test func contentBundleIsValid() throws {
    let bundle = try ContentLoader.bundledContent()

    // Version 2+
    #expect(bundle.version >= 2)

    // Exactly 9 topics with expected ids, orders 0–8 contiguous
    let expectedTopicIds: Set<String> = [
        "swift", "memory", "concurrency", "swiftui", "uikit", "behavioral",
        "testing", "architecture", "sysdesign"
    ]
    let topicIds = Set(bundle.topics.map(\.id))
    #expect(topicIds == expectedTopicIds)
    #expect(bundle.topics.count == 9)
    let orders = Set(bundle.topics.map(\.order))
    #expect(orders == Set(0..<9))

    let validSections: Set<String> = ["fundamentals", "frameworks", "craft"]
    let validColorTokens: Set<String> = [
        "swift", "memory", "concurrency", "swiftui", "uikit",
        "networking", "coredata", "systemdesign", "behavioral",
        "testing", "architecture"
    ]

    // Global id uniqueness
    var allIds: Set<String> = []
    for topic in bundle.topics {
        #expect(validSections.contains(topic.section.rawValue))
        #expect(validColorTokens.contains(topic.colorToken))

        // Per-topic minimums
        #expect(topic.lessons.count >= 2, "Topic \(topic.id) needs >= 2 lessons")
        #expect(topic.questions.count >= 8, "Topic \(topic.id) needs >= 8 questions")

        // Lesson order contiguous from 0
        let lessonOrders = topic.lessons.map(\.order).sorted()
        #expect(lessonOrders == Array(0..<topic.lessons.count), "Topic \(topic.id) lesson orders non-contiguous")

        for lesson in topic.lessons {
            #expect(!allIds.contains(lesson.id), "Duplicate id: \(lesson.id)")
            allIds.insert(lesson.id)

            #expect(lesson.id.hasPrefix("\(topic.id)-l"), "Lesson id convention: \(lesson.id)")
            #expect(lesson.quickCheck != nil, "Lesson \(lesson.id) missing quickCheck")

            if let qc = lesson.quickCheck {
                #expect(qc.id == "\(lesson.id)-qc", "QuickCheck id convention: \(qc.id)")
                #expect(!allIds.contains(qc.id), "Duplicate id: \(qc.id)")
                allIds.insert(qc.id)
                #expect(!qc.prompt.isEmpty)
                #expect(!qc.explanation.isEmpty)

                switch qc.kind {
                case .multipleChoice, .code:
                    #expect(qc.correctIndex != nil)
                    #expect(qc.options.count >= 2)
                    if let ci = qc.correctIndex {
                        #expect(ci >= 0 && ci < qc.options.count)
                    }
                case .behavioral, .systemDesign:
                    #expect(qc.correctIndex == nil)
                    #expect(qc.options.isEmpty)
                    #expect(qc.rubric != nil)
                }
            }
        }

        for q in topic.questions {
            #expect(!allIds.contains(q.id), "Duplicate id: \(q.id)")
            allIds.insert(q.id)

            #expect(q.id.hasPrefix("\(topic.id)-q"), "Question id convention: \(q.id)")
            #expect(!q.prompt.isEmpty)
            #expect(!q.explanation.isEmpty)

            switch q.kind {
            case .multipleChoice:
                #expect(q.correctIndex != nil)
                #expect(q.rubric == nil)
                #expect(q.options.count >= 2)
                if let ci = q.correctIndex {
                    #expect(ci >= 0 && ci < q.options.count)
                }
            case .code:
                #expect(q.correctIndex != nil)
                #expect(q.rubric == nil)
                #expect(q.codeSnippet != nil)
                #expect(q.options.count >= 2)
                if let ci = q.correctIndex {
                    #expect(ci >= 0 && ci < q.options.count)
                }
            case .behavioral, .systemDesign:
                #expect(q.correctIndex == nil)
                #expect(q.codeSnippet == nil)
                #expect(q.options.isEmpty)
                #expect(q.rubric != nil)
            }
        }
    }
}

@MainActor
@Test func seedIsIdempotentOnReseed() throws {
    let container = try AppModelContainer.make(inMemory: true)
    let context = container.mainContext
    let profile = UserProfile()
    context.insert(profile)

    let bundleV1 = try ContentLoader.decode(Data(sampleJSON.utf8))
    ContentLoader.seedIfNeeded(into: context, profile: profile, bundle: bundleV1)

    // Mutate user-progress fields
    let topics = try context.fetch(FetchDescriptor<Topic>())
    let topic = try #require(topics.first)
    topic.mastery = 42
    topic.isSaved = true
    let lesson = try #require(topic.lessons.first)
    lesson.isComplete = true

    // v2: same shape but changed lesson title
    let v2JSON = """
    {
      "version": 2,
      "topics": [
        {
          "id": "swift", "name": "Swift", "section": "fundamentals",
          "symbolName": "swift", "colorToken": "swift", "order": 0,
          "lessons": [
            { "id": "swift-l1", "order": 0, "title": "Value vs Reference Types — Updated",
              "estimatedMinutes": 4, "body": "Structs are value types.", "quickCheck": null }
          ],
          "questions": [
            { "id": "swift-q1", "kind": "multipleChoice",
              "prompt": "Which is a value type?", "explanation": "Structs are value types.",
              "correctIndex": 0, "rubric": null, "codeSnippet": null,
              "options": [ { "text": "struct", "isMonospaced": true },
                           { "text": "class", "isMonospaced": true } ] }
          ]
        }
      ]
    }
    """
    let bundleV2 = try ContentLoader.decode(Data(v2JSON.utf8))
    ContentLoader.seedIfNeeded(into: context, profile: profile, bundle: bundleV2)

    // No duplicate rows
    let topicsAfter = try context.fetch(FetchDescriptor<Topic>())
    #expect(topicsAfter.count == 1)
    let lessonsAfter = try context.fetch(FetchDescriptor<Lesson>())
    #expect(lessonsAfter.count == 1)
    let questionsAfter = try context.fetch(FetchDescriptor<Question>())
    #expect(questionsAfter.count == 1)

    // Author-owned content field updated
    #expect(lessonsAfter[0].title == "Value vs Reference Types — Updated")

    // User-progress fields preserved
    #expect(topicsAfter[0].mastery == 42)
    #expect(topicsAfter[0].isSaved == true)
    #expect(lessonsAfter[0].isComplete == true)
}

@Test func decodesQuestionLevel() throws {
    let json = """
    { "id": "q1", "kind": "multipleChoice", "prompt": "P", "explanation": "E",
      "correctIndex": 0, "rubric": null, "codeSnippet": null, "level": "senior",
      "options": [ { "text": "a", "isMonospaced": false },
                   { "text": "b", "isMonospaced": false } ] }
    """
    let dto = try JSONDecoder().decode(QuestionDTO.self, from: Data(json.utf8))
    #expect(dto.level == .senior)
}

@Test func missingLevelDefaultsToMid() throws {
    let json = """
    { "id": "q1", "kind": "multipleChoice", "prompt": "P", "explanation": "E",
      "correctIndex": 0, "rubric": null, "codeSnippet": null,
      "options": [ { "text": "a", "isMonospaced": false },
                   { "text": "b", "isMonospaced": false } ] }
    """
    let dto = try JSONDecoder().decode(QuestionDTO.self, from: Data(json.utf8))
    #expect(dto.level == .mid)
}

@MainActor
@Test func seedPersistsQuestionLevel() throws {
    let container = try AppModelContainer.make(inMemory: true)
    let context = container.mainContext
    let bundle = try ContentLoader.decode(Data(sampleJSON.utf8))
    ContentLoader.seed(bundle, into: context)
    let questions = try context.fetch(FetchDescriptor<Question>())
    #expect(!questions.isEmpty)
    #expect(questions.allSatisfy { Level(rawValue: $0.levelRaw) != nil })
}

@Test func bundledContentLoadsEveryTopicInTheManifest() throws {
    let bundle = try ContentLoader.bundledContent()
    #expect(bundle.version == 6)
    #expect(bundle.topics.count == 9)
    #expect(Set(bundle.topics.map(\.id)).count == bundle.topics.count)
}

@Test func reseedingIdenticalContentPreservesOptionObjects() throws {
    let container = try AppModelContainer.make(inMemory: true)
    let context = ModelContext(container)
    let bundle = try ContentLoader.decode(Data(sampleJSON.utf8))

    ContentLoader.seed(bundle, into: context)
    try context.save()
    let before = try context.fetch(FetchDescriptor<Option>())
    let beforeIDs = Set(before.map(\.persistentModelID))
    #expect(!beforeIDs.isEmpty)

    ContentLoader.seed(bundle, into: context)   // same content again
    try context.save()
    let after = try context.fetch(FetchDescriptor<Option>())

    #expect(after.count == before.count, "option count changed on an identical re-seed")
    #expect(Set(after.map(\.persistentModelID)) == beforeIDs,
            "options were rebuilt despite identical content")
}

@Test func reseedingChangedOptionsDoesRebuildThem() throws {
    let container = try AppModelContainer.make(inMemory: true)
    let context = ModelContext(container)
    ContentLoader.seed(try ContentLoader.decode(Data(sampleJSON.utf8)), into: context)
    try context.save()

    let edited = sampleJSON.replacingOccurrences(
        of: "\"text\": \"struct\"", with: "\"text\": \"A struct\"")
    #expect(edited != sampleJSON, "fixture text not found — update this test's needle")
    ContentLoader.seed(try ContentLoader.decode(Data(edited.utf8)), into: context)
    try context.save()

    let texts = try context.fetch(FetchDescriptor<Option>()).map(\.text)
    #expect(texts.contains("A struct"))
    #expect(!texts.contains("struct"))
}

@Test func bundledContentThrowsOnAMissingTopicFile() {
    #expect(throws: (any Error).self) {
        try ContentLoader.assembleContent(manifestName: "content-manifest-missing-fixture")
    }
}
