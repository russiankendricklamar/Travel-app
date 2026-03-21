---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Apple Maps UI Parity
status: unknown
stopped_at: Phase 10 context gathered
last_updated: "2026-03-21T03:34:17.089Z"
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 3
  completed_plans: 3
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-21)

**Core value:** Путешественник может построить маршрут между любыми точками, получить пошаговую навигацию с голосом на любом транспорте, и всё это работает офлайн в чужой стране без интернета.
**Current focus:** Phase 09 — floating-controls

## Current Position

Phase: 10
Plan: Not started

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
| Phase 07-sheet-geometry P01 | 45 | 2 tasks | 3 files |
| Phase 08-search-bar-handle P01 | 30 | 2 tasks | 1 files |
| Phase 09 P01 | 189 | 2 tasks | 3 files |

## Accumulated Context

### Decisions

- Research confirmed: do NOT use `.presentationDetents` — content-height bugs on iOS 16-18
- Research confirmed: use single `UnevenRoundedRectangle` for all detent states to enable shape morph
- Research confirmed: spring params `response: 0.35, dampingFraction: 0.85` already correct — do not change
- Research confirmed: focus delay 150ms already correct — do not change
- Phase 9 can run parallel to Phase 8 (no dependency between search bar and floating controls)
- Must test `.ultraThinMaterial` on physical device — Simulator does not expose opacity issues over map tiles
- [Phase 07-sheet-geometry]: Used opacity crossfade between two UnevenRoundedRectangle backgrounds rather than animating corner radii to avoid interpolation jank
- [Phase 07-sheet-geometry]: Peek background uses ultraThinMaterial + black.opacity(0.35) + dark colorScheme so map tiles show through regardless of terrain color
- [Phase 07-sheet-geometry]: Drag gesture scoped to full pill in peek, handle-only in half/full to avoid scroll interference
- [Phase 08-search-bar-handle]: Search bar background is RoundedRectangle(cornerRadius: 10) not Capsule — consistent with Apple Maps
- [Phase 08-search-bar-handle]: Cancel button must NOT call vm.dismissSearch() — that sets sheetDetent = .peek; action inlined instead
- [Phase 08-search-bar-handle]: Sparkles button hidden in peek mode (vm.sheetDetent != .peek) — no secondary controls in collapsed state
- [Phase 09]: Used @Bindable var vm: MapViewModel (not @ObservedObject) for toggle writes with @Observable pattern
- [Phase 09]: MapCompass moved from .mapControls into FloatingControlsOverlay with namespace scope wiring

### Blockers/Concerns

- Phase 11 requires physical device testing (`.ultraThinMaterial` over park/beach map tiles)
- Shape morph complexity: if `UnevenRoundedRectangle` parameter interpolation produces jank, use opacity crossfade fallback

## Session Continuity

Last session: 2026-03-21T03:34:17.086Z
Stopped at: Phase 10 context gathered
Resume file: .planning/phases/10-sheet-content/10-CONTEXT.md
