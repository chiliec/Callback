import SwiftUI
import SwiftData
import AppCore
import DesignSystem

// MARK: - Body parser

enum BodySegment {
    case prose(String)
    case code(filename: String?, language: String, body: String)
    case keyIdea(String)
}

struct LessonBodyParser {
    static func parse(_ markdown: String) -> [BodySegment] {
        var segments: [BodySegment] = []
        var proseLines: [String] = []
        var inCode = false
        var codeLang = ""
        var codeLines: [String] = []

        func flushProse() {
            let block = proseLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !block.isEmpty { segments.append(.prose(block)) }
            proseLines = []
        }

        for line in markdown.components(separatedBy: "\n") {
            if inCode {
                if line.hasPrefix("```") {
                    // Extract optional filename from first code line
                    var filename: String? = nil
                    var body = codeLines
                    if let first = body.first, first.hasPrefix("// "), first.hasSuffix(".swift") {
                        filename = String(first.dropFirst(3))
                        body = Array(body.dropFirst())
                    }
                    segments.append(.code(filename: filename, language: codeLang, body: body.joined(separator: "\n")))
                    codeLines = []
                    inCode = false
                } else {
                    codeLines.append(line)
                }
            } else if line.hasPrefix("```") {
                flushProse()
                codeLang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if codeLang.isEmpty { codeLang = "swift" }
                inCode = true
            } else if line.hasPrefix("> KEY:") {
                flushProse()
                let idea = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                segments.append(.keyIdea(idea))
            } else {
                proseLines.append(line)
            }
        }
        flushProse()
        return segments
    }
}

// MARK: - LessonReaderView

struct LessonReaderView: View {
    let lesson: Lesson
    let lessonIndex: Int
    let totalLessons: Int
    let nextLesson: Lesson?

    @State private var readingProgress: Double = 0
    @State private var isComplete: Bool
    @Environment(\.modelContext) private var context

    init(lesson: Lesson, lessonIndex: Int, totalLessons: Int, nextLesson: Lesson?) {
        self.lesson = lesson
        self.lessonIndex = lessonIndex
        self.totalLessons = totalLessons
        self.nextLesson = nextLesson
        self._isComplete = State(initialValue: lesson.isComplete)
    }

    private var segments: [BodySegment] {
        LessonBodyParser.parse(lesson.body)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    segmentView(segment)
                }

                if isComplete {
                    completedCard
                } else {
                    markCompleteButton
                }

                if let next = nextLesson {
                    upNextRow(next)
                }

                if let quickCheck = lesson.quickCheck {
                    QuickCheckView(question: quickCheck)
                }
            }
            .padding(DSSpacing.sessionInset)
        }
        .onScrollGeometryChange(for: Double.self) { geo in
            let offset = geo.contentOffset.y
            let total = geo.contentSize.height - geo.containerSize.height
            return total > 0 ? min(1, max(0, offset / total)) : 0
        } action: { _, newValue in
            readingProgress = newValue
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            GeometryReader { geo in
                Rectangle()
                    .fill(DSColor.action)
                    .frame(width: geo.size.width * readingProgress, height: 3)
                    .animation(.linear(duration: 0.1), value: readingProgress)
            }
            .frame(height: 3)
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(lesson.title)
                        .font(DSFont.headline)
                        .lineLimit(1)
                    Text("Lesson \(lessonIndex) of \(totalLessons) · \(Int(readingProgress * 100))%")
                        .font(DSFont.badge)
                        .foregroundStyle(DSColor.secondaryLabel)
                        .monospacedDigit()
                }
            }
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
    }

    // MARK: - Segment rendering

    @ViewBuilder
    private func segmentView(_ segment: BodySegment) -> some View {
        switch segment {
        case .prose(let text):
            if let attributed = try? AttributedString(markdown: text) {
                Text(attributed)
                    .font(DSFont.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text)
                    .font(DSFont.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .code(let filename, let language, let body):
            CodeBlock(filename: filename ?? "snippet.swift", language: language, code: body)
        case .keyIdea(let text):
            HStack(spacing: 12) {
                Rectangle()
                    .fill(DSColor.action)
                    .frame(width: 3)
                    .clipShape(Capsule())
                Text(text)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.action)
            }
            .padding(14)
            .background(DSColor.actionTint)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Mark complete

    private var markCompleteButton: some View {
        Button {
            markComplete()
        } label: {
            Text("Mark complete")
                .font(DSFont.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DSColor.action)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var completedCard: some View {
        GroupedCard {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DSColor.green)
                Text("Lesson complete · +1 mastery")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.greenText)
                Spacer()
                Button("Undo") { undoComplete() }
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.secondaryLabel)
            }
        }
        .background(DSColor.green.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
    }

    private func upNextRow(_ next: Lesson) -> some View {
        GroupedCard(padding: 0) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(DSColor.action)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Up next")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.secondaryLabel)
                    Text(next.title)
                        .font(DSFont.body)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: DSSpacing.rowMinHeight)
        }
    }

    // MARK: - Mark complete logic

    private func markComplete() {
        lesson.isComplete = true
        lesson.completedAt = .now
        lesson.topic?.mastery = min(100, (lesson.topic?.mastery ?? 0) + 1)
        recomputeReadiness()
        try? context.save()
        isComplete = true
    }

    private func undoComplete() {
        lesson.isComplete = false
        lesson.completedAt = nil
        lesson.topic?.mastery = max(0, (lesson.topic?.mastery ?? 0) - 1)
        recomputeReadiness()
        try? context.save()
        isComplete = false
    }

    private func recomputeReadiness() {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard let profile = profiles.first else { return }
        let topics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []
        let records = (try? context.fetch(FetchDescriptor<AnswerRecord>())) ?? []
        let countsByTopic = Dictionary(grouping: records, by: \.topicID).mapValues { $0.count }
        let inputs = topics.map {
            ScoringEngine.TopicReadinessInput(mastery: $0.mastery, answeredCount: countsByTopic[$0.id] ?? 0)
        }
        profile.readiness = ScoringEngine().readiness(topics: inputs)
    }
}

// MARK: - QuickCheckView

struct QuickCheckView: View {
    let question: Question

    @State private var pickedIndex: Int? = nil

    private static let labels = ["A", "B", "C", "D"]

    var body: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Check")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.secondaryLabel)

                Text(question.prompt)
                    .font(DSFont.headline)

                let sortedOptions = question.options.sorted { $0.order < $1.order }
                ForEach(Array(sortedOptions.enumerated()), id: \.element.persistentModelID) { i, option in
                    OptionRow(
                        label: i < Self.labels.count ? Self.labels[i] : "\(i + 1)",
                        text: option.text,
                        isMonospaced: option.isMonospaced,
                        state: optionState(index: i)
                    ) {
                        if pickedIndex == nil { pickedIndex = i }
                    }
                }

                if pickedIndex != nil {
                    Text(question.explanation)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.secondaryLabel)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func optionState(index: Int) -> AnswerState {
        guard let picked = pickedIndex else { return .idle }
        if index == picked {
            return (question.correctIndex == picked) ? .correct : .wrongPick
        }
        if index == question.correctIndex { return .correct }
        return .idle
    }
}
