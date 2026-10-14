import Foundation
import AppKit
import XcodeKit
import os.log

final class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    private static let log = OSLog(subsystem: "com.gabrielnetto.SwiftQuest.XcodeExtension", category: "Command")

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        let id = invocation.commandIdentifier
        os_log(.default, log: Self.log, "SwiftQuest command %{public}@ invoked (selections: %d)", id, invocation.buffer.selections.count)

        let lines = invocation.buffer.lines.compactMap { $0 as? String }
        let ranges = invocation.buffer.selections.compactMap { $0 as? XCSourceTextRange }
        let selected = ranges.compactMap { selection -> String? in
            guard !lines.isEmpty, selection.start.line < lines.count else { return nil }
            let start = max(0, selection.start.line)
            let end = min(selection.end.line, lines.count - 1)
            guard start <= end else { return nil }
            return lines[start...end].joined(separator: "\n")
        }.joined(separator: "\n\n")
        // Empty selection: fall back to the whole file.
        let source = String((selected.isEmpty ? lines.joined(separator: "\n") : selected).prefix(20_000))

        if id.hasSuffix(".comment") {
            insertExplanationComments(invocation: invocation, source: source, firstLine: ranges.first?.start.line ?? 0, completionHandler: completionHandler)
            return
        }

        let command: SwiftQuestCommand
        switch id {
        case _ where id.hasSuffix(".flashcard"): command = .flashcard
        case _ where id.hasSuffix(".exercise"): command = .exercise
        default: command = .explain
        }
        send(SwiftQuestMessage(command: command, source: source, projectName: invocation.buffer.contentUTI),
             completionHandler: completionHandler)
    }

    /// Hands the payload to the host app through its swiftquest:// URL scheme.
    private func send(_ message: SwiftQuestMessage, completionHandler: @escaping (Error?) -> Void) {
        do {
            let payload = String(data: try JSONEncoder().encode(message), encoding: .utf8) ?? "{}"
            var components = URLComponents()
            components.scheme = "swiftquest"
            components.host = message.command.rawValue
            components.queryItems = [URLQueryItem(name: "payload", value: payload)]
            if let url = components.url { NSWorkspace.shared.open(url) }
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    /// Writes short explanations of the Swift concepts it finds as comments above the selection, right in the editor.
    private func insertExplanationComments(invocation: XCSourceEditorCommandInvocation, source: String, firstLine: Int,
                                           completionHandler: @escaping (Error?) -> Void) {
        let code = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        let table = InlineGlossary.meanings[code] ?? InlineGlossary.meanings["en"] ?? [:]
        let found = ExplainRules.matches(in: source).compactMap { match -> String? in
            guard let meaning = table[match.term] else { return nil }
            return "// SwiftQuest · \(match.term): \(meaning)"
        }.prefix(6)

        guard !found.isEmpty else {
            let message = code == "pt" ? "Nenhum conceito Swift conhecido encontrado." :
                          code == "es" ? "No se encontraron conceptos de Swift conocidos." :
                          "No known Swift concepts found."
            completionHandler(NSError(domain: "SwiftQuest", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
            return
        }

        let lines = invocation.buffer.lines
        let index = min(max(0, firstLine), lines.count)
        let current = index < lines.count ? (lines[index] as? String ?? "") : ""
        let indent = String(current.prefix { $0 == " " || $0 == "\t" })
        for text in found.reversed() {
            lines.insert(indent + text, at: index)
        }
        completionHandler(nil)
    }
}
