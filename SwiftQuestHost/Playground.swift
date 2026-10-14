import SwiftUI
import AppKit

// MARK: - Running Swift code

struct RunResult: Sendable {
    var output = ""
    var errors = ""
    var exitCode: Int32 = 0
    var timedOut = false
    var toolMissing = false
}

enum SwiftRunner {
    static let toolPath = "/usr/bin/swift"

    /// Runs `code` with the system Swift toolchain (installed with Xcode / the Command Line Tools).
    static func run(_ code: String, timeout: TimeInterval = 20) async -> RunResult {
        await Task.detached(priority: .userInitiated) { () -> RunResult in
            guard FileManager.default.isExecutableFile(atPath: toolPath) else {
                return RunResult(toolMissing: true)
            }
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("swiftquest-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: dir) }
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let file = dir.appendingPathComponent("main.swift")
                try code.write(to: file, atomically: true, encoding: .utf8)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: toolPath)
                process.arguments = [file.path]
                process.currentDirectoryURL = dir
                let out = Pipe(), err = Pipe()
                process.standardOutput = out
                process.standardError = err
                process.standardInput = FileHandle.nullDevice

                var result = RunResult()
                let outBox = DataBox(), errBox = DataBox()
                out.fileHandleForReading.readabilityHandler = { outBox.append($0.availableData) }
                err.fileHandleForReading.readabilityHandler = { errBox.append($0.availableData) }

                try process.run()
                let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
                process.waitUntilExit()
                result.timedOut = killer.isCancelled == false && process.terminationReason == .uncaughtSignal && process.terminationStatus == SIGTERM
                killer.cancel()

                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                outBox.append(out.fileHandleForReading.readDataToEndOfFile())
                errBox.append(err.fileHandleForReading.readDataToEndOfFile())
                result.output = String(decoding: outBox.data, as: UTF8.self)
                result.errors = String(decoding: errBox.data, as: UTF8.self)
                result.exitCode = process.terminationStatus
                return result
            } catch {
                return RunResult(errors: error.localizedDescription, exitCode: -1)
            }
        }.value
    }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()
    func append(_ d: Data) { lock.lock(); storage.append(d); lock.unlock() }
    var data: Data { lock.lock(); defer { lock.unlock() }; return storage }
}

// MARK: - Challenges

struct CodeChallenge: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let prompt: String
    let hint: String
    let starter: String
    let solution: String
    let expected: String
}

// MARK: - Editor (NSTextView without smart quotes/dashes, which would break code)

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextCompletionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isRichText = false
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.delegate = context.coordinator
        tv.string = text
        tv.setAccessibilityLabel("Swift code editor")
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView, tv.string != text else { return }
        tv.string = text
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: CodeEditor
        init(_ parent: CodeEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

// MARK: - View

struct PlaygroundView: View {
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var progress: CourseProgress
    @State private var selected = "free"
    @State private var code = "print(\"Hello, SwiftQuest!\")\n"
    @State private var result: RunResult?
    @State private var running = false
    @State private var showHint = false
    @State private var showSolution = false
    @State private var verdict: Bool?

    private var challenge: CodeChallenge? { loc.challenges.first { $0.id == selected } }

    var body: some View {
        HStack(spacing: 0) {
            List(selection: Binding(get: { Optional(selected) }, set: { select($0 ?? "free") })) {
                Label(loc.t("pg.free"), systemImage: "terminal.fill").tag("free")
                Section(loc.t("pg.challenges")) {
                    ForEach(loc.challenges) { c in
                        HStack {
                            Text(c.title)
                            Spacer()
                            if progress.isSolved(c.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        }
                        .tag(c.id)
                    }
                }
            }
            .frame(width: 240)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if let c = challenge {
                    Text(c.title).font(.title.bold())
                    Text(c.prompt)
                } else {
                    Text(loc.t("pg.free")).font(.title.bold())
                    Text(loc.t("pg.free.sub")).foregroundStyle(.secondary)
                }
                CodeEditor(text: $code)
                    .frame(minHeight: 220)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                HStack {
                    Button { Task { await run() } } label: { Label(loc.t("pg.run"), systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(running)
                    if running { ProgressView().controlSize(.small) }
                    if let c = challenge {
                        Button(showHint ? loc.t("hint.hide") : loc.t("hint")) { showHint.toggle() }
                        Button(loc.t("pg.reset")) { code = c.starter; result = nil; verdict = nil }
                        Button(showSolution ? loc.t("pg.solution.hide") : loc.t("pg.solution")) { showSolution.toggle() }
                    }
                    Spacer()
                    Text("⌘↩").font(.caption).foregroundStyle(.tertiary)
                }
                if let c = challenge {
                    if showHint { Text(c.hint).font(.callout).foregroundStyle(.secondary) }
                    if showSolution { CodeBlock(code: c.solution) }
                }
                if let verdict {
                    Label(verdict ? loc.t("pg.pass") : loc.t("pg.fail"), systemImage: verdict ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.headline).foregroundStyle(verdict ? .green : .red)
                    if !verdict, let c = challenge {
                        Text("\(loc.t("pg.expected")):").font(.caption.bold())
                        CodeBlock(code: c.expected)
                    }
                }
                Text(loc.t("pg.output")).font(.headline)
                ScrollView {
                    Text(outputText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(minHeight: 100)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(20)
        }
    }

    private var outputText: String {
        guard let r = result else { return running ? "…" : "" }
        if r.toolMissing { return loc.t("pg.notool") }
        if r.timedOut { return loc.t("pg.timeout") }
        return r.output + (r.errors.isEmpty ? "" : (r.output.isEmpty ? "" : "\n") + r.errors)
    }

    private func select(_ id: String) {
        selected = id
        result = nil; verdict = nil; showHint = false; showSolution = false
        code = loc.challenges.first { $0.id == id }?.starter ?? "print(\"Hello, SwiftQuest!\")\n"
    }

    private func run() async {
        running = true
        verdict = nil
        let r = await SwiftRunner.run(code)
        result = r
        running = false
        if let c = challenge, !r.toolMissing, !r.timedOut {
            let ok = r.exitCode == 0 &&
                r.output.trimmingCharacters(in: .whitespacesAndNewlines) == c.expected.trimmingCharacters(in: .whitespacesAndNewlines)
            verdict = ok
            progress.recordAttempt(topic: "c:\(c.id)", correct: ok)
            if ok { progress.markSolved(c.id) }
        }
    }
}
