import SwiftUI

// MARK: - Guided path

struct PathStep: Identifiable {
    enum Kind { case lesson(String), pillar(Int) }
    let id: String
    let kind: Kind
    let title: String
    let detail: String
}

@MainActor
enum PathBuilder {
    static func steps(_ loc: Localizer) -> [PathStep] {
        let lessons = loc.lessons.map { PathStep(id: "l-\($0.id)", kind: .lesson($0.id), title: $0.title, detail: $0.summary) }
        let pillars = loc.pillars.sorted { (CourseData.categoryRank($0.categoryName), $0.id) < (CourseData.categoryRank($1.categoryName), $1.id) }.map {
            PathStep(id: "p-\($0.id)", kind: .pillar($0.id), title: "\($0.id). \($0.title)", detail: loc.category($0.categoryName))
        }
        return lessons + pillars
    }

    static func isCompleted(_ step: PathStep, loc: Localizer, course: CourseProgress, lessons: ProgressStore) -> Bool {
        switch step.kind {
        case .lesson(let id): return lessons.completed.contains(id)
        case .pillar(let id):
            guard let p = loc.pillars.first(where: { $0.id == id }) else { return false }
            return course.progress(for: p).percentage >= 60
        }
    }
}

struct PathView: View {
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var course: CourseProgress
    @EnvironmentObject var lessons: ProgressStore
    @EnvironmentObject var route: SwiftQuestRoute
    @AppStorage("pathUnlockAll") private var unlockAll = false

    private func state() -> (steps: [PathStep], done: [Bool], open: [Bool]) {
        let steps = PathBuilder.steps(loc)
        let done = steps.map { PathBuilder.isCompleted($0, loc: loc, course: course, lessons: lessons) }
        let open = steps.indices.map { i in
            i == 0 || unlockAll || i < course.snapshot.unlockedUpTo || done[i - 1] || done[i]
        }
        return (steps, done, open)
    }

    var body: some View {
        let (steps, done, open) = state()
        let next = steps.indices.first { open[$0] && !done[$0] }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("nav.path")).font(.largeTitle.bold())
                TodayCard()
                if let weak = course.weakTopics().first {
                    Button { route.selection = .focus } label: {
                        Label("\(loc.t("focus.next")): \(loc.topicName(weak.topic))", systemImage: "target")
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.link)
                }
                HStack {
                    if let next {
                        Button { route.go(steps[next]) } label: {
                            Label("\(loc.t("path.continue")): \(steps[next].title)", systemImage: "play.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Label(loc.t("path.alldone"), systemImage: "party.popper.fill").foregroundStyle(.green)
                    }
                    Button { route.selection = .review } label: {
                        Label("\(loc.t("nav.review")) (\(course.reviewQueue.count))", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button { route.selection = .placement } label: {
                        Label(loc.t("path.placement"), systemImage: "checklist")
                    }
                }
                Toggle(loc.t("path.unlockall"), isOn: $unlockAll).toggleStyle(.switch)
                Text("\(done.filter { $0 }.count) / \(steps.count) \(loc.t("path.steps.done"))")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach(steps.indices, id: \.self) { i in
                    let step = steps[i]
                    Button { if open[i] { route.go(step) } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: done[i] ? "checkmark.circle.fill" : (open[i] ? "circle" : "lock.fill"))
                                .foregroundStyle(done[i] ? Color.green : (open[i] ? Color.accentColor : Color.secondary))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title).font(.headline)
                                Text(step.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if i == next { Text(loc.t("path.next")).font(.caption.bold()).foregroundStyle(Color.accentColor) }
                        }
                        .padding(10)
                        .background(.quaternary.opacity(i == next ? 0.6 : 0.25), in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!open[i])
                    .accessibilityLabel("\(step.title). \(done[i] ? loc.t("a11y.completed") : (open[i] ? loc.t("a11y.available") : loc.t("a11y.locked")))")
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Review queue (questions you got wrong)

struct ReviewView: View {
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var course: CourseProgress
    @State private var offset = 0
    @State private var picked: Int?

    var body: some View {
        let queue = course.reviewQueue.compactMap { key in loc.question(forKey: key).map { (key, $0) } }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("nav.review")).font(.largeTitle.bold())
                Text(loc.t("review.sub")).foregroundStyle(.secondary)
                if queue.isEmpty {
                    Label(loc.t("review.empty"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    let item = queue[offset % queue.count]
                    Text("\(queue.count) \(loc.t("review.pending")) · \(item.1.title)").font(.callout).foregroundStyle(.secondary)
                    QuestionView(question: item.1.question, picked: Binding(
                        get: { picked },
                        set: { value in
                            picked = value
                            if let value {
                                course.markQuestion(item.0, correct: value == item.1.question.correctIndex)
                                if let topic = reviewTopic(item.0) {
                                    course.recordAttempt(topic: topic, correct: value == item.1.question.correctIndex)
                                }
                            }
                        }))
                    .id(item.0)
                    Button(loc.t("next.question")) { picked = nil; offset += 1 }.buttonStyle(.borderedProminent)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Statistics topic behind a review-queue key ("p:3:2" -> "p:3", "e:exam-1:4" -> its category).
@MainActor
private func reviewTopic(_ key: String) -> String? {
    let parts = key.split(separator: ":").map(String.init)
    switch parts.first {
    case "p" where parts.count >= 2: return "p:\(parts[1])"
    default: return nil
    }
}

// MARK: - Placement quiz

struct PlacementView: View {
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var course: CourseProgress
    @EnvironmentObject var route: SwiftQuestRoute
    @State private var questions: [CourseQuestion] = []
    @State private var picks: [Int: Int] = [:]
    @State private var finished = false

    private var score: Int { questions.indices.filter { picks[$0] == questions[$0].correctIndex }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("nav.placement")).font(.largeTitle.bold())
                Text(loc.t("placement.sub")).foregroundStyle(.secondary)
                ForEach(questions.indices, id: \.self) { i in
                    QuestionView(question: questions[i],
                                 picked: Binding(get: { picks[i] }, set: { if !finished { picks[i] = $0 } }),
                                 showFeedback: finished)
                }
                if finished {
                    let total = PathBuilder.steps(loc).count
                    Label("\(score) / \(questions.count) — \(loc.t("placement.result")) \(unlockCount(total))",
                          systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(.green)
                    Button(loc.t("nav.path")) { route.selection = .path }.buttonStyle(.borderedProminent)
                } else {
                    Button(loc.t("finish")) { finish() }
                        .buttonStyle(.borderedProminent)
                        .disabled(picks.count < questions.count)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { if questions.isEmpty { questions = Array(loc.exams.flatMap(\.questions).shuffled().prefix(10)) } }
    }

    /// 0–3 right answers keep the path at the beginning; 10/10 opens about 80% of it.
    private func unlockCount(_ total: Int) -> Int {
        score <= 3 ? 0 : Int(Double(score - 3) / 7.0 * Double(total) * 0.8)
    }

    private func finish() {
        finished = true
        course.setUnlockedUpTo(unlockCount(PathBuilder.steps(loc).count))
        HabitStore.shared.recordActivity()
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var route: SwiftQuestRoute
    @ObservedObject var habits = HabitStore.shared
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc.t("onb.welcome")).font(.largeTitle.bold())
            Text(loc.t("onb.sub")).foregroundStyle(.secondary)
            Picker(loc.t("language"), selection: $loc.language) {
                ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
            }
            Stepper("\(loc.t("onb.goal")): \(habits.dailyGoal)", value: $habits.dailyGoal, in: 1...10)
            Text(loc.t("onb.how")).font(.callout).foregroundStyle(.secondary)
            HStack {
                Button(loc.t("onb.placement")) { route.selection = .placement; onDone() }
                Button(loc.t("onb.start")) { route.selection = .path; onDone() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 480)
    }
}
