import Foundation

/// Language-independent rules that detect Swift concepts in a piece of code.
/// Shared by the host app (explanations, flashcards, exercises) and the Xcode extension (inline comments).
enum ExplainRules {
    static let rules: [(term: String, pattern: String, lessonID: String)] = [
        ("let", "\\blet\\b", "values"),
        ("var", "\\bvar\\b", "values"),
        ("func", "\\bfunc\\b", "functions"),
        ("guard", "\\bguard\\b", "optionals"),
        ("if let", "\\bif\\s+(let|var)\\b", "optionals"),
        ("Optional (?)", "\\w\\?(\\s|\\)|,|=|\\.|$)|\\?\\?", "optionals"),
        ("Force unwrap (!)", "\\w!(\\s|\\)|\\.|,|$)", "optionals"),
        ("struct", "\\bstruct\\b", "types"),
        ("class", "\\bclass\\b", "types"),
        ("enum", "\\benum\\b", "types"),
        ("switch", "\\bswitch\\b", "types"),
        ("protocol", "\\bprotocol\\b", "types"),
        ("extension", "\\bextension\\b", "types"),
        ("for-in", "\\bfor\\b.+\\bin\\b", "collections"),
        ("map/filter/reduce", "\\.(map|filter|reduce|compactMap|flatMap)\\b", "collections"),
        ("Closure ($0)", "\\$\\d|\\{\\s*\\w+\\s+in\\b", "collections"),
        ("View / body", ":\\s*View\\b|\\bvar\\s+body\\b", "swiftui"),
        ("@State", "@State\\b", "swiftui"),
        ("@Published / ObservableObject", "@Published\\b|ObservableObject\\b", "swiftui"),
        ("Stacks", "\\b(VStack|HStack|ZStack)\\b", "swiftui")
    ]

    /// Terms (in rule order) whose pattern matches `source`.
    static func matches(in source: String) -> [(term: String, lessonID: String)] {
        rules.compactMap { rule in
            source.range(of: rule.pattern, options: .regularExpression) != nil ? (rule.term, rule.lessonID) : nil
        }
    }
}
