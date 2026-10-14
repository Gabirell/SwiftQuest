import Foundation

// Full course content imported from the "aprendendo-swift" project (Portuguese, PT-BR).
// The data lives in bundled JSON (Content/*.json); this file holds the models and the
// gamification rules (XP, levels, badges) ported from the original app.

struct CourseExercise: Codable, Identifiable, Sendable {
    let id: Int
    let question: String
    let codeSnippet: String
    let correctAnswer: String
    let hint: String
}

struct CourseQuestion: Codable, Identifiable, Sendable {
    let id: Int
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

struct Pillar: Codable, Identifiable, Sendable {
    let id: Int
    let title: String
    let theory: String
    let appleDocUrl: String?
    let category: String?
    let corporateCase: String
    let gameCase: String
    let exercises: [CourseExercise]
    let quiz: [CourseQuestion]
    let extraQuiz: [CourseQuestion]?

    var categoryName: String { category ?? "Fundamentos" }
}

struct MockExam: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let category: String
    let timeLimitMinutes: Int
    let questions: [CourseQuestion]
}

struct GlossaryTerm: Codable, Identifiable, Sendable {
    let term: String
    let definition: String
    var id: String { term }
}

struct Badge: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let category: String
    let criteria: String
    let xpReward: Int

    var symbol: String {
        switch iconName {
        case "Sparkles": "sparkles"
        case "Code2": "chevron.left.forwardslash.chevron.right"
        case "Award": "rosette"
        case "Flame": "flame.fill"
        case "ShieldCheck": "checkmark.shield.fill"
        case "BookOpen": "book.fill"
        case "Cpu": "cpu"
        case "Smartphone": "iphone"
        case "Zap": "bolt.fill"
        case "Trophy": "trophy.fill"
        case "Crown": "crown.fill"
        case "GraduationCap": "graduationcap.fill"
        default: "star.fill"
        }
    }
}

enum CourseData {
    static func load<T: Decodable>(_ name: String, _ language: AppLanguage) -> [T] {
        for lang in [language, .pt] {
            if let url = Bundle.main.url(forResource: "\(name).\(lang.rawValue)", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let items = try? JSONDecoder().decode([T].self, from: data) {
                return items
            }
        }
        return []
    }

    // Language-independent reference data (ids, counts, XP) used by the progress rules.
    static let pillars: [Pillar] = load("pillars", .pt)
    static let badges: [Badge] = load("badges", .pt)

    static let categoryOrder = ["Fundamentos", "Swift Avançado", "iOS e iPadOS", "watchOS", "macOS", "visionOS"]
    static let passingGrade = 0.7
}

struct LevelInfo {
    let level: Int
    let title: String
    let progressPercent: Double
    let nextLevelXP: Int
}

struct CourseStats {
    let points: Int
    let level: LevelInfo
    let unlockedBadges: Set<String>
}

struct CourseSnapshot: Codable {
    var exerciseAnswers: [String: String] = [:]   // "pillar-exercise" -> correct answer given
    var quizScores: [Int: Int] = [:]               // pillar id -> best number of correct answers
    var passedExams: [String] = []
    var savedTerms: [String] = []
    var seenBadges: [String] = []                  // badges the user has already been congratulated for

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exerciseAnswers = try c.decodeIfPresent([String: String].self, forKey: .exerciseAnswers) ?? [:]
        quizScores = try c.decodeIfPresent([Int: Int].self, forKey: .quizScores) ?? [:]
        passedExams = try c.decodeIfPresent([String].self, forKey: .passedExams) ?? []
        savedTerms = try c.decodeIfPresent([String].self, forKey: .savedTerms) ?? []
        seenBadges = try c.decodeIfPresent([String].self, forKey: .seenBadges) ?? []
    }
}

enum PillarStatus: Sendable {
    case notStarted, inProgress, needsReview, mastered
}

struct PillarProgress: Sendable {
    let pillar: Pillar
    let quizScore: Int
    let exercisesDone: Int
    let percentage: Int
    let status: PillarStatus
}

@MainActor
final class CourseProgress: ObservableObject {
    private let key = "courseProgress"
    @Published private(set) var snapshot: CourseSnapshot
    @Published var newlyUnlocked: Badge?
    private var pendingBadges: [Badge] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(CourseSnapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = CourseSnapshot()
        }
    }

    private func persist() {
        queueNewBadges()
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func isExerciseDone(pillar: Int, exercise: Int) -> Bool {
        snapshot.exerciseAnswers["\(pillar)-\(exercise)"] != nil
    }

    /// Returns true when the answer is correct (trimmed, case-insensitive, like the original app).
    @discardableResult
    func check(exercise: CourseExercise, pillar: Int, answer: String) -> Bool {
        let ok = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == exercise.correctAnswer.lowercased()
        if ok {
            snapshot.exerciseAnswers["\(pillar)-\(exercise.id)"] = answer
            persist()
        }
        return ok
    }

    func recordQuiz(pillar: Int, correct: Int) {
        if snapshot.quizScores[pillar] == nil || correct > (snapshot.quizScores[pillar] ?? 0) {
            snapshot.quizScores[pillar] = correct
            persist()
        }
    }

    func recordExam(id: String, passed: Bool) {
        if passed, !snapshot.passedExams.contains(id) {
            snapshot.passedExams.append(id)
            persist()
        }
    }

    func toggleTerm(_ term: String) {
        if let i = snapshot.savedTerms.firstIndex(of: term) {
            snapshot.savedTerms.remove(at: i)
        } else {
            snapshot.savedTerms.append(term)
        }
        persist()
    }

    private func queueNewBadges() {
        let unlocked = stats.unlockedBadges
        let fresh = CourseData.badges.filter { unlocked.contains($0.id) && !snapshot.seenBadges.contains($0.id) }
        guard !fresh.isEmpty else { return }
        snapshot.seenBadges.append(contentsOf: fresh.map(\.id))
        pendingBadges.append(contentsOf: fresh)
        showNextBadge()
    }

    func showNextBadge() {
        guard newlyUnlocked == nil, !pendingBadges.isEmpty else { return }
        newlyUnlocked = pendingBadges.removeFirst()
    }

    func dismissBadge() {
        newlyUnlocked = nil
        showNextBadge()
    }

    /// Same rules as the original dashboard: needs review below 60% quiz after an attempt, mastered at 80%+.
    func progress(for pillar: Pillar) -> PillarProgress {
        let attempted = snapshot.quizScores[pillar.id] != nil
        let score = snapshot.quizScores[pillar.id] ?? 0
        let done = pillar.exercises.filter { isExerciseDone(pillar: pillar.id, exercise: $0.id) }.count
        let total = pillar.quiz.count + pillar.exercises.count
        let pct = total > 0 ? Int((Double(score + done) / Double(total) * 100).rounded()) : 0
        let quizPct = pillar.quiz.isEmpty ? 0 : Double(score) / Double(pillar.quiz.count) * 100
        let status: PillarStatus
        if attempted && quizPct < 60 { status = .needsReview }
        else if pct >= 80 { status = .mastered }
        else if pct > 0 || attempted || done > 0 { status = .inProgress }
        else { status = .notStarted }
        return PillarProgress(pillar: pillar, quizScore: score, exercisesDone: done, percentage: pct, status: status)
    }

    func isSaved(_ term: String) -> Bool { snapshot.savedTerms.contains(term) }

    // MARK: Gamification (ported from the original gamification.ts)

    static func levelInfo(for xp: Int) -> LevelInfo {
        let perLevel = 100
        let level = max(1, xp / perLevel + 1)
        let title: String
        switch level {
        case 1: title = "Iniciante Swift"
        case 2: title = "Aprendiz iOS"
        case 3: title = "Desenvolvedor SwiftUI"
        case 4: title = "Arquiteto Apple"
        case 5..<8: title = "Especialista em Swift"
        default: title = "Grão-Mestre Apple"
        }
        let into = xp - (level - 1) * perLevel
        return LevelInfo(level: level, title: title,
                         progressPercent: min(1, max(0, Double(into) / Double(perLevel))),
                         nextLevelXP: level * perLevel)
    }

    var stats: CourseStats {
        let s = snapshot
        let basePoints = s.exerciseAnswers.count * 15
            + s.quizScores.values.reduce(0, +) * 5
            + s.passedExams.count * 60
            + s.savedTerms.count * 3

        var unlocked = Set<String>()
        let ex = s.exerciseAnswers.count
        if ex >= 1 { unlocked.insert("first-code") }
        if ex >= 5 { unlocked.insert("code-enthusiast") }
        if ex >= 10 { unlocked.insert("code-master") }

        let perfect = CourseData.pillars.filter { !$0.quiz.isEmpty && (s.quizScores[$0.id] ?? 0) >= $0.quiz.count }.count
        if perfect >= 1 { unlocked.insert("quiz-starter") }
        if perfect >= 4 { unlocked.insert("quiz-scholar") }
        if s.passedExams.count >= 1 { unlocked.insert("exam-approved") }
        if s.passedExams.count >= 2 { unlocked.insert("exam-champion") }
        if s.savedTerms.count >= 3 { unlocked.insert("glossary-collector") }

        // The original app referenced pillar IDs by position; here they are matched by title,
        // so the badges follow the real ARC and watchOS/macOS/visionOS pillars.
        if let arc = CourseData.pillars.first(where: { $0.title.contains("ARC") }),
           (s.quizScores[arc.id] ?? 0) >= 3 { unlocked.insert("memory-guardian") }
        let ecosystem = CourseData.pillars
            .filter { ["watchOS", "macOS", "visionOS"].contains($0.categoryName) }
            .reduce(0) { $0 + (s.quizScores[$1.id] ?? 0) }
        if ecosystem >= 2 { unlocked.insert("ecosystem-explorer") }
        if basePoints >= 100 { unlocked.insert("century-club") }
        if basePoints >= 350 { unlocked.insert("swift-legend") }

        let bonus = CourseData.badges.filter { unlocked.contains($0.id) }.reduce(0) { $0 + $1.xpReward }
        let total = basePoints + bonus
        return CourseStats(points: total, level: Self.levelInfo(for: total), unlockedBadges: unlocked)
    }
}
