// App/Session/MockSessionView.swift
import SwiftUI
import SwiftData
import AppCore
import DesignSystem

struct MockSessionView: View {
    @State var session: MockSession
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]

    @State private var showPauseOverlay = false
    @State private var savedResult: MockCompletion.Result? = nil

    private static let labels = ["A", "B", "C", "D"]
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
                if showPauseOverlay {
                    pauseOverlay
                }
            }
            .navigationDestination(item: $savedResult) { result in
                SessionResultsView(result: result, onDone: onDone)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { pauseTapped() } label: {
                        Image(systemName: "pause.fill")
                    }
                    .disabled(session.isComplete)
                }
                ToolbarItem(placement: .principal) {
                    Text(timerDisplay)
                        .font(DSFont.scoreHeadline)
                        .monospacedDigit()
                        .foregroundStyle(session.timeRemaining < 60 ? DSColor.red : DSColor.label)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { session.toggleFlag() } label: {
                        Image(systemName: session.isFlagged ? "flag.fill" : "flag")
                            .foregroundStyle(session.isFlagged ? DSColor.orange : DSColor.secondaryLabel)
                    }
                    .disabled(session.isComplete)
                }
            }
        }
        .onAppear { session.startTimer() }
        .onDisappear { session.stopTimer() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: session.sceneDidBackground(at: Date())
            case .active:     session.sceneDidForeground(at: Date())
            default:          break
            }
        }
        .onChange(of: session.isComplete) { _, complete in
            guard complete, savedResult == nil else { return }
            saveSession()
        }
    }

    // MARK: Main content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            ProgressView(value: session.progress)
                .tint(DSColor.action)
                .padding(.horizontal, DSSpacing.sessionInset)
                .padding(.top, 4)
            if let question = session.current {
                questionContent(question)
            }
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
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
                Text(question.prompt)
                    .font(DSFont.question)
                if let snippet = question.codeSnippet {
                    CodeBlock(filename: snippet.filename, language: snippet.language, code: snippet.code)
                }
                let sortedOptions = question.options.sorted { $0.order < $1.order }
                ForEach(Array(sortedOptions.enumerated()), id: \.element.persistentModelID) { i, option in
                    OptionRow(
                        label: i < Self.labels.count ? Self.labels[i] : "\(i + 1)",
                        text: option.text,
                        isMonospaced: option.isMonospaced,
                        state: answerState(optionIndex: i, question: question)
                    ) {
                        session.pick(i)
                    }
                }
                if session.isAnswered {
                    verdictView(question)
                }
            }
            .padding(DSSpacing.sessionInset)
        }
        .safeAreaInset(edge: .bottom) {
            if session.isAnswered {
                Button("Next") { session.advance() }
                    .font(DSFont.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DSColor.action)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
                    .padding(DSSpacing.sessionInset)
                    .background(.bar)
            }
        }
    }

    // MARK: Verdict

    @ViewBuilder
    private func verdictView(_ question: Question) -> some View {
        let isBehavioral = question.kind == .behavioral
        if !isBehavioral, let picked = session.pickedIndex {
            let correct = question.correctIndex.map { picked == $0 } ?? false
            HStack(spacing: 6) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                Text(correct ? "Correct" : "Not quite")
                    .font(DSFont.headline)
            }
            .foregroundStyle(correct ? DSColor.greenText : DSColor.redText)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((correct ? DSColor.green : DSColor.red).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
        }
        GroupedCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(isBehavioral ? "Guidance" : "Why")
                    .font(DSFont.headline)
                Text(isBehavioral ? (question.rubric ?? question.explanation) : question.explanation)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.secondaryLabel)
            }
        }
    }

    // MARK: Pause overlay

    private var pauseOverlay: some View {
        ZStack {
            Color(red: 0.949, green: 0.949, blue: 0.969)
                .opacity(0.72)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 32) {
                Text("Paused")
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.secondaryLabel)
                Text(timerDisplay)
                    .font(.system(size: 48, weight: .bold))
                    .monospacedDigit()
                VStack(spacing: 12) {
                    Button("Resume") {
                        session.resume()
                        showPauseOverlay = false
                    }
                    .font(DSFont.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DSColor.action)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
                    Button("End Session") {
                        showPauseOverlay = false
                        session.endSession()
                    }
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.redText)
                }
                .padding(.horizontal, DSSpacing.sessionInset)
            }
        }
    }

    // MARK: Helpers

    private var timerDisplay: String {
        let m = session.timeRemaining / 60
        let s = session.timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func pauseTapped() {
        session.pause()
        showPauseOverlay = true
    }

    private func saveSession() {
        guard let profile else { return }
        guard let result = try? MockCompletion.save(
            mockSession: session,
            profile: profile,
            context: context
        ) else { return }
        savedResult = result
    }

    private func answerState(optionIndex: Int, question: Question) -> AnswerState {
        guard session.isAnswered else { return .idle }
        let picked = session.pickedIndex
        if question.kind == .behavioral {
            return optionIndex == picked ? .correct : .fadedIncorrect
        }
        if let correct = question.correctIndex, optionIndex == correct { return .correct }
        if optionIndex == picked { return .wrongPick }
        return .fadedIncorrect
    }
}
