public enum Grading {
    /// A behavioral question has no key — its self-rating is the grade.
    public static func isCorrect(question: Question, pickedIndex: Int?, selfRating: SelfRating?) -> Bool {
        if let correctIndex = question.correctIndex, let pickedIndex {
            return pickedIndex == correctIndex
        }
        return selfRating?.countsAsCorrect ?? false
    }
}
