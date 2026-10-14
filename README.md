# SwiftQuest

Learn Swift inside and alongside Xcode. A macOS app plus an Xcode Source Editor Extension, in English, Português (Brasil) and Español.

## What's inside
- **My path** – guided, ordered steps (lessons then 25 course pillars) with locks, *Continue*, a daily goal and streak.
- **Learn / Practice** – offline lessons, quizzes, and a study bank. **Review** brings back questions you got wrong.
- **Playground** – write and run Swift (uses the system toolchain from Xcode / Command Line Tools) with 10 auto-checked challenges.
- **Course** – 25 pillars: fundamentals, advanced Swift, modern Swift (concurrency, testing, errors), data & networking, platforms, and step-by-step projects. Plus mock exams, a glossary, a progress dashboard, a mind map and achievements (XP, levels, badges).
- **Flashcards** – code saved from Xcode, reviewed with spaced repetition.
- **Explain Code** – rule-based, offline explanations, with an optional AI coach (bring your own Anthropic key, stored in the Keychain).
- **Export** progress as Markdown or JSON; optional daily reminder (Settings, ⌘,).

## Xcode extension commands (Editor → SwiftQuest Xcode Extension)
- **Explain This Swift** – opens the selection in the app.
- **Save as Flashcard** – saves the selection as a flashcard.
- **Turn Into Exercise** – blanks a keyword in your code to fill in.
- **Explain in Comment** – inserts short explanations as comments right in the editor (no app needed).

## Build & test
Open `SwiftQuestXcode.xcodeproj` (do not open it as a Swift package), select the `SwiftQuest` scheme and run. To test the extension, run the `SwiftQuestExtension` scheme and choose Xcode.

Headless self-test of all bundled content and the playground runner:

    SwiftQuest.app/Contents/MacOS/SwiftQuest --selftest

Course content lives in `SwiftQuestHost/Content/*.<lang>.json`; UI strings in `Localization.swift` and `StringsFeatures.swift`.
