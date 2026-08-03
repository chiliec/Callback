import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct PlacementQuizView: View {
    @State var session: PlacementSession
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(SaveErrorState.self) private var saveError

    @State private var autoAdvanceTask: Task<Void, Never>? = nil
    @State private var resultPath: [PlacementResult] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var profile: UserProfile? { profiles.first }
    private static let labels = ["A", "B", "C", "D"]

    var body: some View {
        NavigationStack(path: $resultPath) {
            VStack(spacing: 0) {
                progressBar
                if !session.isComplete, let question = session.current {
                    questionContent(question)
                }
            }
            .background(DSColor.groupedBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        autoAdvanceTask?.cancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .principal) {
                    let shown = min(session.currentIndex + 1, session.questions.count)
                    Text("\(shown) / \(session.questions.count)")
                        .font(DSFont.headline)
                        .monospacedDigit()
                }
            }
            .navigationDestination(for: PlacementResult.self) { result in
                PlacementResultsView(result: result)
            }
        }
        .sensoryFeedback(trigger: session.currentIndex) { _, _ in .selection }
        .sensoryFeedback(.success, trigger: session.isComplete)
    }

    // MARK: Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(DSColor.action)
                .frame(width: geo.size.width * session.progress, height: 3)
                .animation(
                    DSMotion.animation(.linear(duration: DSMotion.standard), reduceMotion: reduceMotion),
                    value: session.progress
                )
        }
        .frame(height: 3)
    }

    // MARK: Question content

    @ViewBuilder
    private func questionContent(_ question: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let topic = question.topic {
                    Text(topic.name.uppercased())
                        .font(DSFont.sectionHeader)
                        .foregroundStyle(DSColor.secondaryLabel)
                }

                Text(inlineMarkdown: question.prompt)
                    .font(DSFont.question)

                if let snippet = question.codeSnippet {
                    CodeBlock(
                        filename: snippet.filename,
                        language: snippet.language,
                        code: snippet.code
                    )
                }

                let sortedOptions = question.options.sorted { $0.order < $1.order }
                ForEach(Array(sortedOptions.enumerated()), id: \.element.persistentModelID) { i, option in
                    OptionRow(
                        label: i < Self.labels.count ? Self.labels[i] : "\(i + 1)",
                        text: option.text,
                        isMonospaced: option.isMonospaced,
                        state: optionState(index: i)
                    ) {
                        handlePick(index: i)
                    }
                }

                if question.kind.isSelfRated {
                    SelfAssessCard(
                        rubric: question.rubric ?? question.explanation,
                        isRevealed: session.isGuidanceRevealed,
                        selection: session.rating,
                        onReveal: { session.revealGuidance() },
                        onRate: { handleRate($0) }
                    )
                }

                Button("Not sure yet — skip") {
                    autoAdvanceTask?.cancel()
                    session.skip()
                    checkComplete()
                }
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.secondaryLabel)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            .padding(DSSpacing.sessionInset)
        }
    }

    // MARK: Option state

    private func optionState(index: Int) -> AnswerState {
        let idx = session.currentIndex
        guard session.picks.indices.contains(idx) else { return .idle }
        let pick = session.picks[idx]
        guard let pick else { return .idle }
        return index == pick ? .selected : .fadedIncorrect
    }

    // MARK: Pick + auto-advance

    private func handlePick(index: Int) {
        let idx = session.currentIndex
        guard session.picks.indices.contains(idx),
              session.picks[idx] == nil else { return }
        session.pick(index)
        scheduleAutoAdvance()
    }

    private func handleRate(_ rating: SelfRating) {
        session.rate(rating)
        scheduleAutoAdvance()
    }

    private func scheduleAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(450))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            _ = session.advance()
            checkComplete()
        }
    }

    private func checkComplete() {
        guard session.isComplete else { return }
        guard let profile else { return }
        do {
            let result = try PlacementCompletion.save(
                placement: session, profile: profile, context: context
            )
            resultPath.append(result)
        } catch {
            saveError.message = "Couldn't save your progress. Please try again."
        }
    }
}

#Preview {
    PlacementQuizView(session: PlacementSession(questions: [
        Question(
            id: "q1", kind: .multipleChoice,
            prompt: "What does ARC stand for?",
            explanation: "Automatic Reference Counting.",
            correctIndex: 0,
            options: [
                Option(text: "Automatic Reference Counting", isMonospaced: false, order: 0),
                Option(text: "Async Runtime Context", isMonospaced: false, order: 1)
            ]
        )
    ]))
    .modelContainer(try! AppModelContainer.make(inMemory: true))
    .environment(AppCoordinator())
    .environment(SaveErrorState())
}
