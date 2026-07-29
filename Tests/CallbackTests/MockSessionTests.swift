// Tests/CallbackTests/MockSessionTests.swift
import Foundation
import Testing
@testable import Callback
import AppCore

@Suite("MockSession")
@MainActor
struct MockSessionTests {

    private func makeQuestion(id: String = "q1", correctIndex: Int = 0) -> Question {
        Question(id: id, kind: .multipleChoice, prompt: "Q?", explanation: "E.",
                 correctIndex: correctIndex,
                 options: [Option(text: "A", isMonospaced: false, order: 0),
                           Option(text: "B", isMonospaced: false, order: 1)])
    }

    private func makeSession(count: Int = 2, total: Int = 60) -> MockSession {
        let qs = (0..<count).map { makeQuestion(id: "q\($0)") }
        return MockSession(sessionKind: .mock, level: .mid, questions: qs, totalSeconds: total)
    }

    @Test func initialState() {
        let s = makeSession()
        #expect(s.elapsedSeconds == 0)
        #expect(s.timeRemaining == 60)
        #expect(s.currentIndex == 0)
        #expect(!s.isAnswered)
        #expect(!s.isComplete)
        #expect(!s.isPaused)
        #expect(s.isFlagged == false)
    }

    @Test func timeRemainingDecrementsOnTick() {
        let s = makeSession(total: 60)
        s.tick()
        s.tick()
        #expect(s.elapsedSeconds == 2)
        #expect(s.timeRemaining == 58)
    }

    @Test func tickDoesNotRunWhenPaused() {
        let s = makeSession()
        s.pause()
        s.tick()
        #expect(s.elapsedSeconds == 0)
    }

    @Test func tickDoesNotRunWhenComplete() {
        let s = makeSession(count: 1)
        s.endSession()
        s.tick()
        #expect(s.elapsedSeconds == 0)
    }

    @Test func tickCompletesSessionWhenTimerExpires() {
        let s = makeSession(total: 2)
        s.tick()
        s.tick()
        #expect(s.isComplete)
    }

    @Test func pickLocksAnswerAndSetsIsAnswered() {
        let s = makeSession()
        s.pick(1)
        #expect(s.pickedIndex == 1)
        #expect(s.isAnswered)
    }

    @Test func pickIsIdempotentWhenAlreadyAnswered() {
        let s = makeSession()
        s.pick(0)
        s.pick(1)  // should be ignored
        #expect(s.pickedIndex == 0)
    }

    @Test func advanceMovesToNextQuestion() {
        let s = makeSession(count: 2)
        s.pick(0)
        s.advance()
        #expect(s.currentIndex == 1)
        #expect(!s.isAnswered)  // fresh question
    }

    @Test func advanceOnLastQuestionCompletesSession() {
        let s = makeSession(count: 1)
        s.pick(0)
        s.advance()
        #expect(s.isComplete)
    }

    @Test func toggleFlagFlipsFlag() {
        let s = makeSession()
        #expect(!s.isFlagged)
        s.toggleFlag()
        #expect(s.isFlagged)
        s.toggleFlag()
        #expect(!s.isFlagged)
    }

    @Test func endSessionSetsIsComplete() {
        let s = makeSession()
        s.endSession()
        #expect(s.isComplete)
    }

    @Test func backgroundForegroundAddsElapsedTime() {
        let s = makeSession(total: 600)
        let t0 = Date()
        s.tick() // 1 second already elapsed
        let bgDate = t0.addingTimeInterval(1)
        let fgDate = bgDate.addingTimeInterval(30)
        s.sceneDidBackground(at: bgDate)
        s.sceneDidForeground(at: fgDate)
        // 1 (tick) + 30 (background) = 31
        #expect(s.elapsedSeconds == 31)
    }

    @Test func backgroundForegroundDoesNotExceedTotal() {
        let s = makeSession(total: 10)
        let bg = Date()
        let fg = bg.addingTimeInterval(100)
        s.sceneDidBackground(at: bg)
        s.sceneDidForeground(at: fg)
        #expect(s.elapsedSeconds == 10)
        #expect(s.isComplete)
    }

    @Test func progressReflectsCurrentIndex() {
        let s = makeSession(count: 4)
        // currentIndex = 0, progress = 1/4 = 0.25
        #expect(abs(s.progress - 0.25) < 0.001)
        s.pick(0)
        s.advance()
        // currentIndex = 1, progress = 2/4 = 0.5
        #expect(abs(s.progress - 0.5) < 0.001)
    }
}
