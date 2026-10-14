import Foundation

// Built-in, AI-free introductory lessons. Content lives in Content/intro.<lang>.json.

struct LessonSection: Codable, Sendable {
    let heading: String
    let body: String
    var code: String? = nil
}

struct QuizQuestion: Codable, Identifiable, Sendable {
    let id: String
    let prompt: String
    let choices: [String]
    let answer: Int
    let explanation: String
}

struct Lesson: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let icon: String
    let summary: String
    let sections: [LessonSection]
    let exercise: String
    let quiz: [QuizQuestion]
}

struct GlossaryEntry: Sendable {
    let term: String
    let pattern: String      // regular expression matched against the user's code
    let meaning: String
    let lessonID: String
}

struct IntroContent: Codable, Sendable {
    let lessons: [Lesson]
    let glossary: [String: String]   // term -> localized meaning

    static func load(_ language: AppLanguage) -> IntroContent {
        for lang in [language, .en] {
            if let url = Bundle.main.url(forResource: "intro.\(lang.rawValue)", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let content = try? JSONDecoder().decode(IntroContent.self, from: data) {
                return content
            }
        }
        return IntroContent(lessons: [], glossary: [:])
    }
}

enum Curriculum {
    // Language-independent detection rules; the explanation text comes from the localized JSON.
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

    static func explain(_ source: String, glossary: [String: String]) -> [GlossaryEntry] {
        rules.compactMap { rule in
            guard source.range(of: rule.pattern, options: .regularExpression) != nil,
                  let meaning = glossary[rule.term] else { return nil }
            return GlossaryEntry(term: rule.term, pattern: rule.pattern, meaning: meaning, lessonID: rule.lessonID)
        }
    }
}
