---
phase: 08-search-bar-handle
plan: 01
subsystem: ui
tags: [swiftui, maps, search-bar, haptics, animation, apple-maps-parity]

# Dependency graph
requires:
  - phase: 07-sheet-geometry
    provides: MapBottomSheet with correct detents, drag handle dimensions frozen
provides:
  - Restyled MapSearchContent.swift with Apple Maps proportions
  - 17pt icon/font, RoundedRectangle(10) background with 0.5pt white stroke
  - Clear/sparkles mutual exclusion in search field trailing area
  - Haptic on peek tap, peek expands to .half (not .full)
  - Cancel clears query and keeps sheet at .half (does not collapse to peek)
  - Sticky search bar header in full mode with scroll-aware divider
affects: [09-floating-controls, 10-results-cards, 11-map-interaction]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sticky header pattern: search bar outside ScrollView, content in ScrollView for full mode"
    - "Mutual exclusion: clear button (xmark.circle.fill) replaces sparkles when query non-empty"
    - "Peek interaction: expand to .half + haptic + 150ms focus delay (not expand to .full)"
    - "Cancel behavior: clear query + dismiss focus + stay at .half (never call vm.dismissSearch())"
    - "Conditional ScrollView: full mode wraps content, half/peek uses flat VStack"

key-files:
  created: []
  modified:
    - "Travel app/Views/Map/MapSearchContent.swift"

key-decisions:
  - "Search bar background is RoundedRectangle(cornerRadius: 10) not Capsule — consistent with Apple Maps"
  - "Cancel button must NOT call vm.dismissSearch() — that sets sheetDetent = .peek; inline the action instead"
  - "Sparkles button hidden in peek mode (vm.sheetDetent != .peek condition) — D-50/D-51"
  - "onScrollGeometryChange (iOS 18+) used for scroll detection — project targets iOS 26.2, safe"
  - "Both Task 1 and Task 2 committed as a single feat commit (586798e) — tasks were sequential on the same file"

patterns-established:
  - "Sticky header: VStack { searchRow; conditionalDivider; if full { ScrollView { content } } else { content } }"
  - "Scroll detection: .onScrollGeometryChange(for: Bool.self) { geo in geo.contentOffset.y > 2 }"

requirements-completed: [HNDL-01, HNDL-02, HNDL-03, SRCH-01, SRCH-02, SRCH-03, SRCH-04, SRCH-05]

# Metrics
duration: ~30min
completed: 2026-03-21
---

# Phase 8 Plan 01: Search Bar Handle Summary

**Apple Maps-parity search bar: 17pt icon/font, RoundedRectangle(10) with stroke, clear/sparkles mutual exclusion, haptic peek-to-half expansion, cancel stays at half, sticky header with scroll-aware divider in full mode**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-03-21
- **Completed:** 2026-03-21
- **Tasks:** 2 auto tasks + 1 checkpoint (approved)
- **Files modified:** 1

## Accomplishments

- Restyled search field to Apple Maps proportions: magnifyingglass at 17pt .regular, 14pt inner leading padding, 6pt icon-text gap, 17pt placeholder font
- Replaced `Capsule()` background with `RoundedRectangle(cornerRadius: 10)` + `.quaternary.opacity(0.5)` fill + 0.5pt white stroke, hidden in peek mode
- Implemented clear/sparkles mutual exclusion: `xmark.circle.fill` when query non-empty, sparkles toggle when empty and not peek, both hidden in peek
- Fixed peek tap: expands to `.half` (was `.full`) with `UIImpactFeedbackGenerator(.light)` haptic + 150ms focus delay
- Fixed cancel button: clears query, dismisses focus, keeps sheet at `.half` — does NOT call `vm.dismissSearch()` which would collapse to peek
- Added sticky header pattern: search bar + cancel outside ScrollView, scrollable content below; scroll-aware divider appears via `onScrollGeometryChange`

## Task Commits

Both tasks committed together (sequential edits to same file):

1. **Task 1 + Task 2: Restyle search bar + add sticky header** — `586798e` (feat)

## Files Created/Modified

- `/Users/egorgalkin/Travel app/Travel app/Views/Map/MapSearchContent.swift` — Complete restyle: proportions, background, trailing buttons, cancel action, sticky header with scrollable content extraction

## Decisions Made

- `RoundedRectangle(cornerRadius: 10)` not `Capsule()` — Apple Maps uses rounded rectangle for search field
- Cancel must NOT call `vm.dismissSearch()` (that method sets `.peek`); action inlined directly in button
- `onScrollGeometryChange` chosen over `GeometryReader` for scroll detection — cleaner API, project targets iOS 26.2
- Sparkles hidden in peek mode via `vm.sheetDetent != .peek` guard — matches Apple Maps: no secondary controls in collapsed state

## Deviations from Plan

None - plan executed exactly as written. Both tasks completed per spec, build succeeded, user approved visual checkpoint.

## Issues Encountered

None — implementation matched the detailed task spec. Build succeeded on first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 8 complete. MapSearchContent.swift has Apple Maps search bar proportions and interactions.
- Phase 9 (floating controls) can run in parallel — no dependency on search bar internals per STATE.md decision.
- Handle dimensions in MapBottomSheet.swift unchanged (Phase 7 output, frozen): 36x5pt Capsule, systemFill, top:8, bottom:6.

---
*Phase: 08-search-bar-handle*
*Completed: 2026-03-21*
