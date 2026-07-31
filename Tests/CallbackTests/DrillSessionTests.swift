// Tests/CallbackTests/DrillSessionTests.swift
import Foundation
import Testing
@testable import Callback
import AppCore

@Suite("DrillSession")
struct DrillSessionTests {

    private func makeQuestion(id: String = "q1") -> Question {
        Question(id: id, kind: .behavioral, prompt: "Tell me about a time...", explanation: "E.",
                 correctIndex: nil, rubric: "Look for STAR structure.")
    }

    private func makeSession(count: Int = 2) -> DrillSession {
        DrillSession(questions: (0..<count).map { makeQuestion(id: "q\($0)") })
    }

    @Test func rateFlipsIsAnswered() {
        let s = makeSession()
        #expect(!s.isAnswered)
        s.rate(.ok)
        #expect(s.rating == .ok)
        #expect(s.isAnswered)
    }

    @Test func advancingThenReturningRestoresIsAnsweredFromRating() {
        let s = makeSession(count: 2)
        s.rate(.strong)
        s.advance()
        #expect(!s.isAnswered)
        s.rate(.weak)
        s.advance()
        #expect(s.isComplete)
    }

    @Test func reRatingOverwrites() {
        let s = makeSession()
        s.rate(.weak)
        s.rate(.strong)
        #expect(s.rating == .strong)
    }

    @Test func revealGuidanceIsPerIndex() {
        let s = makeSession(count: 2)
        s.revealGuidance()
        #expect(s.isGuidanceRevealed)
        s.rate(.ok)
        s.advance()
        #expect(!s.isGuidanceRevealed)
    }
}
