import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct ReviewItemView: View {
    let entries: [ReviewEntry]
    let onDone: () -> Void

    @State private var currentIndex: Int = 0
    @State private var selectedLesson: Lesson? = nil
    @State private var retrySession: DrillSession? = nil
    @Query private var profiles: [UserProfile]
    private var profile: UserProfile? { profiles.first }

    private var entry: ReviewEntry { entries[currentIndex] }
    private var question: Question { entry.question }
    private var topic: Topic { entry.topic }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(question.prompt)
                    .font(DSFont.question)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let cs = question.codeSnippet {
                    CodeBlock(filename: cs.filename, language: cs.language, code: cs.code)
                }

                if question.kind == .behavioral {
                    behavioralAnswerSection
                } else {
                    answersSection
                }

                whyCard

                if let lesson = firstIncompleteLesson {
                    coversGapRow(lesson)
                }
            }
            .padding(DSSpacing.sessionInset)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(currentIndex < entries.count - 1 ? "Next review" : "Done") {
                    if currentIndex < entries.count - 1 {
                        currentIndex += 1
                    } else {
                        onDone()
                    }
                }
                .font(DSFont.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DSColor.action)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))

                Button("Retry") {
                    retrySession = DrillSession(questions: [entry.question])
                }
                .font(DSFont.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DSColor.actionTint)
                .foregroundStyle(DSColor.action)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
            }
            .padding(DSSpacing.sessionInset)
            .background(.bar)
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Review").font(DSFont.headline)
                    Text("\(currentIndex + 1) of \(entries.count)")
                        .font(DSFont.badge)
                        .foregroundStyle(DSColor.secondaryLabel)
                        .monospacedDigit()
                }
            }
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
        .fullScreenCover(item: $retrySession) { session in
            NavigationStack {
                if let profile {
                    QuestionPlayerView(session: session, topic: entry.topic, profile: profile)
                }
            }
        }
        .navigationDestination(item: $selectedLesson) { lesson in
            let sorted = topic.lessons.sorted { $0.order < $1.order }
            let idx = sorted.firstIndex(where: { $0.id == lesson.id }) ?? 0
            let next = sorted.indices.contains(idx + 1) ? sorted[idx + 1] : nil
            LessonReaderView(
                lesson: lesson,
                lessonIndex: idx + 1,
                totalLessons: sorted.count,
                nextLesson: next
            )
        }
    }

    // MARK: - Answers section

    private var answersSection: some View {
        VStack(spacing: 8) {
            let wasWrong = entry.item.wasWrong
            let pickedText = pickedOptionText

            answerRow(
                label: "Your answer",
                text: pickedText ?? "Skipped",
                isCorrect: !wasWrong,
                icon: wasWrong ? "xmark.circle.fill" : "checkmark.circle.fill"
            )

            if wasWrong,
               let correctIdx = question.correctIndex,
               let correct = question.options.first(where: { $0.order == correctIdx }) {
                answerRow(
                    label: "Correct answer",
                    text: correct.text,
                    isCorrect: true,
                    icon: "checkmark.circle.fill"
                )
            }
        }
    }

    private var pickedOptionText: String? {
        guard let picked = entry.item.pickedIndex else { return nil }
        return question.options.first(where: { $0.order == picked })?.text
    }

    // MARK: - Behavioral answer section

    private var behavioralAnswerSection: some View {
        let rating = entry.item.selfRating
        return answerRow(
            label: "You rated yourself",
            text: rating?.label ?? "Skipped",
            isCorrect: rating?.countsAsCorrect ?? false,
            icon: (rating?.countsAsCorrect ?? false) ? "checkmark.circle.fill" : "xmark.circle.fill"
        )
    }

    private func answerRow(label: String, text: String, isCorrect: Bool, icon: String) -> some View {
        GroupedCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(isCorrect ? DSColor.green : DSColor.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.secondaryLabel)
                    Text(text)
                        .font(DSFont.body)
                }
                Spacer()
            }
        }
        .background(
            (isCorrect ? DSColor.green : DSColor.red).opacity(0.10)
        )
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
    }

    // MARK: - Why card

    private var whyCard: some View {
        GroupedCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Why")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.secondaryLabel)
                Text(question.kind == .behavioral ? (question.rubric ?? question.explanation) : question.explanation)
                    .font(DSFont.body)
            }
        }
    }

    // MARK: - Covers gap row

    private var firstIncompleteLesson: Lesson? {
        topic.lessons.sorted { $0.order < $1.order }.first(where: { !$0.isComplete })
    }

    private func coversGapRow(_ lesson: Lesson) -> some View {
        GroupedCard(padding: 0) {
            HStack(spacing: 12) {
                Image(systemName: "text.book.closed")
                    .foregroundStyle(DSColor.action)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Covers this gap")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.secondaryLabel)
                    Text(lesson.title)
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
        .onTapGesture { selectedLesson = lesson }
    }
}
