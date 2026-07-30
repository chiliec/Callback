---
project: Callback
linear_project_id: skip
---

# Callback — iOS interview-prep app

Native iPhone app (iOS 18+) to prepare for iOS developer interviews. Local-first,
no accounts, no network. Modern MV + `@Observable` + SwiftData. Two local SPM packages
(`DesignSystem`, `AppCore`) + app target, wired via XcodeGen.

## Status: Phase 6 complete — Phase 7 next

- **Repo:** https://github.com/chiliec/Callback (public, `main`)
- **Spec:** `~/Develop/Pet/Journal/Projects/Callback/specs/2026-07-29-callback-design.md`
- **Roadmap:** `~/Develop/Pet/Journal/Projects/Callback/plans/2026-07-29-callback-roadmap.md`
- **Phase 1 plan (executed):** `~/Develop/Pet/Journal/Projects/Callback/plans/2026-07-29-callback-phase1-foundations.md`
- **Phase 5 plan (executed):** `~/Develop/Pet/Journal/Projects/Callback/plans/2026-07-30-callback-phase5-onboarding-profile.md`
- **Phase 6 plan (executed):** `~/Develop/Pet/Journal/Projects/Callback/plans/2026-07-30-callback-phase6-content.md` — Core-6 content bundle (v2), Standard depth (3 lessons + 10 Q/topic), + idempotent seeding
- **Design handoff (reference):** `design_handoff_callback_ios/` (open `Interview Prep iOS.dc.html`; README has all tokens/screens).

## Key decisions

- Goal: portfolio showpiece **and** real study tool (equal weight).
- iPhone-first; iPad deferred. iOS 18 minimum.
- Content: hand-authored curated seed — **Core 6 topics deep** (Swift, Memory,
  Concurrency, SwiftUI, UIKit, Behavioral).
- Behavioral questions use a `rubric` (no single correct answer).
- Readiness = coverage-aware weighted mean of topic masteries; mastery = recency-weighted
  accuracy. All in a tested `ScoringEngine`.

## What's built (Phases 1 + 2)

**AppCore package** (`Packages/AppCore/`) — 20 tests passing:
- SwiftData model graph: `Topic`, `Lesson`, `Question`, `CodeSnippet`, `Option`, `Session`, `AnswerRecord`, `UserProfile`
- `AppModelContainer` — schema + in-memory factory
- `ContentLoader` — JSON decode, seed, version-guard (TDD)
- `ScoringEngine` — recency-weighted mastery, coverage-aware readiness, accuracy, streakDays (TDD, pinned math)
- `ReviewQueue` — dedupe/filter/sort over AnswerRecord (TDD)
- `content-v1.json` — 2 seed topics: Swift (2 Q + 1 lesson) + Behavioral (1 Q)

**DesignSystem package** (`Packages/DesignSystem/`) — 7 tests passing:
- `Tokens.swift` — DSColor, DSRadius, DSSpacing, DSFont, DSCode (with `#if canImport(UIKit)` guards for macOS test compat)
- `SwiftSyntaxHighlighter` — line tokenizer (TDD)
- `CodeBlock` — header + gutter + horizontal-scrolling highlighted view
- `ProgressRing`, `IconTile`, `GroupedCard`, `SectionHeader`
- `PrimaryButtonStyle`, `TintedButtonStyle`
- `SegmentedFilter`, `OptionRow` + `AnswerState`, `WeeklyBarChart`

**App target (Phase 1):**
- `CallbackApp` — injects `ModelContainer`, seeds content on first launch via `bootstrap()`

**App target (Phase 2) — core loop skeleton:**
- `AppCoordinator` (`@Observable`) — `selectedTab: AppTab`, `topicsFilter: TopicFilter`; cross-tab navigation state
- `AppTabView` — 4-tab shell (Home / Topics / Practice / Profile) using iOS 18 `Tab(value:)` API
- `HomeView` — readiness ring (76pt/stroke 7), delta, Streak/Answered/Accuracy stats grid, Continue card, Weak Areas deep-link
- `TopicsView` + `TopicRow` — sections by `TopicSection`, search, All/Weak/Saved filter, `NavigationLink` push to TopicDetail
- `TopicDetailView` — 68pt mastery ring, below-target status, full-width Practice CTA, lessons list, question-bank counts
- `DrillSession` (`@Observable`) — in-progress drill state: questions, picks, currentIndex, advance/complete
- `QuestionPlayerView` — kicker, question (20/700), optional CodeBlock, A–D `OptionRow` answer mechanic, verdict chip + explanation, Next/Finish, drill-complete screen
- `DrillCompletion.save(throws:)` — inserts `AnswerRecord`s, recomputes `Topic.mastery` + `UserProfile` (readiness, delta, answeredCount, accuracy, streakDays) via `ScoringEngine`

**App target (Phase 3):**
- `MockSession` (`@MainActor @Observable`) — countdown timer, pause/resume, background persistence via `scenePhase`, flag toggle, pick/advance
- `MockCompletion` — creates `Session` entity, links `AnswerRecord`s, recomputes multi-topic mastery + readiness, returns `readinessDelta` + `toReviewCount`
- `MockSessionView` — fullscreen modal, toolbar (pause / mm:ss / flag), frosted pause overlay, same answer mechanic as `QuestionPlayerView`, pushes `SessionResultsView` on complete
- `SessionResultsView` — 100pt ring, correct/total, meta line, readiness + review chips, by-topic mini-bar breakdown, CTA buttons
- `PracticeView` — mock card with level segmented picker, timed drill rows (Rapid Fire / Code Review / System Design), recent sessions list

**App target (Phase 4):**
- `ReviewQueueView` — filter (All/Wrong/Flagged), per-row wrong/flagged badges, "Review N" CTA, empty state 9b (all-clear)
- `ReviewItemView` — paginated answer-vs-correct comparison cards, explanation, covers-gap lesson row
- `LessonReaderView` + `LessonBodyParser` — prose/code-fence/keyIdea segments, scroll-driven 3pt progress bar, mark-complete (+1 mastery, readiness recompute), completed card with undo, `QuickCheckView` inline
- `TopicsView` empty state 9c — saved-filter overlay when no saved topics
- `AppCore ReviewItem` — `pickedIndex: Int?` added; `ReviewQueue.build()` copies it from `AnswerRecord`
- Navigation: TopicDetailView lessons → `NavigationLink(value: Lesson)`; SessionResultsView "Review N" → `ReviewQueueView`; ReviewItemView covers-gap → `LessonReaderView`

**App target (Phase 5):**
- `LaunchView` + `RootView` — brand splash (96pt rounded tile, `DSColor.action`, curlybraces, "Get the callback."), ZStack overlay with 1.1s auto-dismiss + `.easeOut(0.18)` fade; `reduceMotion` skips animation
- `SaveErrorState` (`@Observable`) — app-level error presenter injected via `.environment()`; `.saveErrorAlert()` ViewModifier
- `FirstRunHomeView` — dashed placeholder readiness ring, blue CTA card, zeroed stats, starter topic chips; shown when `!profile.hasCompletedPlacement`
- `HomeView` — branches on `hasCompletedPlacement` in body; `.fullScreenCover` drives `PlacementQuizView` via `$coordinator.showPlacement`
- `PlacementSession` (`@Observable`) — `questions`, `picks`, `currentIndex`, `advance()`, `skip()`, `makeQuestions(from:)` (round-robin, min 12)
- `PlacementQuizView` — progress bar, `AnswerState.selected` (blue, no verdict), 450ms auto-advance `Task`, skip button, save via `PlacementCompletion`, pushes `PlacementResultsView`
- `PlacementCompletion` — inserts `AnswerRecord`s for answered (not skipped), recomputes mastery + readiness + profile stats, sets `hasCompletedPlacement = true`; `PlacementResult` (readiness, solid/focus topics, weekPlan)
- `PlacementResultsView` — 100pt ring, topic chips via custom `FlowLayout: Layout`, solid (green) / focus (orange) chips, 5-day week plan, "Start day 1" CTA
- `PlacementCompletionTests` — 5 Swift Testing tests covering mastery seeding, skipped record count, solid/focus split, readiness equality
- `ProfileView` (full replacement) — Goal (role/level/date/daily goal), Activity (WeeklyBarChart, all sessions, answer history), Notifications (toggle + async auth + `UNCalendarNotificationTrigger`), Data (export via ShareSheet, reset via confirmationDialog), version footer
- `DataExport` — `Codable` snapshot structs + `DataExporter.makeJSON` (prettyPrinted, sortedKeys, iso8601)
- `OptionRow.AnswerState.selected` — new case; blue fill/border (`DSColor.actionTint` / `DSColor.action`), no verdict icon
- Carry-forwards: `ReviewItemView` Retry → single-question `DrillSession`; `PracticeView` ReviewQueue entry; `QuickCheckView` persists `AnswerRecord` + updates mastery; `QuestionPlayerView` + `MockSessionView` surface save errors via `SaveErrorState` (replaces `try?`)

## Known carry-forward items (for Phase 6)

**From Phase 1 (unchanged):**
- `weeklyActivity: [Int]` in UserProfile stored as Transformable — no SQL predicates on it
- `ContentLoader.seed()` relies on implicit SwiftData cascade-insert for Lesson/Option/CodeSnippet (works; make explicit)
- `Session.score` uses default IEEE 754 rounding; consider `.toNearestOrAwayFromZero`
- `DSCode.functionDecl` defined but no matching `SyntaxTokenKind` — dead token
- `SyntaxTokenKind.call` never produced by tokenizer — dead enum case
- `OptionRow` border-width via Color equality comparison — works but fragile pattern

**From Phase 2:**
- `.padding(.vertical, 8)` bare literals in HomeView + TopicsView safeAreaInset (no DSSpacing token)
- `PrimaryButtonStyle` not used in `QuestionPlayerView` (inline modifier chain)
- `.background(.bar)` after `.clipShape` on Done button in drill-complete view (minor visual bleed)
- Behavioral-only drill shows "0 of 0 correct" on completion screen
- `DrillCompletion.save` makes 3 sequential `context.fetch` calls; the first is a subset of the third — can be combined
- `try? DrillCompletion.save(...)` at call site silently swallows save errors — Phase 5 for user-facing error handling
- Only available simulator is `iPad Pro 12.9 shots` (iOS 26.4) — iPhone 16 not installed

**From Phase 3:**
- `MockSessionView` progress bar height not enforced to 3pt (`.frame(height: 3)` missing — uses system default ~4pt)
- `saveSession()` silently swallows `MockCompletion.save` errors via `try?`
- `PracticeView` Start button uses `.padding(.vertical, 14)` bare literal; divider leading `56` has no named token

**App target (Phase 6):**
- `content-v1.json` — bumped to **version 2** (file renamed stays `content-v1.json`); 6 topics × 3 lessons × 10 questions = 18 lessons + 60 questions + 18 quickChecks (96 question objects total)
- `ContentLoader.seed` — rewritten to **upsert by id**; author-owned fields updated, user progress (mastery, isSaved, isComplete, AnswerRecords) preserved on version bump
- **22 AppCore tests** passing (added: `seedIsIdempotentOnReseed`, `contentBundleIsValid`)

## Next session

**Phase 7** — Polish + distribution prep: app icon, launch screen polish, TestFlight build, and/or any UX improvements surfaced from dogfooding with real content.

**Pending test run:** `xcodebuild test -project Callback.xcodeproj -scheme Callback -destination 'platform=iOS Simulator,name=iPad Pro 12.9 shots'` — blocked by missing iOS simulator runtime (CoreSimulator has no runtimes; opening Xcode.app should trigger the download). All 22 AppCore + 7 DesignSystem tests pass via `swift test`.


> `linear_project_id: skip` keeps Linear sync inert — change it if you want Linear tracking.
