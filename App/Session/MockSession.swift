// App/Session/MockSession.swift
import Foundation
import AppCore

@MainActor @Observable final class MockSession: Identifiable {
    let id = UUID()
    let sessionKind: SessionKind
    let level: Level
    let questions: [Question]
    let totalSeconds: Int
    let startedAt: Date

    private(set) var elapsedSeconds: Int = 0
    private(set) var isPaused: Bool = false
    private(set) var isComplete: Bool = false
    private(set) var currentIndex: Int = 0
    private(set) var picks: [Int?]
    private(set) var flags: [Bool]
    private(set) var isAnswered: Bool = false

    private var timer: Timer?
    private var backgroundedAt: Date?

    init(sessionKind: SessionKind, level: Level, questions: [Question], totalSeconds: Int) {
        precondition(!questions.isEmpty, "MockSession requires at least one question")
        self.sessionKind = sessionKind
        self.level = level
        self.questions = questions
        self.totalSeconds = totalSeconds
        self.startedAt = Date()
        self.picks = Array(repeating: nil, count: questions.count)
        self.flags = Array(repeating: false, count: questions.count)
    }

    var timeRemaining: Int { max(0, totalSeconds - elapsedSeconds) }
    var current: Question? { questions.indices.contains(currentIndex) ? questions[currentIndex] : nil }
    var pickedIndex: Int? { picks.indices.contains(currentIndex) ? picks[currentIndex] : nil }
    var isFlagged: Bool { flags.indices.contains(currentIndex) ? flags[currentIndex] : false }
    var progress: Double { questions.isEmpty ? 0 : Double(currentIndex + 1) / Double(questions.count) }

    func startTimer() {
        guard timer == nil, !isComplete else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func tick() {
        guard !isPaused, !isComplete else { return }
        elapsedSeconds += 1
        if elapsedSeconds >= totalSeconds {
            complete()
        }
    }

    func pause() {
        isPaused = true
        stopTimer()
    }

    func resume() {
        isPaused = false
        startTimer()
    }

    func sceneDidBackground(at date: Date) {
        backgroundedAt = date
        stopTimer()
    }

    func sceneDidForeground(at date: Date) {
        guard let bg = backgroundedAt else { return }
        backgroundedAt = nil
        if !isPaused, !isComplete {
            let elapsed = Int(date.timeIntervalSince(bg))
            elapsedSeconds = min(elapsedSeconds + elapsed, totalSeconds)
            if elapsedSeconds >= totalSeconds {
                complete()
            } else {
                startTimer()
            }
        }
    }

    func pick(_ index: Int) {
        guard !isAnswered, questions.indices.contains(currentIndex) else { return }
        picks[currentIndex] = index
        isAnswered = true
    }

    func advance() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            isAnswered = picks[currentIndex] != nil
        } else {
            complete()
        }
    }

    func toggleFlag() {
        guard flags.indices.contains(currentIndex) else { return }
        flags[currentIndex].toggle()
    }

    func endSession() {
        complete()
    }

    private func complete() {
        isComplete = true
        stopTimer()
    }
}
