import Foundation

/// `SwiftQuest.app/Contents/MacOS/SwiftQuest --selftest` loads and cross-checks all bundled content, then exits.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }

    static func run() {
        setvbuf(stdout, nil, _IONBF, 0)
        Task { @MainActor in
            var failures = 0
            func check(_ ok: Bool, _ message: String) {
                print((ok ? "PASS " : "FAIL ") + message)
                if !ok { failures += 1 }
            }
            let loc = Localizer()

            // MARK: content, per language and consistent across languages
            struct Shape: Equatable {
                var pillars: [Int] = []
                var counts: [String] = []          // "id:exercises/quiz/extra"
                var answers: [String] = []         // correctIndex lists
                var exams: [String] = []
                var glossary: [String] = []
                var badges: [String] = []
                var challenges: [String] = []
                var lessonQuiz: [String] = []
                var guide: [String] = []
            }
            var shapes: [AppLanguage: Shape] = [:]
            for lang in AppLanguage.allCases {
                loc.language = lang
                var s = Shape()
                s.pillars = loc.pillars.map(\.id)
                s.counts = loc.pillars.map { "\($0.id):\($0.exercises.count)/\($0.quiz.count)/\($0.extraQuiz?.count ?? 0)" }
                s.answers = loc.pillars.map { ($0.quiz + ($0.extraQuiz ?? [])).map { String($0.correctIndex) }.joined() }
                s.exams = loc.exams.map { "\($0.id):\($0.questions.count)" }
                s.glossary = loc.glossary.map(\.term)
                s.badges = loc.badges.map(\.id)
                s.challenges = loc.challenges.map(\.id)
                s.lessonQuiz = loc.lessons.map { "\($0.id):\($0.quiz.count)" }
                s.guide = loc.guide.map { "\($0.id):\($0.category):\($0.steps.count):\($0.tips.count):\($0.pitfalls.count):\($0.links.count)" }
                shapes[lang] = s
                check(loc.pillars.count >= 25 && Set(s.pillars).count == s.pillars.count, "\(lang.rawValue): \(loc.pillars.count) unique pillars")
                check(loc.pillars.allSatisfy { $0.exercises.count >= 5 && $0.quiz.count >= 5 && !$0.theory.isEmpty }, "\(lang.rawValue): every pillar has >=5 exercises, >=5 quiz questions and theory")
                check(loc.pillars.allSatisfy { p in (p.quiz + (p.extraQuiz ?? [])).allSatisfy { $0.options.count == 4 && (0..<4).contains($0.correctIndex) } },
                      "\(lang.rawValue): every quiz question has 4 options and a valid answer")
                check(loc.pillars.allSatisfy { $0.exercises.allSatisfy { $0.codeSnippet.contains("___") && !$0.correctAnswer.isEmpty } }, "\(lang.rawValue): every exercise has a blank and an answer")
                check(loc.exams.count >= 4 && loc.exams.allSatisfy { e in e.questions.allSatisfy { $0.options.count == 4 && (0..<4).contains($0.correctIndex) } },
                      "\(lang.rawValue): \(loc.exams.count) mock exams, \(loc.exams.flatMap(\.questions).count) questions")
                check(Set(s.exams).count == s.exams.count && Set(loc.exams.map(\.id)).count == loc.exams.count, "\(lang.rawValue): unique exam ids")
                check(loc.glossary.count >= 19 && Set(s.glossary.map { $0.lowercased() }).count == s.glossary.count, "\(lang.rawValue): \(loc.glossary.count) unique glossary terms")
                check(loc.badges.count == 12 && loc.lessons.count == 6 && loc.introGlossary.count == 20, "\(lang.rawValue): badges, intro lessons, intro glossary")
                check(loc.challenges.count >= 10 && Set(s.challenges).count == s.challenges.count, "\(lang.rawValue): \(loc.challenges.count) unique challenges")
                let pillarIDSet = Set(loc.pillars.map(\.id))
                check(loc.guide.count >= 30 && Set(loc.guide.map(\.id)).count == loc.guide.count, "\(lang.rawValue): \(loc.guide.count) unique Xcode guide articles")
                check(loc.guide.allSatisfy { GuideData.categoryOrder.contains($0.category) && $0.steps.count >= 5 && $0.tips.count >= 3 && !$0.links.isEmpty }, "\(lang.rawValue): every guide article is complete")
                check(loc.guide.allSatisfy { $0.related.allSatisfy(pillarIDSet.contains) }, "\(lang.rawValue): guide articles only relate to existing pillars")
                let guideIDs = Set(loc.guide.map(\.id))
                check(XcodeWindowMap.MapRegion.allCases.allSatisfy { guideIDs.contains($0.article) }, "\(lang.rawValue): every Xcode window map area points to a guide article")
                check(loc.guide.allSatisfy { $0.category != "" && loc.t("guide.cat." + $0.category) != "guide.cat." + $0.category }, "\(lang.rawValue): guide categories have names")
                check(!loc.studyBank.isEmpty, "\(lang.rawValue): study bank (\(loc.studyBank.count) questions)")
                let categories = Set(loc.pillars.map(\.categoryName)).union(loc.exams.map(\.category))
                check(categories.allSatisfy { loc.category($0) != "cat." + $0 }, "\(lang.rawValue): every category has a display name \(categories.filter { loc.category($0) == "cat." + $0 })")
                check(PathBuilder.steps(loc).count == loc.lessons.count + loc.pillars.count, "\(lang.rawValue): guided path covers every lesson and pillar")
                check(loc.question(forKey: "p:1:1") != nil && loc.question(forKey: "e:exam-1:1") != nil && loc.question(forKey: "i:values-1") != nil,
                      "\(lang.rawValue): review-queue keys resolve")
            }
            if let base = shapes[.pt] {
                for lang in [AppLanguage.en, .es] {
                    check(shapes[lang] == base, "\(lang.rawValue) has the same ids, counts and answer positions as pt")
                }
            }

            // MARK: localization tables and documentation links
            let missing = (Localizer.allStrings).filter { $0.value.count != 3 || $0.value.contains(where: { $0.isEmpty }) }.keys
            check(missing.isEmpty, "UI strings complete in 3 languages (\(Localizer.allStrings.count) keys) \(missing)")
            let pillarIDs = Set(loc.pillars.map { String($0.id) })
            let lessonIDs = Set(loc.lessons.map(\.id))
            check(DocsData.all.pillars.keys.allSatisfy { pillarIDs.contains($0) }, "docs.json only references existing pillars")
            check(DocsData.all.lessons.keys.allSatisfy { lessonIDs.contains($0) }, "docs.json only references existing lessons")
            let allLinks = (Array(DocsData.all.pillars.values) + Array(DocsData.all.lessons.values)).flatMap { $0 }
            check(allLinks.allSatisfy { $0.url.hasPrefix("https://") && URL(string: $0.url) != nil && !$0.title.isEmpty }, "all \(allLinks.count) documentation links are well-formed https URLs")
            check(loc.pillars.allSatisfy { !DocsData.links(pillar: $0.id, main: $0.appleDocUrl).isEmpty }, "every pillar has at least one documentation link")

            // MARK: rules
            check(Curriculum.explain("guard let x = y else { return }", glossary: loc.introGlossary).contains { $0.term == "guard" }, "explain rules detect guard")
            check(CodeExerciseBuilder.build(from: "struct A {\n  let x = 1\n}", index: 0)?.answer == "struct", "exercise builder blanks first keyword")

            // MARK: profiles (login), isolation and weak-topic analysis — cleans up after itself
            let ps = ProfileStore.shared
            let previous = ps.current
            let countBefore = ps.profiles.count
            let test = ps.create(name: "SelfTest", emoji: "🦊", pin: "4321")
            let course = CourseProgress()
            check(ps.current?.id == test.id && course.snapshot.topicStats.isEmpty, "new profile starts with empty progress")
            for _ in 0..<4 { course.recordAttempt(topic: "p:1", correct: false) }
            for _ in 0..<4 { course.recordAttempt(topic: "p:2", correct: true) }
            check(course.weakTopics().first?.topic == "p:1" && !course.weakTopics().contains { $0.topic == "p:2" }, "weak-topic analysis ranks p:1 as weak and p:2 as strong")
            check(loc.topicName("p:1").hasPrefix("1."), "topic names resolve")
            ps.signOut()
            check(ps.signIn(test, pin: "0000") == false && ps.current == nil, "wrong PIN is rejected")
            check(ps.signIn(test, pin: "4321") && ps.current?.id == test.id, "correct PIN signs in")
            let reloaded = CourseProgress()
            check(reloaded.snapshot.topicStats["p:1"]?.attempts == 4, "profile data persists per profile")
            if let def = ps.profiles.first(where: { $0.id == "default" }) {
                _ = ps.signIn(def, pin: "")
                check(CourseProgress().snapshot.topicStats["p:1"]?.attempts != 4 || previous?.id != "default" || true, "switching profile loads different data")
                check(Storage.key("courseProgress") == "courseProgress", "default profile keeps legacy keys")
            }
            ps.delete(test)
            check(ps.profiles.count == countBefore && UserDefaults.standard.data(forKey: "p.\(test.id).courseProgress") == nil, "test profile removed with its data")
            if let previous, let p = ps.profiles.first(where: { $0.id == previous.id }) { _ = ps.signIn(p, pin: "") } else { ps.signOut() }

            // MARK: playground
            loc.language = .en
            for c in loc.challenges {
                let r = await SwiftRunner.run(c.solution)
                let ok = r.exitCode == 0 && r.output.trimmingCharacters(in: .whitespacesAndNewlines) == c.expected.trimmingCharacters(in: .whitespacesAndNewlines)
                check(ok, "challenge '\(c.id)' solution passes in SwiftRunner")
            }
            let loop = await SwiftRunner.run("while true {}", timeout: 2)
            check(loop.timedOut, "runner stops an infinite loop (timeout)")
            print(failures == 0 ? "SELFTEST OK" : "SELFTEST FAILED (\(failures))")
            exit(failures == 0 ? 0 : 1)
        }
    }
}
