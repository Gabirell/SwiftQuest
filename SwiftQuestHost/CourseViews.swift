import SwiftUI

// MARK: - Shared question UI

struct QuestionView: View {
    let question: CourseQuestion
    @Binding var picked: Int?
    var showFeedback = true
    @EnvironmentObject var loc: Localizer

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(question.question).font(.headline)
                ForEach(question.options.indices, id: \.self) { i in
                    Button {
                        if picked == nil || !showFeedback { picked = i }
                    } label: {
                        HStack(alignment: .top) {
                            Image(systemName: picked == i ? "largecircle.fill.circle" : "circle")
                            Text(question.options[i]).multilineTextAlignment(.leading)
                            Spacer()
                            if showFeedback, let picked {
                                if i == question.correctIndex { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                else if i == picked { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if showFeedback, let picked {
                    Text((picked == question.correctIndex ? loc.t("correct") : loc.t("incorrect")) + " " + question.explanation)
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct QuizSet: View {
    let questions: [CourseQuestion]
    var keyPrefix: String?          // when set, wrong answers go to the review queue as "<prefix>:<question id>"
    var onScore: ((Int) -> Void)?
    @EnvironmentObject var course: CourseProgress
    @EnvironmentObject var loc: Localizer
    @State private var picks: [Int: Int] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(questions) { q in
                QuestionView(question: q, picked: Binding(
                    get: { picks[q.id] },
                    set: { value in
                        picks[q.id] = value
                        if let prefix = keyPrefix, let value {
                            course.markQuestion("\(prefix):\(q.id)", correct: value == q.correctIndex)
                        }
                        report()
                    }))
            }
            let correct = questions.filter { picks[$0.id] == $0.correctIndex }.count
            Text("\(loc.t("score")): \(correct) / \(questions.count)").font(.callout.bold())
        }
    }

    private func report() {
        guard picks.count == questions.count else { return }
        onScore?(questions.filter { picks[$0.id] == $0.correctIndex }.count)
    }
}

// MARK: - Course

struct CourseView: View {
    @EnvironmentObject var progress: CourseProgress
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var route: SwiftQuestRoute
    @State private var selected: Int? = 1

    private var groups: [(String, [Pillar])] {
        CourseData.categoryOrder.compactMap { cat in
            let items = loc.pillars.filter { $0.categoryName == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selected) {
                ForEach(groups, id: \.0) { cat, items in
                    Section(loc.category(cat)) {
                        ForEach(items) { p in
                            HStack {
                                Text("\(p.id). \(p.title)")
                                Spacer()
                                if progress.progress(for: p).status == .mastered {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                                }
                            }
                            .tag(p.id)
                        }
                    }
                }
            }
            .frame(width: 300)
            .onAppear { if let t = route.pillarTarget { selected = t; route.pillarTarget = nil } }
            .onChange(of: route.pillarTarget) { _, t in if let t { selected = t; route.pillarTarget = nil } }
            Divider()
            if let id = selected, let p = loc.pillars.first(where: { $0.id == id }) {
                PillarDetail(pillar: p).id("\(p.id)-\(loc.language.rawValue)")
            } else {
                Text(loc.t("pick.pillar")).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct PillarDetail: View {
    let pillar: Pillar
    @EnvironmentObject var progress: CourseProgress
    @EnvironmentObject var loc: Localizer
    @State private var showExtra = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(pillar.title).font(.largeTitle.bold())
                Text(loc.category(pillar.categoryName)).font(.subheadline).foregroundStyle(.secondary)
                Text(markdown(pillar.theory))
                if let s = pillar.appleDocUrl, let url = URL(string: s) {
                    Link(loc.t("official.docs"), destination: url)
                }
                GroupBox(loc.t("case.corporate")) {
                    Text(markdown(pillar.corporateCase)).frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
                GroupBox(loc.t("case.game")) {
                    Text(markdown(pillar.gameCase)).frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
                Text(loc.t("exercises")).font(.title3.bold())
                ForEach(pillar.exercises) { ExerciseRow(pillarID: pillar.id, exercise: $0) }
                Text(loc.t("quiz")).font(.title3.bold())
                QuizSet(questions: pillar.quiz, keyPrefix: "p:\(pillar.id)") { progress.recordQuiz(pillar: pillar.id, correct: $0) }
                if let extra = pillar.extraQuiz, !extra.isEmpty {
                    if showExtra {
                        Text(loc.t("quiz.extra")).font(.title3.bold())
                        QuizSet(questions: extra)
                    } else {
                        Button(loc.t("quiz.extra.show")) { showExtra = true }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ExerciseRow: View {
    let pillarID: Int
    let exercise: CourseExercise
    @EnvironmentObject var progress: CourseProgress
    @EnvironmentObject var loc: Localizer
    @State private var answer = ""
    @State private var result: Bool?
    @State private var showHint = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.question).font(.headline)
                CodeBlock(code: exercise.codeSnippet)
                HStack {
                    TextField(loc.t("fill.blank"), text: $answer)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(check)
                    Button(loc.t("check"), action: check)
                    Button(showHint ? loc.t("hint.hide") : loc.t("hint")) { showHint.toggle() }.buttonStyle(.link)
                }
                if showHint { Text(exercise.hint).font(.callout).foregroundStyle(.secondary) }
                if progress.isExerciseDone(pillar: pillarID, exercise: exercise.id) || result == true {
                    Label(loc.t("correct.short"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else if result == false {
                    Label(loc.t("try.again"), systemImage: "xmark.circle.fill").foregroundStyle(.red)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func check() {
        result = progress.check(exercise: exercise, pillar: pillarID, answer: answer)
    }
}

// MARK: - Mock exams

struct ExamsView: View {
    @EnvironmentObject var progress: CourseProgress
    @EnvironmentObject var loc: Localizer
    @State private var running: String?

    var body: some View {
        if let id = running, let exam = loc.exams.first(where: { $0.id == id }) {
            ExamRunner(exam: exam) { running = nil }.id(exam.id)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc.t("nav.exams")).font(.largeTitle.bold())
                    Text(loc.t("exams.pass")).foregroundStyle(.secondary)
                    ForEach(loc.exams) { exam in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(exam.title).font(.headline)
                                    if progress.snapshot.passedExams.contains(exam.id) {
                                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                                    }
                                }
                                Text(exam.description).foregroundStyle(.secondary)
                                Text("\(loc.category(exam.category)) · \(exam.timeLimitMinutes) min · \(exam.questions.count) \(loc.t("questions"))")
                                    .font(.caption)
                                Button(loc.t("start")) { running = exam.id }.buttonStyle(.borderedProminent)
                            }
                            .padding(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ExamRunner: View {
    let exam: MockExam
    let onExit: () -> Void
    @EnvironmentObject var progress: CourseProgress
    @EnvironmentObject var loc: Localizer
    @State private var picks: [Int: Int] = [:]
    @State private var finished = false
    @State private var remaining: Int
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(exam: MockExam, onExit: @escaping () -> Void) {
        self.exam = exam
        self.onExit = onExit
        _remaining = State(initialValue: exam.timeLimitMinutes * 60)
    }

    private var score: Int { exam.questions.filter { picks[$0.id] == $0.correctIndex }.count }
    private var passed: Bool { Double(score) / Double(exam.questions.count) >= CourseData.passingGrade }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(exam.title).font(.largeTitle.bold())
                    Spacer()
                    if !finished {
                        Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                            .font(.title2.monospacedDigit())
                    }
                }
                if finished {
                    Label("\(score) / \(exam.questions.count) — \(passed ? loc.t("exam.passed") : loc.t("exam.failed"))",
                          systemImage: passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.title3.bold())
                        .foregroundStyle(passed ? .green : .red)
                }
                ForEach(exam.questions) { q in
                    QuestionView(question: q,
                                 picked: Binding(get: { picks[q.id] },
                                                 set: { if !finished { picks[q.id] = $0 } }),
                                 showFeedback: finished)
                }
                HStack {
                    if !finished {
                        Button(loc.t("finish")) { finish() }.buttonStyle(.borderedProminent)
                    }
                    Button(finished ? loc.t("back.exams") : loc.t("cancel"), action: onExit)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onReceive(timer) { _ in
            guard !finished else { return }
            if remaining > 0 { remaining -= 1 } else { finish() }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        for q in exam.questions {
            progress.markQuestion("e:\(exam.id):\(q.id)", correct: picks[q.id] == q.correctIndex)
        }
        progress.recordExam(id: exam.id, passed: passed)
    }
}

// MARK: - Glossary

struct GlossaryView: View {
    @EnvironmentObject var progress: CourseProgress
    @EnvironmentObject var loc: Localizer
    @State private var query = ""

    private var terms: [GlossaryTerm] {
        let all = loc.glossary.sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        return query.isEmpty ? all : all.filter {
            $0.term.localizedCaseInsensitiveContains(query) || $0.definition.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(loc.t("nav.glossary")).font(.largeTitle.bold())
            TextField(loc.t("search"), text: $query).textFieldStyle(.roundedBorder)
            List(terms) { t in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.term).font(.headline.monospaced())
                        Text(t.definition).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        progress.toggleTerm(t.term)
                    } label: {
                        Image(systemName: progress.isSaved(t.term) ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(.plain)
                    .help(loc.t("save.term"))
                    .accessibilityLabel(loc.t("save.term"))
                }
            }
        }
        .padding(28)
    }
}

// MARK: - Achievements

struct BadgesView: View {
    @EnvironmentObject var progress: CourseProgress
    @EnvironmentObject var loc: Localizer

    var body: some View {
        let stats = progress.stats
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("nav.badges")).font(.largeTitle.bold())
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(loc.t("level")) \(stats.level.level) · \(loc.levelTitle(stats.level.level))").font(.headline)
                        ProgressView(value: stats.level.progressPercent)
                        Text("\(stats.points) XP — \(loc.t("next.level")) \(stats.level.nextLevelXP) XP").font(.caption)
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                    ForEach(loc.badges) { b in
                        let on = stats.unlockedBadges.contains(b.id)
                        GroupBox {
                            HStack(alignment: .top) {
                                Image(systemName: on ? b.symbol : "lock.fill")
                                    .font(.title2)
                                    .foregroundStyle(on ? Color.yellow : Color.secondary)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.title).font(.headline)
                                    Text(b.description).font(.caption).foregroundStyle(.secondary)
                                    Text("\(b.criteria) · +\(b.xpReward) XP").font(.caption2).foregroundStyle(.tertiary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(4)
                        }
                        .opacity(on ? 1 : 0.55)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BadgeUnlockedView: View {
    let badge: Badge
    let onClose: () -> Void
    @EnvironmentObject var loc: Localizer

    var body: some View {
        // Show the translated copy of the badge when available.
        let shown = loc.badges.first(where: { $0.id == badge.id }) ?? badge
        VStack(spacing: 14) {
            Image(systemName: shown.symbol).font(.system(size: 54)).foregroundStyle(.yellow)
            Text(loc.t("badge.unlocked")).font(.caption.bold()).textCase(.uppercase).foregroundStyle(.secondary)
            Text(shown.title).font(.title.bold()).multilineTextAlignment(.center)
            Text(shown.description).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("+\(shown.xpReward) XP").font(.title2.bold()).foregroundStyle(.orange)
            Button(loc.t("keep.going"), action: onClose).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
        }
        .padding(30)
        .frame(width: 360)
    }
}

// MARK: - Progress dashboard (ported from the original pillar progress chart)

struct DashboardView: View {
    @EnvironmentObject var lessons: ProgressStore
    @EnvironmentObject var progress: CourseProgress
    @EnvironmentObject var loc: Localizer

    var body: some View {
        let rows = loc.pillars.map { progress.progress(for: $0) }
        let average = rows.isEmpty ? 0 : rows.reduce(0) { $0 + $1.percentage } / rows.count
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(loc.t("nav.dashboard")).font(.largeTitle.bold())
                    Spacer()
                    Menu {
                        Button("Markdown") {
                            ProgressExporter.save(ProgressExporter.markdown(loc: loc, course: progress, lessons: lessons), suggestedName: "SwiftQuest-progress.md")
                        }
                        Button("JSON") {
                            ProgressExporter.save(ProgressExporter.json(loc: loc, course: progress, lessons: lessons), suggestedName: "SwiftQuest-progress.json")
                        }
                    } label: { Label(loc.t("export"), systemImage: "square.and.arrow.up") }
                }
                HStack(spacing: 24) {
                    ZStack {
                        Circle().stroke(.quaternary, lineWidth: 14)
                        Circle().trim(from: 0, to: Double(average) / 100)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(average)%").font(.title.bold())
                    }
                    .frame(width: 120, height: 120)
                    VStack(alignment: .leading, spacing: 6) {
                        summary(.mastered, rows, "status.mastered", "checkmark.seal.fill", .green)
                        summary(.inProgress, rows, "status.inprogress", "clock.fill", .blue)
                        summary(.needsReview, rows, "status.review", "exclamationmark.triangle.fill", .orange)
                        summary(.notStarted, rows, "status.notstarted", "circle", .secondary)
                    }
                }
                ForEach(rows, id: \.pillar.id) { r in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(r.pillar.id). \(r.pillar.title)").font(.headline)
                                Spacer()
                                Text(statusLabel(r.status)).font(.caption.bold()).foregroundStyle(statusColor(r.status))
                            }
                            ProgressView(value: Double(r.percentage) / 100).tint(statusColor(r.status))
                            Text("\(loc.t("quiz")) \(r.quizScore)/\(r.pillar.quiz.count) · \(loc.t("exercises")) \(r.exercisesDone)/\(r.pillar.exercises.count)")
                                .font(.caption).foregroundStyle(.secondary)
                            if r.status == .needsReview {
                                Text(loc.t("status.review.hint")).font(.caption).foregroundStyle(.orange)
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summary(_ status: PillarStatus, _ rows: [PillarProgress], _ key: String, _ icon: String, _ color: Color) -> some View {
        Label("\(rows.filter { $0.status == status }.count) · \(loc.t(key))", systemImage: icon).foregroundStyle(color)
    }

    private func statusLabel(_ s: PillarStatus) -> String {
        switch s {
        case .mastered: loc.t("status.mastered")
        case .inProgress: loc.t("status.inprogress")
        case .needsReview: loc.t("status.review")
        case .notStarted: loc.t("status.notstarted")
        }
    }

    private func statusColor(_ s: PillarStatus) -> Color {
        switch s {
        case .mastered: .green
        case .inProgress: .blue
        case .needsReview: .orange
        case .notStarted: .secondary
        }
    }
}
