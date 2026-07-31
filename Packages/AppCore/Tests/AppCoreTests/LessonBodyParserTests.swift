import Testing
@testable import AppCore

@Test func parsesHeading() {
    let segments = LessonBodyParser.parse("## Retain Cycles\nProse after.")
    guard case .heading(let title) = segments[0] else {
        Issue.record("expected heading, got \(segments[0])"); return
    }
    #expect(title == "Retain Cycles")
    guard case .prose(let body) = segments[1] else {
        Issue.record("expected prose"); return
    }
    #expect(body == "Prose after.")
}

@Test func parsesBulletList() {
    let segments = LessonBodyParser.parse("- first\n- second\n- third")
    guard case .bulletList(let items) = segments[0] else {
        Issue.record("expected bulletList, got \(segments[0])"); return
    }
    #expect(items == ["first", "second", "third"])
}

@Test func parsesNumberedList() {
    let segments = LessonBodyParser.parse("1. loadView\n2. viewDidLoad\n3. viewWillAppear")
    guard case .numberedList(let items) = segments[0] else {
        Issue.record("expected numberedList, got \(segments[0])"); return
    }
    #expect(items == ["loadView", "viewDidLoad", "viewWillAppear"])
}

@Test func numberedListPreservesAuthoredOrderNotAuthoredNumbers() {
    // Rendering numbers from position means sloppy authored numbering still reads right.
    let segments = LessonBodyParser.parse("1. alpha\n1. beta\n1. gamma")
    guard case .numberedList(let items) = segments[0] else {
        Issue.record("expected numberedList"); return
    }
    #expect(items == ["alpha", "beta", "gamma"])
}

@Test func listTerminatesOnBlankLine() {
    let segments = LessonBodyParser.parse("- a\n- b\n\nAfter the list.")
    guard case .bulletList(let items) = segments[0] else {
        Issue.record("expected bulletList"); return
    }
    #expect(items == ["a", "b"])
    guard case .prose(let after) = segments[1] else {
        Issue.record("expected prose"); return
    }
    #expect(after == "After the list.")
}

@Test func headingImmediatelyFollowedByList() {
    let segments = LessonBodyParser.parse("## Rules\n- one\n- two")
    #expect(segments.count == 2)
    guard case .heading = segments[0] else { Issue.record("expected heading"); return }
    guard case .bulletList(let items) = segments[1] else {
        Issue.record("expected bulletList"); return
    }
    #expect(items == ["one", "two"])
}

@Test func stillParsesFencedCodeWithFilename() {
    let body = "Intro.\n```swift\n// Point.swift\nstruct Point {}\n```\nOutro."
    let segments = LessonBodyParser.parse(body)
    guard case .code(let filename, let language, let code) = segments[1] else {
        Issue.record("expected code, got \(segments[1])"); return
    }
    #expect(filename == "Point.swift")
    #expect(language == "swift")
    #expect(code == "struct Point {}")
}

@Test func stillParsesKeyIdea() {
    let segments = LessonBodyParser.parse("> KEY: Values copy, references share.")
    guard case .keyIdea(let idea) = segments[0] else {
        Issue.record("expected keyIdea"); return
    }
    #expect(idea == "Values copy, references share.")
}

@Test func blankLineSplitsProseIntoSeparateParagraphs() {
    // One segment per paragraph: `AttributedString(markdown:)` throws away block
    // structure, so a merged block renders as "first paragraph.Second paragraph."
    let segments = LessonBodyParser.parse("First para.\n\n**Second para:**\n\nThird para.")
    #expect(segments.count == 3)
    guard case .prose(let a) = segments[0], case .prose(let b) = segments[1],
          case .prose(let c) = segments[2] else {
        Issue.record("expected three prose segments, got \(segments)"); return
    }
    #expect(a == "First para.")
    #expect(b == "**Second para:**")
    #expect(c == "Third para.")
}

@Test func softWrappedLinesStayInOneParagraph() {
    let segments = LessonBodyParser.parse("A sentence\ncontinued on the next line.")
    #expect(segments.count == 1)
    guard case .prose(let body) = segments[0] else {
        Issue.record("expected one prose segment"); return
    }
    #expect(body == "A sentence\ncontinued on the next line.")
}

@Test func runsOfBlankLinesDoNotProduceEmptyParagraphs() {
    let segments = LessonBodyParser.parse("One.\n\n\n \n\nTwo.")
    #expect(segments.count == 2)
}

@Test func markersInsideFencedCodeAreNotParsedAsBlocks() {
    let body = "```swift\n// - not a bullet\n// ## not a heading\n```"
    let segments = LessonBodyParser.parse(body)
    #expect(segments.count == 1)
    guard case .code = segments[0] else { Issue.record("expected code only"); return }
}
