import Foundation

extension Localizer {
    // Order of each row: English, Português (Brasil), Español.
    static let featureStrings: [String: [String]] = [
        "sidebar.today": ["Today", "Hoje", "Hoy"],
        "nav.path": ["My path", "Minha trilha", "Mi ruta"],
        "nav.review": ["Review", "Revisão", "Repaso"],
        "nav.flashcards": ["Flashcards", "Flashcards", "Flashcards"],
        "nav.playground": ["Playground", "Playground", "Playground"],
        "nav.mindmap": ["Mind map", "Mapa mental", "Mapa mental"],
        "nav.placement": ["Placement quiz", "Teste de nível", "Prueba de nivel"],
        "cat.Swift Moderno": ["Modern Swift", "Swift Moderno", "Swift moderno"],
        "cat.Dados e Rede": ["Data & Networking", "Dados e Rede", "Datos y red"],
        "cat.Projetos": ["Projects", "Projetos", "Proyectos"],

        // Flashcards
        "flash.sub": ["Code you saved from Xcode, reviewed with spaced repetition.", "Código que você salvou do Xcode, revisado com repetição espaçada.", "Código que guardaste desde Xcode, repasado con repetición espaciada."],
        "flash.empty": ["No flashcards yet. In Xcode, select code and choose Editor → SwiftQuest Xcode Extension → Save as Flashcard.", "Nenhum flashcard ainda. No Xcode, selecione código e escolha Editor → SwiftQuest Xcode Extension → Save as Flashcard.", "Aún no hay flashcards. En Xcode, selecciona código y elige Editor → SwiftQuest Xcode Extension → Save as Flashcard."],
        "flash.due": ["Due for review", "Para revisar", "Para repasar"],
        "flash.question": ["What does this code do?", "O que este código faz?", "¿Qué hace este código?"],
        "flash.reveal": ["Show explanation", "Mostrar explicação", "Mostrar explicación"],
        "flash.again": ["Again", "De novo", "Otra vez"],
        "flash.knew": ["I knew it", "Eu sabia", "Lo sabía"],
        "flash.alldone": ["All caught up. Come back later!", "Tudo em dia. Volte mais tarde!", "Todo al día. ¡Vuelve más tarde!"],
        "flash.all": ["All cards", "Todos os cards", "Todas las tarjetas"],
        "flash.saved": ["Saved as a flashcard.", "Salvo como flashcard.", "Guardado como flashcard."],
        "flash.exists": ["This code is already a flashcard.", "Este código já é um flashcard.", "Este código ya es una flashcard."],
        "delete": ["Delete", "Excluir", "Eliminar"],

        // Exercise from your code
        "ex.title": ["Exercise from your code", "Exercício do seu código", "Ejercicio de tu código"],
        "ex.prompt": ["Fill in the missing keyword.", "Preencha a palavra-chave que falta.", "Rellena la palabra clave que falta."],
        "ex.another": ["Another blank", "Outro espaço", "Otro hueco"],
        "ex.none": ["No keyword to blank out in this code. Try a longer selection.", "Nenhuma palavra-chave para esconder neste código. Tente uma seleção maior.", "No hay palabra clave que ocultar en este código. Prueba con una selección más larga."],

        // Habits
        "habit.goal": ["Daily goal", "Meta diária", "Meta diaria"],
        "habit.goal.met": ["Daily goal reached. Great work!", "Meta diária atingida. Ótimo trabalho!", "Meta diaria alcanzada. ¡Gran trabajo!"],
        "habit.streak.days": ["day streak", "dias seguidos", "días seguidos"],
        "habit.settings": ["Study habits", "Hábitos de estudo", "Hábitos de estudio"],
        "habit.reminder": ["Daily reminder", "Lembrete diário", "Recordatorio diario"],
        "habit.reminder.time": ["Reminder time", "Horário do lembrete", "Hora del recordatorio"],
        "habit.denied": ["Notifications are turned off for SwiftQuest in System Settings.", "As notificações do SwiftQuest estão desativadas nos Ajustes do Sistema.", "Las notificaciones de SwiftQuest están desactivadas en Ajustes del Sistema."],
        "habit.notif.title": ["Time to practice Swift", "Hora de praticar Swift", "Hora de practicar Swift"],
        "habit.notif.body": ["A few minutes today keep your streak alive.", "Alguns minutos hoje mantêm sua sequência viva.", "Unos minutos hoy mantienen viva tu racha."],

        // Onboarding / path / review / placement
        "onb.welcome": ["Welcome to SwiftQuest", "Bem-vindo ao SwiftQuest", "Bienvenido a SwiftQuest"],
        "onb.sub": ["Learn Swift inside and alongside Xcode, with lessons, a code playground and practice that works without AI.", "Aprenda Swift dentro e ao lado do Xcode, com lições, um playground de código e prática que funciona sem IA.", "Aprende Swift dentro y junto a Xcode, con lecciones, un playground de código y práctica que funciona sin IA."],
        "onb.goal": ["Daily goal (activities)", "Meta diária (atividades)", "Meta diaria (actividades)"],
        "onb.how": ["Not a beginner? Take a short placement quiz to unlock part of the path.", "Não é iniciante? Faça um teste de nível rápido para liberar parte da trilha.", "¿No eres principiante? Haz una prueba de nivel breve para desbloquear parte de la ruta."],
        "onb.placement": ["Take placement quiz", "Fazer teste de nível", "Hacer prueba de nivel"],
        "onb.start": ["Start from the beginning", "Começar do início", "Empezar desde el principio"],
        "path.continue": ["Continue", "Continuar", "Continuar"],
        "path.alldone": ["You finished the whole path!", "Você concluiu toda a trilha!", "¡Terminaste toda la ruta!"],
        "path.placement": ["Placement quiz", "Teste de nível", "Prueba de nivel"],
        "path.unlockall": ["Unlock all steps", "Liberar todas as etapas", "Desbloquear todos los pasos"],
        "path.steps.done": ["steps completed", "etapas concluídas", "pasos completados"],
        "path.next": ["Next", "Próxima", "Siguiente"],
        "a11y.completed": ["completed", "concluída", "completado"],
        "a11y.available": ["available", "disponível", "disponible"],
        "a11y.locked": ["locked", "bloqueada", "bloqueado"],
        "review.sub": ["Questions you missed come back here until you answer them correctly.", "As questões que você errou voltam aqui até você acertar.", "Las preguntas que fallaste vuelven aquí hasta que las aciertes."],
        "review.empty": ["Nothing to review. Great job!", "Nada para revisar. Ótimo trabalho!", "Nada que repasar. ¡Buen trabajo!"],
        "review.pending": ["to review", "para revisar", "por repasar"],
        "placement.sub": ["10 mixed questions. Your score unlocks part of the guided path.", "10 questões variadas. Sua nota libera parte da trilha guiada.", "10 preguntas variadas. Tu nota desbloquea parte de la ruta guiada."],
        "placement.result": ["steps unlocked:", "etapas liberadas:", "pasos desbloqueados:"],

        // Playground
        "pg.free": ["Free play", "Livre", "Libre"],
        "pg.free.sub": ["Write any Swift code and run it. Needs Xcode or the Command Line Tools installed.", "Escreva qualquer código Swift e execute. Requer Xcode ou as Command Line Tools instaladas.", "Escribe cualquier código Swift y ejecútalo. Requiere Xcode o las Command Line Tools instaladas."],
        "pg.challenges": ["Challenges", "Desafios", "Desafíos"],
        "pg.run": ["Run", "Executar", "Ejecutar"],
        "pg.reset": ["Reset", "Reiniciar", "Reiniciar"],
        "pg.solution": ["Show solution", "Ver solução", "Ver solución"],
        "pg.solution.hide": ["Hide solution", "Esconder solução", "Ocultar solución"],
        "pg.pass": ["Correct! Output matches.", "Correto! A saída confere.", "¡Correcto! La salida coincide."],
        "pg.fail": ["Output does not match yet.", "A saída ainda não confere.", "La salida aún no coincide."],
        "pg.expected": ["Expected output", "Saída esperada", "Salida esperada"],
        "pg.output": ["Output", "Saída", "Salida"],
        "pg.notool": ["Swift was not found. Install Xcode or run xcode-select --install.", "Swift não encontrado. Instale o Xcode ou execute xcode-select --install.", "No se encontró Swift. Instala Xcode o ejecuta xcode-select --install."],
        "pg.timeout": ["The program ran too long and was stopped (20 s).", "O programa demorou demais e foi interrompido (20 s).", "El programa tardó demasiado y se detuvo (20 s)."],

        // Export
        "export": ["Export", "Exportar", "Exportar"],
        "export.title": ["Progress report", "Relatório de progresso", "Informe de progreso"]
    ]
}
