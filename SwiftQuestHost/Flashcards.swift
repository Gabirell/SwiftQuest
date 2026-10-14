import SwiftUI

// MARK: - Flashcards (saved from Xcode, reviewed with simple spaced repetition)

struct Flashcard: Codable, Identifiable, Sendable {
    let id: UUID
    let code: String
    let created: Date
    var box: Int
    var due: Date
}

@MainActor
final class FlashcardStore: ObservableObject {
    static let shared = FlashcardStore()
    /// Days until the next review for each Leitner box.
    static let intervals = [0, 1, 3, 7, 14, 30]
    private let key = "flashcards"
    @Published private(set) var cards: [Flashcard]

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([Flashcard].self, from: data) {
            cards = saved
        } else {
            cards = []
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cards) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// Returns false when the same code is already saved.
    @discardableResult
    func add(code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !cards.contains(where: { $0.code == trimmed }) else { return false }
        cards.append(Flashcard(id: UUID(), code: trimmed, created: Date(), box: 0, due: Date()))
        persist()
        return true
    }

    func delete(_ card: Flashcard) {
        cards.removeAll { $0.id == card.id }
        persist()
    }

    var due: [Flashcard] { cards.filter { $0.due <= Date() }.sorted { $0.due < $1.due } }

    func review(_ card: Flashcard, knewIt: Bool) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        let box = knewIt ? min(cards[i].box + 1, Self.intervals.count - 1) : 0
        cards[i].box = box
        cards[i].due = Calendar.current.date(byAdding: .day, value: Self.intervals[box], to: Date()) ?? Date()
        persist()
        HabitStore.shared.recordActivity()
    }
}

struct FlashcardsView: View {
    @ObservedObject var store = FlashcardStore.shared
    @EnvironmentObject var loc: Localizer
    @State private var revealed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("nav.flashcards")).font(.largeTitle.bold())
                Text(loc.t("flash.sub")).foregroundStyle(.secondary)
                if store.cards.isEmpty {
                    GroupBox { Text(loc.t("flash.empty")).padding(6) }
                } else if let card = store.due.first {
                    Text("\(loc.t("flash.due")): \(store.due.count)").font(.headline)
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(loc.t("flash.question")).font(.headline)
                            CodeBlock(code: card.code)
                            if revealed {
                                let entries = Curriculum.explain(card.code, glossary: loc.introGlossary)
                                if entries.isEmpty { Text(loc.t("explain.none")).foregroundStyle(.secondary) }
                                ForEach(entries, id: \.term) { e in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.term).font(.subheadline.bold().monospaced())
                                        Text(markdown(e.meaning)).font(.callout)
                                    }
                                }
                                HStack {
                                    Button(loc.t("flash.again")) { revealed = false; store.review(card, knewIt: false) }
                                    Button(loc.t("flash.knew")) { revealed = false; store.review(card, knewIt: true) }
                                        .buttonStyle(.borderedProminent)
                                }
                            } else {
                                Button(loc.t("flash.reveal")) { revealed = true }.buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Label(loc.t("flash.alldone"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                if !store.cards.isEmpty {
                    Text("\(loc.t("flash.all")) (\(store.cards.count))").font(.title3.bold())
                    ForEach(store.cards) { card in
                        GroupBox {
                            HStack(alignment: .top) {
                                Text(card.code).font(.system(.caption, design: .monospaced)).lineLimit(4)
                                Spacer()
                                Button(role: .destructive) { store.delete(card) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(loc.t("delete"))
                            }
                            .padding(4)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - "Turn this into an exercise"

enum CodeExerciseBuilder {
    static let blankable = ["let", "var", "func", "struct", "class", "enum", "guard", "switch", "protocol",
                            "extension", "return", "if", "for", "while", "async", "await", "throws", "try", "some", "static", "final"]

    /// Replaces the `index`-th (wrapping) keyword occurrence in the first lines of `source` by `___`.
    static func build(from source: String, index: Int) -> (snippet: String, answer: String, count: Int)? {
        let excerpt = source.split(separator: "\n", omittingEmptySubsequences: false).prefix(14).joined(separator: "\n")
        let pattern = "\\b(" + blankable.joined(separator: "|") + ")\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = excerpt as NSString
        var hits: [NSRange] = []
        regex.enumerateMatches(in: excerpt, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let r = m?.range else { return }
            // skip comment lines
            let lineRange = ns.lineRange(for: r)
            let line = ns.substring(with: lineRange).trimmingCharacters(in: .whitespaces)
            if !line.hasPrefix("//") { hits.append(r) }
        }
        guard !hits.isEmpty else { return nil }
        let r = hits[index % hits.count]
        return (ns.replacingCharacters(in: r, with: "___"), ns.substring(with: r), hits.count)
    }
}

struct CodeExerciseView: View {
    let source: String
    @EnvironmentObject var loc: Localizer
    @State private var index = 0
    @State private var answer = ""
    @State private var result: Bool?

    var body: some View {
        if let ex = CodeExerciseBuilder.build(from: source, index: index) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc.t("ex.title")).font(.title3.bold())
                    Text(loc.t("ex.prompt")).foregroundStyle(.secondary)
                    CodeBlock(code: ex.snippet)
                    HStack {
                        TextField(loc.t("fill.blank"), text: $answer).textFieldStyle(.roundedBorder).onSubmit { check(ex.answer) }
                        Button(loc.t("check")) { check(ex.answer) }
                        if ex.count > 1 {
                            Button(loc.t("ex.another")) { index += 1; answer = ""; result = nil }.buttonStyle(.link)
                        }
                    }
                    if result == true { Label(loc.t("correct.short"), systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                    if result == false { Label(loc.t("try.again"), systemImage: "xmark.circle.fill").foregroundStyle(.red) }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(loc.t("ex.none")).foregroundStyle(.secondary)
        }
    }

    private func check(_ expected: String) {
        let ok = answer.trimmingCharacters(in: .whitespaces) == expected
        result = ok
        if ok { HabitStore.shared.recordActivity() }
    }
}
