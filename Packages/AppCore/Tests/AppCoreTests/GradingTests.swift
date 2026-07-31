import Testing
@testable import AppCore

private func makeQuestion(kind: QuestionKind, correctIndex: Int?) -> Question {
    Question(id: "q", kind: kind, prompt: "p", explanation: "e", correctIndex: correctIndex)
}

@Test func gradingMultipleChoicePickedMatchesCorrectIndex() {
    let q = makeQuestion(kind: .multipleChoice, correctIndex: 1)
    #expect(Grading.isCorrect(question: q, pickedIndex: 1, selfRating: nil) == true)
    #expect(Grading.isCorrect(question: q, pickedIndex: 0, selfRating: nil) == false)
}

@Test func gradingCodePickedMatchesCorrectIndex() {
    let q = makeQuestion(kind: .code, correctIndex: 2)
    #expect(Grading.isCorrect(question: q, pickedIndex: 2, selfRating: nil) == true)
    #expect(Grading.isCorrect(question: q, pickedIndex: 1, selfRating: nil) == false)
}

@Test func gradingGradedQuestionWithNoPickIsFalse() {
    let q = makeQuestion(kind: .multipleChoice, correctIndex: 1)
    #expect(Grading.isCorrect(question: q, pickedIndex: nil, selfRating: nil) == false)
}

@Test func gradingBehavioralFallsBackToSelfRating() {
    let q = makeQuestion(kind: .behavioral, correctIndex: nil)
    #expect(Grading.isCorrect(question: q, pickedIndex: nil, selfRating: .strong) == true)
    #expect(Grading.isCorrect(question: q, pickedIndex: nil, selfRating: .ok) == true)
    #expect(Grading.isCorrect(question: q, pickedIndex: nil, selfRating: .weak) == false)
}

@Test func gradingBehavioralWithNoRatingIsFalse() {
    let q = makeQuestion(kind: .behavioral, correctIndex: nil)
    #expect(Grading.isCorrect(question: q, pickedIndex: nil, selfRating: nil) == false)
}

@Test func answerRecordCreditUsesSelfRatingWhenPresent() {
    let record = AnswerRecord(
        questionID: "q", topicID: "t", pickedIndex: nil,
        isCorrect: true, isFlagged: false, answeredAt: .now, selfRating: .ok
    )
    #expect(record.credit == 0.5)
}

@Test func answerRecordCreditFallsBackToIsCorrectWhenNoRating() {
    let correct = AnswerRecord(
        questionID: "q", topicID: "t", pickedIndex: 0,
        isCorrect: true, isFlagged: false, answeredAt: .now
    )
    #expect(correct.credit == 1)

    let wrong = AnswerRecord(
        questionID: "q", topicID: "t", pickedIndex: 0,
        isCorrect: false, isFlagged: false, answeredAt: .now
    )
    #expect(wrong.credit == 0)
}
