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
    let data = try ContentLoader.bundledContentData()
    let bundle = try ContentLoader.decode(data)
    #expect(bundle.version >= 1)
    #expect(bundle.topics.isEmpty == false)
}
