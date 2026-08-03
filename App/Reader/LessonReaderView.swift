import SwiftUI
import SwiftData
import AppCore
import DesignSystem

// MARK: - LessonReaderView

struct LessonReaderView: View {
    let lesson: Lesson
    let lessonIndex: Int
    let totalLessons: Int
    let nextLesson: Lesson?

    @State private var readingProgress: Double = 0
    @State private var isComplete: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The reader works out where it is from the lesson itself, so every
    /// `navigationDestination` that opens one — topic detail, the review queue —
    /// gets the same "Lesson n of m" and the same "Up next".
    init(lesson: Lesson) {
        let position = lesson.positionInTopic
        self.lesson = lesson
        self.lessonIndex = position.index
        self.totalLessons = position.total
        self.nextLesson = position.next
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
                    // The topic is passed in, not read off the question: the
                    // content loader hangs a quick check off its `Lesson` only,
                    // so `Question.topic` is nil for every one of them.
                    QuickCheckView(question: quickCheck, topic: lesson.topic)
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
                    .animation(
                        DSMotion.animation(.linear(duration: 0.1), reduceMotion: reduceMotion),
                        value: readingProgress
                    )
            }
            .frame(height: 3)
        }
        .sensoryFeedback(.success, trigger: isComplete)
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
        case .heading(let title):
            // Markdown-parsed like prose: headings such as "### What `async` marks"
            // otherwise show their backticks verbatim.
            Text((try? AttributedString(markdown: title)) ?? AttributedString(title))
                .font(DSFont.headline)
                .foregroundStyle(DSColor.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    listRow(marker: "•", text: item)
                }
            }
        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    listRow(marker: "\(index + 1).", text: item)
                }
            }
        }
    }

    /// Shared row for both list kinds. The marker column is fixed-width so
    /// wrapped lines align under the text, not under the marker.
    private func listRow(marker: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(DSFont.body)
                .foregroundStyle(DSColor.secondaryLabel)
                .frame(minWidth: 20, alignment: .trailing)
            if let attributed = try? AttributedString(markdown: text) {
                Text(attributed).font(DSFont.body)
            } else {
                Text(text).font(DSFont.body)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// It reads as a row, so it has to act like one — as a plain card it was the
    /// app's only dead end, which is what build 17's "No way to continue."
    /// feedback was about.
    ///
    /// A view-based link rather than `NavigationLink(value:)`: the reader is also
    /// reached from the review queue, which is presented with
    /// `navigationDestination(isPresented:)`, and value links inside that segment
    /// resolve against no destination and silently do nothing.
    private func upNextRow(_ next: Lesson) -> some View {
        NavigationLink {
            LessonReaderView(lesson: next)
        } label: {
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
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DSColor.secondaryLabel)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: DSSpacing.rowMinHeight)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("lesson-up-next")
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
    /// The lesson's topic. `question.topic` is always nil here — the loader
    /// attaches a quick check to its lesson, not to the topic's question bank —
    /// so answers used to be filed under an empty topic id and scored nothing.
    let topic: Topic?

    @State private var pickedIndex: Int? = nil
    @State private var isGuidanceRevealed = false
    @State private var rating: SelfRating? = nil
    @Environment(\.modelContext) private var context
    @Environment(SaveErrorState.self) private var saveError

    private static let labels = ["A", "B", "C", "D"]

    /// True once the reader has committed either kind of answer, which is what
    /// reveals the explanation.
    private var isAnswered: Bool { pickedIndex != nil || rating != nil }

    var body: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Check")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.secondaryLabel)

                Text(inlineMarkdown: question.prompt)
                    .font(DSFont.headline)

                // Behavioral and system-design quick checks have no gradable
                // answer and ship with `options: []` — without this branch the
                // card renders a prompt and nothing else, and the authored
                // rubric is unreachable. `QuestionPlayerView` has always had
                // the equivalent; the reader's card never got it.
                if question.kind.isSelfRated {
                    SelfAssessCard(
                        rubric: question.rubric ?? question.explanation,
                        isRevealed: isGuidanceRevealed,
                        selection: rating,
                        onReveal: { isGuidanceRevealed = true },
                        onRate: { newRating in
                            guard rating == nil else { return }
                            rating = newRating
                            persistAnswer(pickedIndex: nil, rating: newRating)
                        }
                    )
                } else {
                    let sortedOptions = question.options.sorted { $0.order < $1.order }
                    ForEach(Array(sortedOptions.enumerated()), id: \.element.persistentModelID) { i, option in
                        OptionRow(
                            label: i < Self.labels.count ? Self.labels[i] : "\(i + 1)",
                            text: option.text,
                            isMonospaced: option.isMonospaced,
                            state: optionState(index: i)
                        ) {
                            guard pickedIndex == nil else { return }
                            pickedIndex = i
                            persistAnswer(pickedIndex: i, rating: nil)
                        }
                    }
                }

                if isAnswered {
                    Text(inlineMarkdown: question.explanation)
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

    private func persistAnswer(pickedIndex: Int?, rating: SelfRating?) {
        let record = AnswerRecord(
            questionID: question.id,
            topicID: topic?.id ?? "",
            pickedIndex: pickedIndex,
            isCorrect: Grading.isCorrect(question: question, pickedIndex: pickedIndex, selfRating: rating),
            isFlagged: false,
            answeredAt: Date(),
            selfRating: rating
        )
        context.insert(record)

        // Recompute mastery and readiness for the affected topic. Credit-based,
        // matching `DrillCompletion`: a self-rated answer is worth 0/0.5/1, so
        // scoring it as a plain correct/incorrect bool here would round every
        // "Decent" in the topic up to a full mark.
        if let topic {
            let topicID = topic.id
            let topicRecords = (try? context.fetch(
                FetchDescriptor<AnswerRecord>(predicate: #Predicate { $0.topicID == topicID })
            )) ?? []
            let credits = topicRecords.sorted { $0.answeredAt < $1.answeredAt }.map { $0.credit }
            topic.mastery = ScoringEngine().mastery(fromChronologicalCredit: credits)
        }
        recomputeReadiness()

        do {
            try context.save()
        } catch {
            saveError.message = "Couldn't save your progress. Please try again."
        }
    }
}
