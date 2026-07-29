---
project: Callback
linear_project_id: skip
---

# Callback — iOS interview-prep app

Native iPhone app (iOS 18+) to prepare for iOS developer interviews. Local-first,
no accounts, no network. Modern MV + `@Observable` + SwiftData. Two local SPM packages
(`DesignSystem`, `AppCore`) + app target, wired via XcodeGen.

## Status: Phase 1 complete — pushed to GitHub

- **Repo:** https://github.com/chiliec/Callback (public, `main`)
- **Spec:** `~/Develop/Pet/Journal/Projects/Callback/specs/2026-07-29-callback-design.md`
- **Roadmap:** `~/Develop/Pet/Journal/Projects/Callback/plans/2026-07-29-callback-roadmap.md`
- **Phase 1 plan (executed):** `~/Develop/Pet/Journal/Projects/Callback/plans/2026-07-29-callback-phase1-foundations.md`
- **Design handoff (reference):** `design_handoff_callback_ios/` (open `Interview Prep iOS.dc.html`; README has all tokens/screens).

## Key decisions

- Goal: portfolio showpiece **and** real study tool (equal weight).
- iPhone-first; iPad deferred. iOS 18 minimum.
- Content: hand-authored curated seed — **Core 6 topics deep** (Swift, Memory,
  Concurrency, SwiftUI, UIKit, Behavioral).
- Behavioral questions use a `rubric` (no single correct answer).
- Readiness = coverage-aware weighted mean of topic masteries; mastery = recency-weighted
  accuracy. All in a tested `ScoringEngine`.

## What's built (Phase 1)

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

**App target:**
- `CallbackApp` — injects `ModelContainer`, seeds content on first launch via `bootstrap()`
- `RootView` — temporary topics list with `@Query(sort: \Topic.order)` and `IconTile`; replaced in Phase 2

## Known carry-forward items (for Phase 2)

- `weeklyActivity: [Int]` in UserProfile stored as Transformable — no SQL predicates on it
- `ContentLoader.seed()` relies on implicit SwiftData cascade-insert for Lesson/Option/CodeSnippet (works; make explicit)
- `Session.score` uses default IEEE 754 rounding; consider `.toNearestOrAwayFromZero`
- `DSCode.functionDecl` defined but no matching `SyntaxTokenKind` — dead token
- `SyntaxTokenKind.call` never produced by tokenizer — dead enum case
- `OptionRow` border-width via Color equality comparison — works but fragile pattern
- Only available simulator is `iPad Pro 12.9 shots` (iOS 26.4) — iPhone 16 not installed

## Next session

Write and execute **Phase 2 (Core loop skeleton)** plan just-in-time per the roadmap.
Start by reading `~/Develop/Pet/Journal/Projects/Callback/plans/2026-07-29-callback-roadmap.md`
to draft the Phase 2 plan before implementing.

> `linear_project_id: skip` keeps Linear sync inert — change it if you want Linear tracking.
