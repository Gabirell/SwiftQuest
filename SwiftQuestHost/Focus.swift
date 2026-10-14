import SwiftUI

// MARK: - "Needs attention": weak-topic analysis

extension Localizer {
    /// Display name for a statistics topic key ("p:12", "l:optionals", "e:Fundamentos", "c:fizzbuzz").
    func topicName(_ key: String) -> String {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return key }
        switch parts[0] {
        case "p": return pillars.first { String($0.id) == parts[1] }.map { "\($0.id). \($0.title)" } ?? key
        case "l": return lessons.first { $0.id == parts[1] }?.title ?? key
        case "e": return "\(t("nav.exams")) · \(category(parts[1]))"
        case "c": return "\(t("pg.challenges")) · \(challenges.first { $0.id == parts[1] }?.title ?? parts[1])"
        default: return key
        }
    }
}

@MainActor
extension SwiftQuestRoute {
    func openTopic(_ key: String) {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        switch parts[0] {
        case "p": pillarTarget = Int(parts[1]); selection = .course
        case "l": lessonTarget = parts[1]; selection = .learn
        case "e": selection = .exams
        case "c": selection = .playground
        default: break
        }
    }
}

struct FocusView: View {
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var course: CourseProgress
    @EnvironmentObject var route: SwiftQuestRoute
    @State private var drilling = false

    var body: some View {
        let weak = course.weakTopics()
        let strong = course.snapshot.topicStats
            .filter { $0.value.attempts >= 3 && $0.value.recentAccuracy >= 0.75 }
            .sorted { $0.value.recentAccuracy > $1.value.recentAccuracy }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("nav.focus")).font(.largeTitle.bold())
                Text(loc.t("focus.sub")).foregroundStyle(.secondary)
                if course.snapshot.topicStats.isEmpty {
                    GroupBox { Text(loc.t("focus.empty")).padding(6) }
                } else if weak.isEmpty {
                    Label(loc.t("focus.none"), systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                } else {
                    if let first = weak.first {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(loc.t("focus.next"), systemImage: "target").font(.headline).foregroundStyle(.orange)
                                Text(loc.topicName(first.topic)).font(.title3.bold())
                                HStack {
                                    Button(loc.t("focus.study")) { route.openTopic(first.topic) }.buttonStyle(.borderedProminent)
                                    Button(loc.t("focus.drill")) { drilling = true }
                                }
                            }
                            .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text(loc.t("focus.weak")).font(.title3.bold())
                    ForEach(weak, id: \.topic) { row in topicRow(row.topic, row.stat, color: .orange) }
                }
                if !strong.isEmpty {
                    Text(loc.t("focus.strong")).font(.title3.bold())
                    ForEach(strong.prefix(8), id: \.key) { topicRow($0.key, $0.value, color: .green) }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $drilling) {
            FocusDrillView(onClose: { drilling = false }).environmentObject(loc).environmentObject(course)
        }
    }

    private func topicRow(_ key: String, _ stat: TopicStat, color: Color) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(loc.topicName(key)).font(.headline)
                    Spacer()
                    Text("\(Int((stat.recentAccuracy * 100).rounded()))%").font(.headline.monospacedDigit()).foregroundStyle(color)
                }
                ProgressView(value: stat.recentAccuracy).tint(color)
                HStack {
                    Text("\(stat.correct)/\(stat.attempts) \(loc.t("focus.correct")) · \(loc.t("focus.recent")) \(stat.recent.filter { $0 }.count)/\(stat.recent.count)")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(loc.t("focus.study")) { route.openTopic(key) }.buttonStyle(.link)
                }
            }
            .padding(4)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A short drill built from the learner's weakest pillars (or the whole course when nothing is weak yet).
struct FocusDrillView: View {
    let onClose: () -> Void
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var course: CourseProgress
    @State private var items: [(pillar: Int, question: CourseQuestion)] = []
    @State private var picks: [Int: Int] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(loc.t("focus.drill")).font(.title2.bold())
                Spacer()
                Button(loc.t("focus.done"), action: onClose)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items.indices, id: \.self) { i in
                        QuestionView(question: items[i].question, picked: Binding(
                            get: { picks[i] },
                            set: { value in
                                guard picks[i] == nil, let value else { return }
                                picks[i] = value
                                course.recordAttempt(topic: "p:\(items[i].pillar)", correct: value == items[i].question.correctIndex)
                                HabitStore.shared.recordActivity()
                            }))
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 520)
        .onAppear { build() }
    }

    private func build() {
        guard items.isEmpty else { return }
        let weakIDs = course.weakTopics().compactMap { $0.topic.hasPrefix("p:") ? Int($0.topic.dropFirst(2)) : nil }.prefix(4)
        let pool = loc.pillars.filter { weakIDs.isEmpty || weakIDs.contains($0.id) }
        let all = pool.flatMap { p in (p.quiz + (p.extraQuiz ?? [])).map { (p.id, $0) } }
        items = Array(all.shuffled().prefix(10)).map { (pillar: $0.0, question: $0.1) }
    }
}
