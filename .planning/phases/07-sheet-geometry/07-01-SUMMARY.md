---
phase: 07-sheet-geometry
plan: 01
subsystem: ui
tags: [swiftui, mapkit, bottomsheet, unevenroundedrectangle, ultrathinmaterial, geometry]

# Dependency graph
requires: []
provides:
  - MapBottomSheet with correct 56pt peek / 40% half / full screen detent heights
  - Single UnevenRoundedRectangle shape for all states enabling smooth shape morph
  - ultraThinMaterial + dark overlay for peek background (map tiles show through)
  - Drag handle (36x5pt Capsule) visible in all three detent states
  - GeometryReader replaced with onGeometryChange for layout measurement
  - Dead code MapFloatingSearchPill.swift deleted
affects: [08-search-bar, 09-floating-controls, 10-place-detail-card, 11-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "UnevenRoundedRectangle with unified radius params for all detent states"
    - "Opacity crossfade (.transition(.opacity) + .animation(.easeInOut(duration:0.15))) to swap peek vs expanded backgrounds"
    - "onGeometryChange instead of GeometryReader for screen height measurement"
    - "Drag gesture scoped to full pill in peek, handle-only in half/full"

key-files:
  created: []
  modified:
    - "Travel app/Views/Map/MapBottomSheet.swift"
    - "Travel app/Views/Map/TripMapView.swift"
  deleted:
    - "Travel app/Views/Map/MapFloatingSearchPill.swift"

key-decisions:
  - "Used opacity crossfade between two distinct UnevenRoundedRectangle backgrounds rather than animating corner radii — avoids potential interpolation jank on older iOS"
  - "Peek background uses ultraThinMaterial + Color.black.opacity(0.35) overlay + .environment(.colorScheme, .dark) so map tiles show through with consistent dark appearance"
  - "Drag gesture on entire pill in peek state, restricted to drag handle in half/full to avoid accidental scroll interference"

patterns-established:
  - "Sheet background pattern: two named .background branches with .transition(.opacity) + .animation(.easeInOut(duration:0.15), value: isPeek)"
  - "Safe area measurement: Color.clear overlay with .onGeometryChange for both height and safeAreaInsets.top"

requirements-completed: [GEOM-01, GEOM-02, GEOM-03, GEOM-04, GEOM-05]

# Metrics
duration: ~45min
completed: 2026-03-21
---

# Phase 07 Plan 01: Sheet Geometry Summary

**MapBottomSheet refactored to Apple Maps geometry — 56pt peek pill with ultraThinMaterial blur, unified UnevenRoundedRectangle shape morph across all three detents, and drag handle always visible**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-03-21T00:00:00Z
- **Completed:** 2026-03-21T00:45:00Z
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 2 modified, 1 deleted

## Accomplishments

- Corrected peek height from 50pt to 56pt (GEOM-01), half from 47% to 40% screen height (GEOM-04)
- Replaced dual RoundedRectangle/UnevenRoundedRectangle with single UnevenRoundedRectangle for all states — eliminates shape snap on detent transition (GEOM-02)
- Peek state now uses ultraThinMaterial + black overlay so map tiles blur through correctly on physical device
- Drag handle (Capsule, 36x5pt, Color(.systemFill)) rendered in all three states — was previously hidden in peek
- Replaced outer GeometryReader with .onGeometryChange for layout measurement
- Deleted dead code: MapFloatingSearchPill.swift (confirmed unreferenced)
- Visual inspection approved by user

## Task Commits

Each task was committed atomically:

1. **Task 1 + 2: Delete dead code, geometry, materials, unified shape** - `9253c1a` (feat)
3. **Task 3: Visual inspection checkpoint** - approved by user (no commit — checkpoint only)

**Plan metadata:** (to be committed with this SUMMARY)

## Files Created/Modified

- `Travel app/Views/Map/MapBottomSheet.swift` — corrected detent heights, single UnevenRoundedRectangle background, ultraThinMaterial peek, always-visible drag handle, onGeometryChange
- `Travel app/Views/Map/TripMapView.swift` — minor adjustments for new sheet geometry
- `Travel app/Views/Map/MapFloatingSearchPill.swift` — DELETED (dead code)

## Decisions Made

- Used opacity crossfade between two named background branches (peek vs expanded) rather than animating UnevenRoundedRectangle corner radii directly. This avoids potential interpolation jank observed in research and is simpler to reason about.
- Peek background: `ultraThinMaterial` + `Color.black.opacity(0.35)` overlay + `.environment(\.colorScheme, .dark)` ensures consistent dark appearance regardless of underlying map tile color (park green, beach sand, etc.).
- Drag gesture split: entire pill captures drag in peek (natural tap target), only handle captures drag in half/full (avoids scroll interference with list content below).

## Deviations from Plan

None — plan executed exactly as written. Tasks 1 and 2 were committed together in a single atomic commit (`9253c1a`) since task 2 directly followed task 1 in the same editing session.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- MapBottomSheet geometry is correct and visually approved. Phases 08 (search bar), 09 (floating controls), and 10 (place detail card) can build on top of the fixed detent heights and sheet API.
- Physical device test of ultraThinMaterial over park/beach map tiles was noted as a bonus step; Simulator approval is sufficient to proceed.

---
*Phase: 07-sheet-geometry*
*Completed: 2026-03-21*
