import SwiftUI
import AppKit

/// Exports the learner's progress as Markdown or JSON.
@MainActor
enum ProgressExporter {
    static func markdown(loc: Localizer, course: CourseProgress, lessons: ProgressStore) -> String {
        let stats = course.stats
        let habits = HabitStore.shared
        var md = "# SwiftQuest — \(loc.t("export.title"))\n\n"
        md += "- \(loc.t("level")) \(stats.level.level) · \(loc.levelTitle(stats.level.level)) — \(stats.points) XP\n"
        md += "- \(loc.t("habit.streak.days")): \(habits.streak)\n"
        md += "- \(loc.t("nav.badges")): \(stats.unlockedBadges.count)/\(loc.badges.count)\n"
        md += "- \(loc.t("nav.flashcards")): \(FlashcardStore.shared.cards.count)\n"
        md += "- \(loc.t("pg.challenges")): \(course.snapshot.solvedChallenges.count)/\(loc.challenges.count)\n\n"
        md += "## \(loc.t("nav.learn"))\n\n"
        for l in loc.lessons { md += "- [\(lessons.completed.contains(l.id) ? "x" : " ")] \(l.title)\n" }
        md += "\n## \(loc.t("nav.course"))\n\n| Pillar | % | \(loc.t("quiz")) | \(loc.t("exercises")) |\n|---|---|---|---|\n"
        for p in loc.pillars {
            let r = course.progress(for: p)
            md += "| \(p.id). \(p.title) | \(r.percentage)% | \(r.quizScore)/\(p.quiz.count) | \(r.exercisesDone)/\(p.exercises.count) |\n"
        }
        md += "\n## \(loc.t("nav.exams"))\n\n"
        for e in loc.exams { md += "- [\(course.snapshot.passedExams.contains(e.id) ? "x" : " ")] \(e.title)\n" }
        md += "\n## \(loc.t("nav.badges"))\n\n"
        for b in loc.badges where stats.unlockedBadges.contains(b.id) { md += "- \(b.title) (+\(b.xpReward) XP)\n" }
        if !course.snapshot.savedTerms.isEmpty {
            md += "\n## \(loc.t("nav.glossary"))\n\n"
            for t in course.snapshot.savedTerms { md += "- \(t)\n" }
        }
        return md
    }

    static func json(loc: Localizer, course: CourseProgress, lessons: ProgressStore) -> String {
        let stats = course.stats
        let payload: [String: Any] = [
            "app": "SwiftQuest",
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "xp": stats.points,
            "level": stats.level.level,
            "streakDays": HabitStore.shared.streak,
            "completedLessons": Array(lessons.completed).sorted(),
            "badges": Array(stats.unlockedBadges).sorted(),
            "passedExams": course.snapshot.passedExams,
            "solvedChallenges": course.snapshot.solvedChallenges,
            "savedTerms": course.snapshot.savedTerms,
            "pillars": loc.pillars.map { p -> [String: Any] in
                let r = course.progress(for: p)
                return ["id": p.id, "title": p.title, "percent": r.percentage, "quiz": r.quizScore, "exercises": r.exercisesDone]
            }
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    static func save(_ text: String, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
