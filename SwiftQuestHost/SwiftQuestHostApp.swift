import SwiftUI
import AppKit

@main
struct SwiftQuestHostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var route = SwiftQuestRoute()
    @StateObject private var progress = ProgressStore()
    @StateObject private var coach = AICoachSettings()
    @StateObject private var course = CourseProgress()
    @StateObject private var loc = Localizer()

    init() {
        if SelfTest.requested { SelfTest.run() }
    }

    var body: some Scene {
        // A single window: URLs sent from Xcode must reuse it instead of opening new ones.
        Window("SwiftQuest", id: "main") {
            RootView()
                .frame(minWidth: 900, minHeight: 580)
                .environmentObject(route)
                .environmentObject(progress)
                .environmentObject(coach)
                .environmentObject(course)
                .environmentObject(loc)
                .environmentObject(HabitStore.shared)
                .onAppear { appDelegate.route = route }
        }
        Settings {
            AICoachSettingsView()
                .environmentObject(coach)
                .environmentObject(loc)
                .environmentObject(HabitStore.shared)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(loc.t("menu.about")) { showAboutPanel(tagline: loc.t("about.tagline")) }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var route: SwiftQuestRoute?

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { url in
            Task { @MainActor in route?.handle(url: url) }
        }
    }
}

enum SidebarItem: String, Hashable {
    case path, focus, certification, learn, practice, explain, course, exams, dashboard, glossary, badges
    case review, flashcards, playground, mindmap, placement
}

/// Completion state of the built-in introductory lessons.
@MainActor
final class ProgressStore: ObservableObject {
    private var key: String { Storage.key("completedLessons") }
    @Published private(set) var completed: Set<String> = []
    private var observer: NSObjectProtocol?

    init() {
        reload()
        observer = NotificationCenter.default.addObserver(forName: .profileDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    func reload() {
        completed = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func toggle(_ id: String) {
        if completed.contains(id) { completed.remove(id) } else { completed.insert(id); HabitStore.shared.recordActivity() }
        UserDefaults.standard.set(Array(completed), forKey: key)
    }
}

@MainActor
final class SwiftQuestRoute: ObservableObject {
    @Published var selection: SidebarItem? = UserDefaults.standard.string(forKey: "startItem").flatMap(SidebarItem.init(rawValue:)) ?? .path
    @Published var source = ""
    @Published var fromXcode = false
    @Published var mode: ExplainMode = .explain
    @Published var banner: String?
    @Published var lessonTarget: String?
    @Published var pillarTarget: Int?

    enum ExplainMode { case explain, exercise }

    /// Opens the lesson or pillar behind a guided-path step.
    func go(_ step: PathStep) {
        switch step.kind {
        case .lesson(let id): lessonTarget = id; selection = .learn
        case .pillar(let id): pillarTarget = id; selection = .course
        }
    }

    func handle(url: URL) {
        guard url.scheme == "swiftquest" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let payload = components?.queryItems?.first(where: { $0.name == "payload" })?.value
        guard let payload,
              let data = payload.data(using: .utf8),
              let message = try? JSONDecoder().decode(SwiftQuestMessage.self, from: data) else { return }
        source = message.source
        fromXcode = true
        mode = .explain
        banner = nil
        switch message.command {
        case .flashcard:
            banner = FlashcardStore.shared.add(code: message.source) ? "flash.saved" : "flash.exists"
        case .exercise:
            mode = .exercise
        default: break
        }
        selection = .explain
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Shows the sign-in screen until a profile is chosen.
struct RootView: View {
    @ObservedObject var profiles = ProfileStore.shared

    var body: some View {
        if let profile = profiles.current {
            SwiftQuestHome().id(profile.id)
        } else {
            SignInView()
        }
    }
}

struct SwiftQuestHome: View {
    @EnvironmentObject var route: SwiftQuestRoute
    @EnvironmentObject var course: CourseProgress
    @EnvironmentObject var loc: Localizer
    @ObservedObject var profiles = ProfileStore.shared
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: Storage.key("onboardingDone"))

    var body: some View {
        NavigationSplitView {
            List(selection: $route.selection) {
                Section(loc.t("sidebar.today")) {
                    Label(loc.t("nav.path"), systemImage: "map.fill").tag(SidebarItem.path)
                    Label(loc.t("nav.focus"), systemImage: "target").tag(SidebarItem.focus)
                    Label("\(loc.t("nav.review")) (\(course.reviewQueue.count))", systemImage: "arrow.triangle.2.circlepath").tag(SidebarItem.review)
                    Label(loc.t("nav.flashcards"), systemImage: "rectangle.on.rectangle.angled").tag(SidebarItem.flashcards)
                }
                Section(loc.t("sidebar.intro")) {
                    Label(loc.t("nav.learn"), systemImage: "book.fill").tag(SidebarItem.learn)
                    Label(loc.t("nav.practice"), systemImage: "gamecontroller.fill").tag(SidebarItem.practice)
                    Label(loc.t("nav.playground"), systemImage: "terminal.fill").tag(SidebarItem.playground)
                    Label(loc.t("nav.explain"), systemImage: "text.magnifyingglass").tag(SidebarItem.explain)
                }
                Section(loc.t("sidebar.course")) {
                    Label(loc.t("nav.cert"), systemImage: "checkmark.seal.fill").tag(SidebarItem.certification)
                    Label(loc.t("nav.course"), systemImage: "graduationcap.fill").tag(SidebarItem.course)
                    Label(loc.t("nav.mindmap"), systemImage: "point.3.connected.trianglepath.dotted").tag(SidebarItem.mindmap)
                    Label(loc.t("nav.exams"), systemImage: "timer").tag(SidebarItem.exams)
                    Label(loc.t("nav.dashboard"), systemImage: "chart.pie.fill").tag(SidebarItem.dashboard)
                    Label(loc.t("nav.glossary"), systemImage: "character.book.closed.fill").tag(SidebarItem.glossary)
                    Label(loc.t("nav.badges"), systemImage: "trophy.fill").tag(SidebarItem.badges)
                }
            }
            .navigationTitle("SwiftQuest")
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    if let me = profiles.current {
                        Menu {
                            Button(loc.t("login.switch")) { profiles.signOut() }
                            Button(loc.t("login.signout")) { profiles.signOut() }
                        } label: {
                            HStack(spacing: 6) { Text(me.emoji); Text(me.name).font(.headline); Spacer() }
                        }
                        .menuStyle(.borderlessButton)
                        .accessibilityLabel("\(me.name). \(loc.t("login.signout"))")
                    }
                    let stats = course.stats
                    Text("\(loc.t("level")) \(stats.level.level) · \(stats.points) XP · 🔥 \(HabitStore.shared.streak)").font(.caption.bold())
                    ProgressView(value: stats.level.progressPercent)
                    Picker(loc.t("language"), selection: $loc.language) {
                        ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                .padding(10)
                .background(.bar)
            }
        } detail: {
            switch route.selection ?? .path {
            case .path: PathView()
            case .focus: FocusView()
            case .certification: CertificationView()
            case .review: ReviewView()
            case .flashcards: FlashcardsView()
            case .playground: PlaygroundView()
            case .mindmap: MindMapView()
            case .placement: PlacementView()
            case .learn: LearnView()
            case .practice: PracticeView()
            case .explain: ExplainView()
            case .course: CourseView()
            case .exams: ExamsView()
            case .dashboard: DashboardView()
            case .glossary: GlossaryView()
            case .badges: BadgesView()
            }
        }
        .sheet(item: $course.newlyUnlocked) { badge in
            BadgeUnlockedView(badge: badge) { course.dismissBadge() }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: Storage.key("onboardingDone"))
                showOnboarding = false
            }
            .environmentObject(route).environmentObject(loc)
        }
    }
}

// MARK: - Intro lessons

struct LearnView: View {
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var loc: Localizer
    @EnvironmentObject var route: SwiftQuestRoute
    @State private var selectedID: String? = "values"

    var body: some View {
        HStack(spacing: 0) {
            List(loc.lessons, selection: $selectedID) { lesson in
                HStack {
                    Image(systemName: lesson.icon)
                    VStack(alignment: .leading) {
                        Text(lesson.title).font(.headline)
                        Text(lesson.summary).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if progress.completed.contains(lesson.id) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .tag(lesson.id)
            }
            .frame(width: 300)
            .onAppear { if let t = route.lessonTarget { selectedID = t; route.lessonTarget = nil } }
            .onChange(of: route.lessonTarget) { _, t in if let t { selectedID = t; route.lessonTarget = nil } }
            Divider()
            if let id = selectedID, let lesson = loc.lessons.first(where: { $0.id == id }) {
                LessonDetail(lesson: lesson).id(lesson.id)
            } else {
                Text(loc.t("pick.lesson")).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

func markdown(_ text: String) -> AttributedString {
    (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
        ?? AttributedString(text)
}

struct CodeBlock: View {
    let code: String
    var body: some View {
        Text(code)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct LessonDetail: View {
    let lesson: Lesson
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var loc: Localizer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(lesson.title).font(.largeTitle.bold())
                ForEach(lesson.sections.indices, id: \.self) { i in
                    let s = lesson.sections[i]
                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.heading).font(.title3.bold())
                        Text(markdown(s.body))
                        if let code = s.code { CodeBlock(code: code) }
                    }
                }
                GroupBox(loc.t("try.xcode")) {
                    Text(lesson.exercise).frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
                Text(loc.t("check.yourself")).font(.title3.bold())
                DocLinksSection(links: DocsData.links(lesson: lesson.id))
                ForEach(lesson.quiz) { q in
                    IntroQuizCard(question: q, lessonID: lesson.id)
                }
                Button {
                    progress.toggle(lesson.id)
                } label: {
                    Label(progress.completed.contains(lesson.id) ? loc.t("lesson.completed") : loc.t("lesson.mark"),
                          systemImage: progress.completed.contains(lesson.id) ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct IntroQuizCard: View {
    let question: QuizQuestion
    let lessonID: String
    @EnvironmentObject var course: CourseProgress
    @State private var picked: Int?

    var body: some View {
        QuestionView(question: CourseQuestion(id: 0, question: question.prompt, options: question.choices,
                                              correctIndex: question.answer, explanation: question.explanation),
                     picked: Binding(get: { picked }, set: { value in
                         picked = value
                         if let value {
                             course.markQuestion("i:\(question.id)", correct: value == question.answer)
                             course.recordAttempt(topic: "l:\(lessonID)", correct: value == question.answer)
                         }
                     }))
    }
}

// MARK: - Practice (study bank: mock-exam questions + lesson quizzes)

struct PracticeView: View {
    @EnvironmentObject var loc: Localizer
    @State private var index = Int.random(in: 0..<1000)
    @State private var picked: Int?

    var body: some View {
        let bank = loc.studyBank
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("nav.practice")).font(.largeTitle.bold())
                Text(loc.t("practice.sub")).foregroundStyle(.secondary)
                if bank.isEmpty {
                    Text(loc.t("nothing.yet")).foregroundStyle(.secondary)
                } else {
                    let q = bank[index % bank.count]
                    QuestionView(question: q, picked: $picked).id("\(index)-\(loc.language.rawValue)")
                    Button(loc.t("next.question")) {
                        index = Int.random(in: 0..<1000)
                        picked = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Explain (offline rules; optional AI coach below)

struct ExplainView: View {
    @EnvironmentObject var route: SwiftQuestRoute
    @EnvironmentObject var loc: Localizer

    var body: some View {
        let entries = Curriculum.explain(route.source, glossary: loc.introGlossary)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(route.fromXcode ? loc.t("explain.title.xcode") : loc.t("nav.explain")).font(.largeTitle.bold())
                if let banner = route.banner {
                    Label(loc.t(banner), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                if route.mode == .exercise {
                    CodeExerciseView(source: route.source).id(route.source)
                }
                if route.source.isEmpty {
                    Text(loc.t("explain.empty")).foregroundStyle(.secondary)
                }
                TextEditor(text: $route.source)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                Text(loc.t("explain.inside")).font(.title3.bold())
                if entries.isEmpty {
                    Text(route.source.isEmpty ? loc.t("nothing.yet") : loc.t("explain.none")).foregroundStyle(.secondary)
                }
                ForEach(entries, id: \.term) { entry in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.term).font(.headline.monospaced())
                            Text(markdown(entry.meaning))
                            if let lesson = loc.lessons.first(where: { $0.id == entry.lessonID }) {
                                Button("\(loc.t("learn.more")): \(lesson.title)") {
                                    route.lessonTarget = lesson.id
                                    route.selection = .learn
                                }
                                .buttonStyle(.link).font(.caption)
                            }
                        }
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text(loc.t("explain.offline")).font(.footnote).foregroundStyle(.tertiary)
                Divider()
                AICoachPanel(code: route.source)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@MainActor
private func showAboutPanel(tagline: String) {
    let credits = NSMutableAttributedString(
        string: tagline + "\n",
        attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
    credits.append(NSAttributedString(
        string: "gabrielnetto.com",
        attributes: [.font: NSFont.systemFont(ofSize: 11), .link: URL(string: "https://gabrielnetto.com")!]))
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))
    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    NSApp.activate(ignoringOtherApps: true)
}
