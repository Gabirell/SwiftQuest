# SwiftQuest

Learn Swift inside and alongside Xcode. A macOS app plus an Xcode Source Editor Extension, in English, Português (Brasil) and Español.

## What's inside
- **Profiles (login)** – local profiles on this Mac, each with its own progress, flashcards, habits and statistics (optional PIN lock). Existing data becomes the default profile.
- **Needs attention** – tracks every answer per topic and shows which topics need more study (recent accuracy), with a "drill my weak spots" session.
- **My path** – guided, ordered steps (lessons, then every course topic grouped by category) with locks, *Continue*, a daily goal and streak.
- **Certification** – Apple's "App Development with Swift" (Certified User / Associate) domains mapped to the topics and mock exams that cover them, with readiness per domain.
- **Course** – 79 topics in EN / PT-BR / ES: Swift fundamentals and advanced Swift, Xcode & tools, planning & design (design cycle, HIG, accessibility, privacy), SwiftUI, UIKit & Interface Builder, data & networking (SwiftData, Core Data, CloudKit, Keychain), system features (location, notifications, widgets, App Intents, photos, iPad), AI & machine learning (Core ML, Vision, Foundation Models), distribution (signing, TestFlight, App Store, StoreKit), visionOS/watchOS/macOS and guided projects. Every topic has theory, real-world cases, fill-in exercises, quizzes and **several verified links to Apple / Swift documentation** (with section anchors).
- **Mock exams** – 14 timed exams incl. a 40-question Associate practice exam, a glossary (200+ terms), progress dashboard, mind map, achievements (XP, levels, badges).
- **Learn / Practice / Review** – offline lessons and quizzes, a study bank, and a review queue for questions you got wrong.
- **Playground** – write and run Swift (uses the system toolchain from Xcode / Command Line Tools) with 30 auto-checked challenges.
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

## Content quality
All course content is validated: structure and translation parity (`--selftest`), documentation links (checked against the DocC data endpoints, including anchors), and playground solutions (run with the Swift toolchain). AI-authored content was independently reviewed question by question; objectives follow Certiport's published list, but always check the current exam objectives before taking an exam. SwiftQuest is independent practice material and is not affiliated with Apple or Certiport.
