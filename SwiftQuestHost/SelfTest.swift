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
            for lang in AppLanguage.allCases {
                loc.language = lang
                check(loc.pillars.count == 25, "\(lang.rawValue): 25 pillars (got \(loc.pillars.count))")
                check(loc.pillars.allSatisfy { $0.exercises.count >= 5 && $0.quiz.count >= 5 }, "\(lang.rawValue): every pillar has >=5 exercises and >=5 quiz questions")
                check(loc.exams.count == 4 && loc.glossary.count == 19 && loc.badges.count == 12, "\(lang.rawValue): exams/glossary/badges")
                check(loc.lessons.count == 6 && loc.introGlossary.count == 20, "\(lang.rawValue): intro lessons + glossary")
                check(loc.challenges.count == 10, "\(lang.rawValue): 10 challenges")
                check(!loc.studyBank.isEmpty, "\(lang.rawValue): study bank (\(loc.studyBank.count) questions)")
                let categories = Set(loc.pillars.map(\.categoryName))
                check(categories.allSatisfy { loc.category($0) != "cat." + $0 }, "\(lang.rawValue): every category has a display name")
                check(PathBuilder.steps(loc).count == 31, "\(lang.rawValue): guided path has 31 steps")
                check(loc.question(forKey: "p:1:1") != nil && loc.question(forKey: "e:exam-1:1") != nil && loc.question(forKey: "i:values-1") != nil,
                      "\(lang.rawValue): review-queue keys resolve")
            }
            let missing = (Localizer.allStrings).filter { $0.value.count != 3 || $0.value.contains(where: { $0.isEmpty }) }.keys
            check(missing.isEmpty, "UI strings complete in 3 languages (\(Localizer.allStrings.count) keys) \(missing)")
            check(Curriculum.explain("guard let x = y else { return }", glossary: loc.introGlossary).contains { $0.term == "guard" }, "explain rules detect guard")
            check(CodeExerciseBuilder.build(from: "struct A {\n  let x = 1\n}", index: 0)?.answer == "struct", "exercise builder blanks first keyword")

            // Every challenge solution must pass through the app's own runner.
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
