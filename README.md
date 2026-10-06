# SwiftQuest 🎮🍎

**Learn Swift. Build games. Build real apps. Think like an Apple developer.**

SwiftQuest is a curriculum-first Swift learning platform designed to help learners progress from Swift fundamentals to practical app development and Apple-style technical preparation.

## What SwiftQuest includes

- 📚 Structured Swift lessons with simple explanations
- 🎮 A videogame example for concepts and exercises
- 💼 A professional app/development example
- 🧪 Hands-on coding challenges
- 🍎 Apple-style practice questions and mock exams
- 🏆 XP, ranks, missions, achievements, mastery and boss challenges
- 🧠 A knowledge map that recommends what to study next
- 💻 Xcode learning extension foundations and practice projects
- 🌎 Português, English and Español, with Spanish available globally
- 🔐 Google, Apple and LinkedIn authentication, with Meta/Facebook support in the architecture
- ☁️ Firebase-backed account and progress synchronization

## AI is optional

SwiftQuest's core curriculum and progression do **not** require AI.

AI is an optional coaching layer for users who want help explaining code, debugging, or generating extra practice. It is designed around two models:

1. **Bring your own provider key**, so the learner pays their AI provider directly.
2. **SwiftQuest AI Credits**, so managed AI usage can be metered, rate-limited and monetized safely.

AI usage never grants XP or exam advantages.

## Languages

The interface uses three global language choices:

- Português
- English
- Español

Spanish content follows Spain-standard editorial terminology while remaining suitable for Spanish-speaking learners worldwide.

## Project structure

```text
src/                       Web learning application
src/domain/                Core curriculum, progress, gamification and AI contracts
src/components/            Lessons, dashboard, missions, exams and AI UI
src/i18n/                  Localization infrastructure
src/services/              Progress, migration and AI gateway services
xcode/SwiftQuestExtension/ Xcode extension foundation and practice challenges
docs/                      Curriculum alignment and deployment documentation
```

## Local development

### Requirements

- Node.js
- npm
- Xcode for the native extension work

### Start the web app

```bash
npm install
npm run dev
```

Copy `.env.example` to `.env.local` and provide only the configuration required for the services you want to enable locally.

### Verify the project

```bash
npm test
node scripts/verify-swiftquest.mjs
```

The Xcode extension package can be tested from `xcode/SwiftQuestExtension` with Swift Package Manager/Xcode.

## Firebase and AI configuration

Firebase is used for authentication, progress synchronization and server-side controls. AI is intentionally optional. Do not place server secrets, payment secrets or privileged provider credentials in client-side code.

See [`docs/deployment.md`](docs/deployment.md) for deployment and service configuration notes.

## Apple preparation

SwiftQuest provides **Apple-style practice**, not official Apple exam content. The curriculum is aligned with modern Swift and Apple development concepts and is intended as preparation and practice.

## License

The repository currently does not declare an open-source license. All rights are reserved unless a license is added by the project owner.
