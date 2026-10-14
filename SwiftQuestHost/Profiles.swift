import SwiftUI
import CryptoKit

// MARK: - Per-profile storage

extension Notification.Name {
    static let profileDidChange = Notification.Name("SwiftQuestProfileDidChange")
}

/// Keys for per-profile data. The original (pre-login) data belongs to the profile with id "default",
/// so existing progress keeps working after the update.
enum Storage {
    @MainActor static func key(_ name: String) -> String {
        let id = ProfileStore.shared.current?.id ?? "default"
        return id == "default" ? name : "p.\(id).\(name)"
    }
}

// MARK: - Profiles ("login")

struct Profile: Codable, Identifiable, Sendable {
    let id: String
    var name: String
    var emoji: String
    var pinHash: String?
    var pinSalt: String?
    let created: Date

    var hasPIN: Bool { pinHash != nil }
}

/// Local profiles on this Mac: each learner has separate progress, flashcards, habits and statistics.
/// A PIN is an optional convenience lock for the profile; it is not encryption and nothing leaves the device.
@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()
    static let avatars = ["🦊", "🐼", "🦁", "🐙", "🦉", "🐯", "🐸", "🦄", "🐳", "🚀", "🎮", "⭐️"]

    @Published private(set) var profiles: [Profile]
    @Published private(set) var current: Profile?
    private let profilesKey = "profiles"
    private let lastKey = "lastProfileID"

    private init() {
        var list: [Profile] = []
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let saved = try? JSONDecoder().decode([Profile].self, from: data) {
            list = saved
        }
        if list.isEmpty {
            // First launch with profiles: the existing data becomes the default profile.
            list = [Profile(id: "default", name: NSFullUserName().split(separator: " ").first.map(String.init) ?? "Me",
                            emoji: "🦊", pinHash: nil, pinSalt: nil, created: Date())]
        }
        profiles = list
        let lastID = UserDefaults.standard.string(forKey: lastKey)
        if let last = list.first(where: { $0.id == lastID }), !last.hasPIN {
            current = last                      // no PIN: go straight in
        } else {
            current = nil                       // PIN or explicit sign-out: show the sign-in screen
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) { UserDefaults.standard.set(data, forKey: profilesKey) }
    }

    private static func hash(_ pin: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + pin).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    func create(name: String, emoji: String, pin: String) -> Profile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let salt = UUID().uuidString
        let profile = Profile(id: UUID().uuidString.prefix(8).lowercased(), name: trimmed.isEmpty ? "Learner" : trimmed, emoji: emoji,
                              pinHash: pin.isEmpty ? nil : Self.hash(pin, salt: salt), pinSalt: pin.isEmpty ? nil : salt, created: Date())
        profiles.append(profile)
        persist()
        enter(profile)
        return profile
    }

    /// Signs in; returns false when the PIN is wrong.
    func signIn(_ profile: Profile, pin: String) -> Bool {
        if let hash = profile.pinHash, let salt = profile.pinSalt, Self.hash(pin, salt: salt) != hash { return false }
        enter(profile)
        return true
    }

    private func enter(_ profile: Profile) {
        current = profile
        UserDefaults.standard.set(profile.id, forKey: lastKey)
        HabitStore.shared.reload()
        FlashcardStore.shared.reload()
        NotificationCenter.default.post(name: .profileDidChange, object: nil)
    }

    func signOut() {
        current = nil
        UserDefaults.standard.removeObject(forKey: lastKey)
    }

    func delete(_ profile: Profile) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == profile.id }
        for name in ["courseProgress", "completedLessons", "flashcards", "habitCounts", "habitGoal", "onboardingDone"] {
            UserDefaults.standard.removeObject(forKey: profile.id == "default" ? name : "p.\(profile.id).\(name)")
        }
        if current?.id == profile.id { current = nil }
        persist()
    }
}

// MARK: - Sign-in screen

struct SignInView: View {
    @ObservedObject var store = ProfileStore.shared
    @EnvironmentObject var loc: Localizer
    @State private var selected: Profile?
    @State private var pin = ""
    @State private var wrongPIN = false
    @State private var creating = false
    @State private var newName = ""
    @State private var newPIN = ""
    @State private var newEmoji = ProfileStore.avatars[0]

    var body: some View {
        VStack(spacing: 22) {
            Text("SwiftQuest").font(.system(size: 34, weight: .bold))
            Text(loc.t("login.who")).font(.title3).foregroundStyle(.secondary)
            if creating {
                createForm
            } else if let profile = selected {
                pinForm(profile)
            } else {
                HStack(spacing: 18) {
                    ForEach(store.profiles) { p in
                        Button {
                            if p.hasPIN { selected = p; pin = ""; wrongPIN = false } else { _ = store.signIn(p, pin: "") }
                        } label: {
                            VStack(spacing: 8) {
                                Text(p.emoji).font(.system(size: 44))
                                    .frame(width: 84, height: 84)
                                    .background(.quaternary.opacity(0.5), in: Circle())
                                HStack(spacing: 4) {
                                    Text(p.name).font(.headline)
                                    if p.hasPIN { Image(systemName: "lock.fill").font(.caption) }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(p.name + (p.hasPIN ? ", " + loc.t("login.locked") : ""))
                        .contextMenu {
                            if store.profiles.count > 1 {
                                Button(loc.t("delete") + " \(p.name)", role: .destructive) { store.delete(p) }
                            }
                        }
                    }
                    Button { creating = true } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus").font(.system(size: 30))
                                .frame(width: 84, height: 84)
                                .background(.quaternary.opacity(0.3), in: Circle())
                            Text(loc.t("login.new")).font(.headline)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Text(loc.t("login.local")).font(.footnote).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pinForm(_ profile: Profile) -> some View {
        VStack(spacing: 12) {
            Text(profile.emoji).font(.system(size: 54))
            Text(profile.name).font(.title2.bold())
            SecureField(loc.t("login.pin"), text: $pin)
                .textFieldStyle(.roundedBorder).frame(width: 200).onSubmit { attempt(profile) }
            if wrongPIN { Text(loc.t("login.wrong")).foregroundStyle(.red) }
            HStack {
                Button(loc.t("cancel")) { selected = nil }
                Button(loc.t("login.enter")) { attempt(profile) }.buttonStyle(.borderedProminent)
            }
        }
    }

    private func attempt(_ profile: Profile) {
        if !store.signIn(profile, pin: pin) { wrongPIN = true; pin = "" }
    }

    private var createForm: some View {
        VStack(spacing: 12) {
            Text(newEmoji).font(.system(size: 54))
            HStack {
                ForEach(ProfileStore.avatars, id: \.self) { e in
                    Button(e) { newEmoji = e }.buttonStyle(.plain).font(.title2)
                        .opacity(newEmoji == e ? 1 : 0.45)
                }
            }
            TextField(loc.t("login.name"), text: $newName).textFieldStyle(.roundedBorder).frame(width: 240)
            SecureField(loc.t("login.pin.optional"), text: $newPIN).textFieldStyle(.roundedBorder).frame(width: 240)
            HStack {
                Button(loc.t("cancel")) { creating = false }
                Button(loc.t("login.create")) {
                    store.create(name: newName, emoji: newEmoji, pin: newPIN)
                    creating = false; newName = ""; newPIN = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
