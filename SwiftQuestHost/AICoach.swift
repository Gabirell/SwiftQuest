import SwiftUI
import Security

// Optional AI coach. Bring-your-own Anthropic API key, stored in the Keychain.
// Nothing is sent anywhere unless the user presses an "Ask" button.

enum KeychainStore {
    private static let service = "com.gabrielnetto.SwiftQuest.aicoach"
    private static let account = "anthropic-api-key"

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String) {
        SecItemDelete(baseQuery as CFDictionary)
        guard !key.isEmpty else { return }
        var query = baseQuery
        query[kSecValueData as String] = Data(key.utf8)
        SecItemAdd(query as CFDictionary, nil)
    }
}

@MainActor
final class AICoachSettings: ObservableObject {
    static let defaultModel = "claude-sonnet-5-5"

    @Published var apiKey: String {
        didSet { KeychainStore.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "aiCoachModel") }
    }

    init() {
        apiKey = KeychainStore.read() ?? ""
        model = UserDefaults.standard.string(forKey: "aiCoachModel") ?? Self.defaultModel
    }

    var isConfigured: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct AICoachError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct AICoachService: Sendable {
    let apiKey: String
    let model: String

    private static let system = """
    You are SwiftQuest's Swift tutor. The learner is studying Swift and Apple development. \
    Explain clearly in plain language, step by step, for a beginner. Point out the key Swift concepts used, \
    why the code works, and one thing to try next. Keep it under 350 words. Use short Markdown.
    """

    func ask(code: String, question: String, answerLanguage: String) async throws -> String {
        var userText = "Swift code:\n```swift\n\(code)\n```"
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        userText += q.isEmpty ? "\n\nExplain what this code does." : "\n\nQuestion: \(q)"
        userText += "\n\nAnswer in \(answerLanguage)."

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": Self.system,
            "messages": [["role": "user", "content": userText]]
        ]
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let detail = (json?["error"] as? [String: Any])?["message"] as? String ?? "HTTP \(http.statusCode)"
            throw AICoachError(message: detail)
        }
        let blocks = json?["content"] as? [[String: Any]] ?? []
        let text = blocks.compactMap { $0["text"] as? String }.joined(separator: "\n")
        guard !text.isEmpty else { throw AICoachError(message: "The AI returned an empty answer.") }
        return text
    }
}

struct AICoachSettingsView: View {
    @EnvironmentObject var settings: AICoachSettings
    @EnvironmentObject var loc: Localizer

    var body: some View {
        Form {
            Section(loc.t("ai.title")) {
                SecureField(loc.t("ai.key"), text: $settings.apiKey)
                TextField(loc.t("ai.model"), text: $settings.model)
                Text(loc.t("ai.privacy")).font(.footnote).foregroundStyle(.secondary)
            }
            Section(loc.t("language")) {
                Picker(loc.t("language"), selection: $loc.language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 340)
    }
}

struct AICoachPanel: View {
    @EnvironmentObject var settings: AICoachSettings
    @EnvironmentObject var loc: Localizer
    let code: String

    @State private var question = ""
    @State private var answer: AttributedString?
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc.t("ai.panel")).font(.title3.bold())
            if !settings.isConfigured {
                Text(loc.t("ai.addkey")).foregroundStyle(.secondary)
            } else {
                TextField(loc.t("ai.question"), text: $question)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button {
                        Task { await run() }
                    } label: {
                        Label(loc.t("ai.ask"), systemImage: "sparkles")
                    }
                    .disabled(isLoading || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if isLoading { ProgressView().controlSize(.small) }
                }
                Text(loc.t("ai.sends")).font(.footnote).foregroundStyle(.tertiary)
                if let error { Text(error).foregroundStyle(.red) }
                if let answer { Text(answer).textSelection(.enabled) }
            }
        }
    }

    private func run() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        let service = AICoachService(apiKey: settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                                     model: settings.model)
        do {
            let text = try await service.ask(code: code, question: question, answerLanguage: loc.language.promptName)
            answer = markdown(text)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
