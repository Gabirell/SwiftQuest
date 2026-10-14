import Foundation

enum SwiftQuestCommand: String, Codable {
    case explain
    case challenge
    case appleQuestion
    case flashcard
    case exercise

    var title: String {
        switch self {
        case .explain: return "Explain This Swift"
        case .challenge: return "Practice This Concept"
        case .appleQuestion: return "Apple-Style Question"
        case .flashcard: return "Save as Flashcard"
        case .exercise: return "Turn Into Exercise"
        }
    }
}

struct SwiftQuestMessage: Codable {
    let command: SwiftQuestCommand
    let source: String
    let projectName: String?
}
