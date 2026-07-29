import SwiftData

@Model
public final class CodeSnippet {
    public var filename: String
    public var language: String
    public var code: String

    public init(filename: String, language: String, code: String) {
        self.filename = filename
        self.language = language
        self.code = code
    }
}
