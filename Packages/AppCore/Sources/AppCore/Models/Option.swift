import SwiftData

@Model
public final class Option {
    public var text: String
    public var isMonospaced: Bool
    public var order: Int

    public init(text: String, isMonospaced: Bool = false, order: Int) {
        self.text = text
        self.isMonospaced = isMonospaced
        self.order = order
    }
}
