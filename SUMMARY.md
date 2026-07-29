---
project: Callback
linear_project_id: skip
---

# Callback — iOS interview-prep app

Native iPhone app (iOS 18+) to prepare for iOS developer interviews. Local-first,
no accounts, no network. Modern MV + `@Observable` + SwiftData. Two local SPM packages
(`DesignSystem`, `AppCore`) + app target, wired via XcodeGen.

## Status: planned, not yet implemented

- **Spec:** `~/Develop/Pet/Journal/Projects/Callback/specs/2026-07-29-callback-design.md`
- **Roadmap:** `~/Develop/Pet/Journal/Projects/Callback/plans/2026-07-29-callback-roadmap.md`
- **Phase 1 plan (ready to execute):** `~/Develop/Pet/Journal/Projects/Callback/plans/2026-07-29-callback-phase1-foundations.md`
- **Design handoff (reference):** `design_handoff_callback_ios/` (open `Interview Prep iOS.dc.html`; README has all tokens/screens).

## Key decisions

- Goal: portfolio showpiece **and** real study tool (equal weight).
- iPhone-first; iPad deferred. iOS 18 minimum.
- Content: hand-authored curated seed — **Core 6 topics deep** (Swift, Memory,
  Concurrency, SwiftUI, UIKit, Behavioral).
- Behavioral questions use a `rubric` (no single correct answer).
- Readiness = coverage-aware weighted mean of topic masteries; mastery = recency-weighted
  accuracy. All in a tested `ScoringEngine`.

## Next session

Execute **Phase 1 (Foundations)** via `superpowers:subagent-driven-development` in a fresh
session (start in this directory). Write each later phase's plan just-in-time before
starting it (see roadmap).

> `linear_project_id: skip` keeps Linear sync inert — change it if you want Linear tracking.
