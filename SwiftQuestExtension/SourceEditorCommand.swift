import Foundation
import AppKit
import XcodeKit
import os.log

final class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        os_log(.default, log: OSLog(subsystem: "com.gabrielnetto.SwiftQuest.XcodeExtension", category: "Command"), "Explain This Swift invoked (selections: %d)", invocation.buffer.selections.count)
        let lines = invocation.buffer.lines.compactMap { $0 as? String }
        let selected = invocation.buffer.selections.compactMap { rawSelection -> String? in
            guard let selection = rawSelection as? XCSourceTextRange else { return nil }
            guard !lines.isEmpty, selection.start.line < lines.count else { return nil }
            let start = max(0, selection.start.line)
            let end = min(selection.end.line, lines.count - 1)
            guard start <= end else { return nil }
            return lines[start...end].joined(separator: "\n")
        }.joined(separator: "\n\n")

        let fullSource = selected.isEmpty ? lines.joined(separator: "\n") : selected
        let source = String(fullSource.prefix(20_000))
        let message = SwiftQuestMessage(command: .explain, source: source, projectName: invocation.buffer.contentUTI)
        do {
            let data = try JSONEncoder().encode(message)
            let payload = String(data: data, encoding: .utf8) ?? "{}"
            // Hand the payload to the host app through its swiftquest:// URL scheme.
            var components = URLComponents()
            components.scheme = "swiftquest"
            components.host = "explain"
            components.queryItems = [URLQueryItem(name: "payload", value: payload)]
            if let url = components.url {
                NSWorkspace.shared.open(url)
            }
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
}

