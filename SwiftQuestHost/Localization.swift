import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en, pt, es

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: "English"
        case .pt: "Português (Brasil)"
        case .es: "Español"
        }
    }

    /// Name used when asking the AI coach to answer in this language.
    var promptName: String {
        switch self {
        case .en: "English"
        case .pt: "Brazilian Portuguese"
        case .es: "Spanish"
        }
    }

    static var systemDefault: AppLanguage {
        for code in Locale.preferredLanguages {
            if code.hasPrefix("pt") { return .pt }
            if code.hasPrefix("es") { return .es }
            if code.hasPrefix("en") { return .en }
        }
        return .en
    }
}

/// In-app language switching: UI strings plus language-specific course content.
@MainActor
final class Localizer: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            reload()
        }
    }

    private(set) var lessons: [Lesson] = []
    private(set) var introGlossary: [String: String] = [:]
    private(set) var pillars: [Pillar] = []
    private(set) var exams: [MockExam] = []
    private(set) var glossary: [GlossaryTerm] = []
    private(set) var badges: [Badge] = []
    private(set) var studyBank: [CourseQuestion] = []
    private(set) var challenges: [CodeChallenge] = []
    private(set) var guide: [GuideArticle] = []

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage").flatMap(AppLanguage.init(rawValue:))
        language = saved ?? .systemDefault
        reload()
    }

    private func reload() {
        let intro = IntroContent.load(language)
        lessons = intro.lessons
        introGlossary = intro.glossary
        pillars = CourseData.loadPillars(language)
        guide = CourseData.loadAll(prefix: "xcodeGuide", language)
        challenges = CourseData.load("challenges", language) + CourseData.loadAll(prefix: "challengesMore", language)
        exams = CourseData.load("mockExams", language) + CourseData.loadAll(prefix: "mockExamsMore", language)
        glossary = CourseData.load("glossary", language) + CourseData.loadAll(prefix: "glossaryMore", language)
        badges = CourseData.load("badges", language)

        // Study bank: every mock-exam question plus the quiz of each introductory lesson.
        var bank = exams.flatMap(\.questions)
        for lesson in lessons {
            for q in lesson.quiz {
                bank.append(CourseQuestion(id: 0, question: q.prompt, options: q.choices,
                                           correctIndex: q.answer, explanation: q.explanation))
            }
        }
        studyBank = bank
    }

    /// Resolves a review-queue key ("p:3:2", "e:exam-1:4", "i:values-1") to the question in the current language.
    func question(forKey key: String) -> (title: String, question: CourseQuestion)? {
        let parts = key.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count == 3 || (parts.count == 2 && parts[0] == "i") else { return nil }
        switch parts[0] {
        case "p":
            guard let pid = Int(parts[1]), let qid = Int(parts[2]), let p = pillars.first(where: { $0.id == pid }),
                  let q = p.quiz.first(where: { $0.id == qid }) else { return nil }
            return (p.title, q)
        case "e":
            guard let qid = Int(parts[2]), let e = exams.first(where: { $0.id == parts[1] }),
                  let q = e.questions.first(where: { $0.id == qid }) else { return nil }
            return (e.title, q)
        case "i":
            let id = parts.dropFirst().joined(separator: ":")
            for lesson in lessons {
                if let q = lesson.quiz.first(where: { $0.id == id }) {
                    return (lesson.title, CourseQuestion(id: 0, question: q.prompt, options: q.choices,
                                                         correctIndex: q.answer, explanation: q.explanation))
                }
            }
            return nil
        default: return nil
        }
    }

    func t(_ key: String) -> String {
        guard let row = Self.allStrings[key] else { return key }
        let index = AppLanguage.allCases.firstIndex(of: language) ?? 0
        return index < row.count ? row[index] : row[0]
    }

    func category(_ key: String) -> String { t("cat." + key) }

    func levelTitle(_ level: Int) -> String {
        switch level {
        case 1...4: t("lvl.\(level)")
        case 5..<8: t("lvl.5")
        default: t("lvl.8")
        }
    }

    // Order of each row: English, Português (Brasil), Español — same as AppLanguage.allCases.
    static let allStrings: [String: [String]] = strings.merging(featureStrings) { a, _ in a }

    static let strings: [String: [String]] = [
        "menu.about": ["About SwiftQuest", "Sobre o SwiftQuest", "Acerca de SwiftQuest"],
        "about.tagline": ["Learn Swift inside and alongside Xcode.", "Aprenda Swift dentro e ao lado do Xcode.", "Aprende Swift dentro y junto a Xcode."],
        "sidebar.intro": ["Start here", "Comece aqui", "Empieza aquí"],
        "sidebar.course": ["Full course", "Curso completo", "Curso completo"],
        "nav.learn": ["Learn", "Aprender", "Aprender"],
        "nav.practice": ["Practice", "Praticar", "Practicar"],
        "nav.explain": ["Explain Code", "Explicar código", "Explicar código"],
        "nav.course": ["Course", "Curso", "Curso"],
        "nav.exams": ["Mock exams", "Simulados", "Simulacros"],
        "nav.dashboard": ["My progress", "Meu progresso", "Mi progreso"],
        "nav.glossary": ["Glossary", "Glossário", "Glosario"],
        "nav.badges": ["Achievements", "Conquistas", "Logros"],
        "level": ["Level", "Nível", "Nivel"],
        "language": ["Language", "Idioma", "Idioma"],
        "next.level": ["next level at", "próximo nível em", "siguiente nivel en"],
        "pick.lesson": ["Pick a lesson", "Escolha uma lição", "Elige una lección"],
        "pick.pillar": ["Pick a topic", "Escolha um pilar", "Elige un pilar"],
        "try.xcode": ["Try it in Xcode", "Experimente no Xcode", "Pruébalo en Xcode"],
        "check.yourself": ["Check yourself", "Teste-se", "Ponte a prueba"],
        "lesson.completed": ["Completed — tap to undo", "Concluída — toque para desfazer", "Completada — toca para deshacer"],
        "lesson.mark": ["Mark lesson complete", "Marcar lição como concluída", "Marcar lección como completada"],
        "practice.sub": ["Random questions from the mock exams and every lesson.", "Questões aleatórias dos simulados e de todas as lições.", "Preguntas aleatorias de los simulacros y de todas las lecciones."],
        "nothing.yet": ["Nothing yet.", "Nada ainda.", "Nada todavía."],
        "next.question": ["Next question", "Próxima questão", "Siguiente pregunta"],
        "explain.title.xcode": ["Explain This Swift", "Explicar este Swift", "Explicar este Swift"],
        "explain.empty": ["In Xcode, select Swift code and choose Editor → SwiftQuest Xcode Extension → Explain This Swift. Or paste code below.",
                          "No Xcode, selecione código Swift e escolha Editor → SwiftQuest Xcode Extension → Explain This Swift. Ou cole código abaixo.",
                          "En Xcode, selecciona código Swift y elige Editor → SwiftQuest Xcode Extension → Explain This Swift. O pega código abajo."],
        "explain.inside": ["What's in this code", "O que há neste código", "Qué hay en este código"],
        "explain.none": ["No known concepts detected. More will be added over time.", "Nenhum conceito conhecido detectado. Mais serão adicionados com o tempo.", "No se detectaron conceptos conocidos. Se añadirán más con el tiempo."],
        "learn.more": ["Learn more", "Saiba mais", "Más información"],
        "explain.offline": ["This explanation is rule-based and works offline.", "Esta explicação é baseada em regras e funciona offline.", "Esta explicación se basa en reglas y funciona sin conexión."],
        "correct": ["Correct.", "Correto.", "Correcto."],
        "incorrect": ["Not quite.", "Incorreto.", "Incorrecto."],
        "score": ["Score", "Acertos", "Aciertos"],
        "official.docs": ["Official documentation", "Documentação oficial", "Documentación oficial"],
        "case.corporate": ["Corporate case", "Caso corporativo", "Caso corporativo"],
        "case.game": ["Game case", "Caso em jogos", "Caso en videojuegos"],
        "exercises": ["Exercises", "Exercícios", "Ejercicios"],
        "quiz": ["Quiz", "Quiz", "Quiz"],
        "quiz.extra": ["Extra quiz", "Quiz extra", "Quiz extra"],
        "quiz.extra.show": ["Show extra quiz", "Mostrar quiz extra", "Mostrar quiz extra"],
        "fill.blank": ["Fill in the blank (___)", "Preencha o espaço (___)", "Rellena el espacio (___)"],
        "check": ["Check", "Verificar", "Comprobar"],
        "hint": ["Hint", "Dica", "Pista"],
        "hint.hide": ["Hide hint", "Esconder dica", "Ocultar pista"],
        "correct.short": ["Correct!", "Correto!", "¡Correcto!"],
        "try.again": ["Not yet. Try again.", "Ainda não. Tente de novo.", "Todavía no. Inténtalo de nuevo."],
        "exams.pass": ["Pass with 70% or more.", "Aprovação com 70% ou mais.", "Se aprueba con 70% o más."],
        "questions": ["questions", "questões", "preguntas"],
        "start": ["Start", "Iniciar", "Empezar"],
        "exam.passed": ["Passed!", "Aprovado!", "¡Aprobado!"],
        "exam.failed": ["Not passed", "Não aprovado", "No aprobado"],
        "finish": ["Finish", "Finalizar", "Finalizar"],
        "back.exams": ["Back to mock exams", "Voltar aos simulados", "Volver a los simulacros"],
        "cancel": ["Cancel", "Cancelar", "Cancelar"],
        "search": ["Search", "Buscar", "Buscar"],
        "save.term": ["Save term", "Guardar termo", "Guardar término"],
        "badge.unlocked": ["New achievement unlocked!", "Nova conquista desbloqueada!", "¡Nuevo logro desbloqueado!"],
        "keep.going": ["Keep going", "Continuar", "Continuar"],
        "status.mastered": ["Mastered", "Dominado", "Dominado"],
        "status.inprogress": ["In progress", "Em progresso", "En progreso"],
        "status.review": ["Needs review", "Revisar conceitos", "Repasar conceptos"],
        "status.notstarted": ["Not started", "Não iniciado", "Sin empezar"],
        "status.review.hint": ["Your quiz score is below 60%. Reread the theory and try again.", "Sua nota no quiz está abaixo de 60%. Releia a teoria e tente de novo.", "Tu nota del quiz es inferior al 60%. Relee la teoría e inténtalo de nuevo."],
        "ai.title": ["Optional AI coach", "Coach de IA (opcional)", "Coach de IA (opcional)"],
        "ai.key": ["Anthropic API key", "Chave de API da Anthropic", "Clave de API de Anthropic"],
        "ai.model": ["Model", "Modelo", "Modelo"],
        "ai.privacy": ["Your key is stored in the macOS Keychain. Code is sent to Anthropic only when you press an Ask button in Explain Code. Everything else in SwiftQuest works without AI.",
                       "Sua chave fica no Keychain do macOS. O código só é enviado à Anthropic quando você aperta o botão de perguntar em Explicar código. Todo o resto do SwiftQuest funciona sem IA.",
                       "Tu clave se guarda en el Llavero de macOS. El código solo se envía a Anthropic cuando pulsas el botón de preguntar en Explicar código. Todo lo demás en SwiftQuest funciona sin IA."],
        "ai.panel": ["AI coach (optional)", "Coach de IA (opcional)", "Coach de IA (opcional)"],
        "ai.addkey": ["Add your API key in SwiftQuest → Settings (⌘,) to enable the coach.", "Adicione sua chave de API em SwiftQuest → Ajustes (⌘,) para ativar o coach.", "Añade tu clave de API en SwiftQuest → Ajustes (⌘,) para activar el coach."],
        "ai.question": ["Ask a question about this code (optional)", "Faça uma pergunta sobre este código (opcional)", "Haz una pregunta sobre este código (opcional)"],
        "ai.ask": ["Ask AI coach", "Perguntar ao coach de IA", "Preguntar al coach de IA"],
        "ai.sends": ["Sends the code above to Anthropic using your key.", "Envia o código acima à Anthropic usando sua chave.", "Envía el código de arriba a Anthropic usando tu clave."],
        "cat.Fundamentos": ["Fundamentals", "Fundamentos", "Fundamentos"],
        "cat.Swift Avançado": ["Advanced Swift", "Swift Avançado", "Swift avanzado"],
        "cat.iOS e iPadOS": ["iOS & iPadOS", "iOS e iPadOS", "iOS e iPadOS"],
        "cat.watchOS": ["watchOS", "watchOS", "watchOS"],
        "cat.macOS": ["macOS", "macOS", "macOS"],
        "cat.visionOS": ["visionOS", "visionOS", "visionOS"],
        "cat.Full-Stack Apple": ["Full-Stack Apple", "Full-Stack Apple", "Full-Stack Apple"],
        "lvl.1": ["Swift Beginner", "Iniciante Swift", "Principiante Swift"],
        "lvl.2": ["iOS Apprentice", "Aprendiz iOS", "Aprendiz iOS"],
        "lvl.3": ["SwiftUI Developer", "Desenvolvedor SwiftUI", "Desarrollador SwiftUI"],
        "lvl.4": ["Apple Architect", "Arquiteto Apple", "Arquitecto Apple"],
        "lvl.5": ["Swift Specialist", "Especialista em Swift", "Especialista en Swift"],
        "lvl.8": ["Apple Grandmaster", "Grão-Mestre Apple", "Gran Maestro Apple"]
    ]
}
