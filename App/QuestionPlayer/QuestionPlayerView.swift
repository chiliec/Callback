import SwiftUI
import AppCore
import DesignSystem

struct QuestionPlayerView: View {
    @State var session: DrillSession
    let topic: Topic
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SaveErrorState.self) private var saveError

    private static let labels = ["A", "B", "C", "D"]

    var body: some View {
        if session.isComplete {
            drillCompleteView
        } else if let question = session.current {
            questionView(question)
        }
    }

    // MARK: Question screen

    @ViewBuilder
    private func questionView(_ question: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Kicker
                Text(topic.name.uppercased())
                    .font(DSFont.sectionHeader)
                    .foregroundStyle(DSColor.secondaryLabel)

                // Question text
                Text(question.prompt)
                    .font(DSFont.question)

                // Optional code block
                if let snippet = question.codeSnippet {
                    CodeBlock(
                        filename: snippet.filename,
                        language: snippet.language,
                        code: snippet.code
                    )
                }

                // Options
                let sortedOptions = question.options.sorted { $0.order < $1.order }
                ForEach(Array(sortedOptions.enumerated()), id: \.element.persistentModelID) { i, option in
                    let label = i < Self.labels.count ? Self.labels[i] : "\(i + 1)"
                    let state = answerState(optionIndex: i, question: question)
                    OptionRow(
                        label: label,
                        text: option.text,
                        isMonospaced: option.isMonospaced,
                        state: state
                    ) {
                        session.pick(i)
                    }
                    .accessibilityIdentifier("option-\(label)")
                }

                // Verdict + explanation (shown after answering); self-assessment
                // for self-rated questions (behavioral, system design) renders
                // before answering too — that's the fix.
                if question.kind.isSelfRated {
                    SelfAssessCard(
                        rubric: question.rubric ?? question.explanation,
                        isRevealed: session.isGuidanceRevealed,
                        selection: session.rating,
                        onReveal: { session.revealGuidance() },
                        onRate: { session.rate($0) }
                    )
                } else if session.isAnswered {
                    verdictView(question)
                }
            }
            .padding(DSSpacing.listInset)
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                Text("\(session.currentIndex + 1) / \(session.questions.count)")
                    .font(DSFont.headline)
                    .monospacedDigit()
            }
        }
        .sensoryFeedback(trigger: session.pickedIndex) { _, _ in .selection }
        .sensoryFeedback(trigger: session.isAnswered) { _, isAnswered -> SensoryFeedback? in
            guard isAnswered, let q = session.current, !q.kind.isSelfRated,
                  let picked = session.pickedIndex, let correct = q.correctIndex else { return nil }
            return picked == correct ? .success : .warning
        }
        .sensoryFeedback(.success, trigger: session.isComplete)
        .safeAreaInset(edge: .bottom) {
            if session.isAnswered {
                Button(session.currentIndex < session.questions.count - 1 ? "Next" : "Finish") {
                    if session.currentIndex < session.questions.count - 1 {
                        session.advance()
                    } else {
                        do {
                            try DrillCompletion.save(session: session, topic: topic, profile: profile, context: context)
                        } catch {
                            saveError.message = "Couldn't save your progress. Please try again."
                        }
                        session.advance() // sets isComplete = true
                    }
                }
                .font(DSFont.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DSColor.action)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
                .padding(DSSpacing.listInset)
                .background(.bar)
                .accessibilityIdentifier("next-finish-button")
            }
        }
    }

    // MARK: Verdict

    @ViewBuilder
    private func verdictView(_ question: Question) -> some View {
        if let picked = session.pickedIndex {
            let correct = question.correctIndex.map { picked == $0 } ?? false
            HStack(spacing: 6) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .accessibilityHidden(true)
                Text(correct ? "Correct" : "Not quite")
                    .font(DSFont.headline)
            }
            .foregroundStyle(correct ? DSColor.greenText : DSColor.redText)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((correct ? DSColor.green : DSColor.red).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
            .accessibilityIdentifier("verdict-chip")
            .accessibilityAddTraits(.isStaticText)
        }

        GroupedCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Why")
                    .font(DSFont.headline)
                Text(question.explanation)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.secondaryLabel)
            }
        }
    }

    // MARK: Drill complete

    private var drillCompleteView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(DSColor.green)
            Text("Drill complete")
                .font(DSFont.readerTitle)
            let correct = zip(session.questions, session.picks)
                .filter { q, p in p == q.correctIndex && q.correctIndex != nil }
                .count
            let total = session.questions.filter { $0.correctIndex != nil }.count
            if total > 0 {
                Text("\(correct) of \(total) correct")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.secondaryLabel)
            } else {
                Text("\(session.questions.count) questions reviewed")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.secondaryLabel)
            }
            Button("Done") { dismiss() }
                .font(DSFont.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DSColor.action)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
                .padding(.horizontal, DSSpacing.listInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.groupedBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    // MARK: Answer state helper

    private func answerState(optionIndex: Int, question: Question) -> AnswerState {
        guard session.isAnswered else { return .idle }
        let picked = session.pickedIndex
        if question.kind.isSelfRated {
            return optionIndex == picked ? .correct : .fadedIncorrect
        }
        if let correct = question.correctIndex, optionIndex == correct { return .correct }
        if optionIndex == picked { return .wrongPick }
        return .fadedIncorrect
    }
}
