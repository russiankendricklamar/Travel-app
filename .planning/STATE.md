---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Apple Maps UI Parity
status: in_progress
stopped_at: Roadmap created, ready to plan Phase 7
last_updated: "2026-03-21"
last_activity: 2026-03-21
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-21)

**Core value:** Путешественник может построить маршрут между любыми точками, получить пошаговую навигацию с голосом на любом транспорте, и всё это работает офлайн в чужой стране без интернета.
**Current focus:** v1.1 Apple Maps UI Parity — Phase 7: Sheet Geometry

## Current Position

Phase: 7 of 11 (Sheet Geometry) — first v1.1 phase
Plan: — (not yet planned)
Status: Ready to plan
Last activity: 2026-03-21 — Roadmap created for v1.1 (5 phases, 28 requirements)

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 12 (v1.0)
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| v1.0 (Phases 1-6) | 12 | — | — |

*Updated after each plan completion*

## Accumulated Context

### Decisions

- Research confirmed: do NOT use `.presentationDetents` — content-height bugs on iOS 16-18
- Research confirmed: use single `UnevenRoundedRectangle` for all detent states to enable shape morph
- Research confirmed: spring params `response: 0.35, dampingFraction: 0.85` already correct — do not change
- Research confirmed: focus delay 150ms already correct — do not change
- Phase 9 can run parallel to Phase 8 (no dependency between search bar and floating controls)
- Must test `.ultraThinMaterial` on physical device — Simulator does not expose opacity issues over map tiles

### Blockers/Concerns

- Phase 11 requires physical device testing (`.ultraThinMaterial` over park/beach map tiles)
- Shape morph complexity: if `UnevenRoundedRectangle` parameter interpolation produces jank, use opacity crossfade fallback

## Session Continuity

Last session: 2026-03-21
Stopped at: Roadmap v1.1 created — 5 phases (7-11), 28 requirements mapped
Resume file: None
