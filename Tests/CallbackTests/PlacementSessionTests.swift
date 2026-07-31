// Tests/CallbackTests/PlacementSessionTests.swift
import Foundation
import Testing
@testable import Callback
import AppCore

@Suite("PlacementSession")
struct PlacementSessionTests {

    private func makeQuestion(id: String = "q1") -> Question {
        Question(id: id, kind: .behavioral, prompt: "Tell me about a time...", explanation: "E.",
                 correctIndex: nil, rubric: "Look for STAR structure.")
    }

    private func makeSession(count: Int = 2) -> PlacementSession {
        PlacementSession(questions: (0..<count).map { makeQuestion(id: "q\($0)") })
    }

    @Test func rateSetsRating() {
        let s = makeSession()
        #expect(s.rating == nil)
        s.rate(.ok)
        #expect(s.rating == .ok)
    }

    @Test func reRatingOverwrites() {
        let s = makeSession()
        s.rate(.weak)
        s.rate(.strong)
        #expect(s.rating == .strong)
    }

    @Test func skipClearsRating() {
        let s = makeSession(count: 2)
        s.rate(.strong)
        s.skip()
        #expect(s.currentIndex == 1)
        s.advance()
        #expect(s.isComplete)
    }

    @Test func revealGuidanceIsPerIndex() {
        let s = makeSession(count: 2)
        s.revealGuidance()
        #expect(s.isGuidanceRevealed)
        s.advance()
        #expect(!s.isGuidanceRevealed)
    }
}
