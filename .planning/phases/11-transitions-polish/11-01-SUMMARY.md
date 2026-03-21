---
phase: 11-transitions-polish
plan: "01"
subsystem: map-ui
tags: [animation, haptics, spring, mapbottomsheet, mapviewmodel]
dependency_graph:
  requires: []
  provides: [drag-progress-morph, unified-sheet-spring, haptic-on-snap]
  affects: [MapBottomSheet, MapViewModel]
tech_stack:
  added: []
  patterns: [drag-progress-interpolation, unified-spring-constant, UIImpactFeedbackGenerator]
key_files:
  created: []
  modified:
    - Travel app/Views/Map/MapBottomSheet.swift
    - Travel app/Views/Map/MapViewModel.swift
decisions:
  - Used dual-layer ZStack with progress-driven opacity instead of if/else branching for smoother drag tracking
  - Scoped .animation modifier to value: detent (not isPeek) so programmatic snaps also animate correctly
  - static let sheetSpring on MapViewModel (not private) so callers can reference it if needed
metrics:
  duration: 148s
  completed: "2026-03-21"
  tasks_completed: 2
  files_modified: 2
---

# Phase 11 Plan 01: Transitions Polish Summary

Drag-progress background morph with corner radius interpolation, haptic snap feedback, and unified spring constant across all 13 MapViewModel detent animation sites.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Drag-progress morph + haptics in MapBottomSheet | fdb1df2 | MapBottomSheet.swift |
| 2 | Unify spring constant in MapViewModel | eebbe59 | MapViewModel.swift |

## What Was Built

### Task 1 — MapBottomSheet.swift
- Added `dragProgress(in:)` function: computes 0→1 blend ratio between peek height (56pt) and half height (40% screen)
- Replaced the binary `if isPeek { ... } else { ... }` background with a ZStack dual-layer approach:
  - Peek blur pill layer: `opacity(1 - progress)` — fades out as user drags up
  - Expanded opaque layer: `opacity(progress)` — fades in with bottom corner radii interpolating `22 * (1 - progress)` → 0
- `UIImpactFeedbackGenerator(style: .light).impactOccurred()` added in `dragGesture.onEnded` before `withAnimation`
- `.animation` modifier changed from `.easeInOut(duration: 0.15)` to `.spring(response: 0.35, dampingFraction: 0.85)` triggered on `value: detent`

### Task 2 — MapViewModel.swift
- Added `static let sheetSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)`
- Replaced all 13 `withAnimation(.spring(response: 0.3))` call sites with `withAnimation(Self.sheetSpring)`
- Covered functions: `onPlaceSelected` (2x), `selectSearchResult`, `selectAIResult`, `clearSelection`, `dismissSearch`, `performMapSearch`, `performCategorySearch`, `calculateDirectionRoute`, `calculateRouteToSearchedItem`, `clearRoute`, `startNavigation`, `stopNavigation`
- Camera animations (`.easeInOut`) intentionally left unchanged

## Verification

- `grep -c "spring(response: 0.3)" MapViewModel.swift` → 0 (all replaced)
- `grep -c "sheetSpring" MapViewModel.swift` → 14 (1 definition + 13 usages)
- `grep -c "dragProgress" MapBottomSheet.swift` → 2 (definition + usage)
- `grep -c "impactOccurred" MapBottomSheet.swift` → 1
- Build: `** BUILD SUCCEEDED **`

## Deviations from Plan

None — plan executed exactly as written.

## Notes for Physical Device Verification

TRAN-02, TRAN-03, TRAN-04 require physical iPhone testing (Simulator does not render `.ultraThinMaterial` over map tiles):
- Drag background opacity tracks finger smoothly over map tiles
- Bottom corner radii interpolate from 22pt → 0pt during drag
- No jank on `UnevenRoundedRectangle` parameter change during spring snap

## Self-Check: PASSED

Files exist:
- FOUND: Travel app/Views/Map/MapBottomSheet.swift
- FOUND: Travel app/Views/Map/MapViewModel.swift

Commits exist:
- FOUND: fdb1df2 (Task 1)
- FOUND: eebbe59 (Task 2)
