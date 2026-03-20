---
phase: 02-navigation-ui
plan: 01
subsystem: ui
tags: [swiftui, mapkit, navigation, glassmorphism, mvvm]

# Dependency graph
requires:
  - phase: 01-navigation-engine
    provides: NavigationEngine, NavigationStep, RoutingService.formatDistance/formatDuration

provides:
  - NavigationHUDView: floating maneuver card with urgency state and iconForInstruction mapper
  - MapRecenterButton: capsule button for manual pan recovery during navigation
  - NavigationSheetContent: peek/expanded sheet body with step list and stop button
  - MapViewModel.isUrgent, isOffNavCenter: HUD urgency and off-center state properties
  - MapViewModel.recenterNavigation(): camera re-center method
  - MapViewModel.tripContextLabel, etaString: computed nav context properties
  - MapSheetContent.navigation case with camera transitions in start/stop
  - MapRouteContent "НАЧАТЬ НАВИГАЦИЮ" button

affects: [02-navigation-ui plan-02, TripMapView wiring phase]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Urgency hysteresis pattern: activate < 50m threshold, deactivate > 65m (prevents flicker)
    - iconForInstruction static mapper on NavigationHUDView reused by NavigationSheetContent
    - Camera heading lock via .userLocation(followsHeading: true) on navigation start

key-files:
  created:
    - Travel app/Views/Map/NavigationHUDView.swift
    - Travel app/Views/Map/MapRecenterButton.swift
    - Travel app/Views/Map/NavigationSheetContent.swift
  modified:
    - Travel app/Views/Map/MapViewModel.swift
    - Travel app/Views/Map/MapRouteContent.swift
    - Travel app/Views/Map/TripMapView.swift

key-decisions:
  - "iconForInstruction placed as static func on NavigationHUDView so NavigationSheetContent can reuse it without duplication"
  - "TripMapView .navigation case initially set to MapRouteContent placeholder (Rule 3 fix), then updated to NavigationSheetContent in same task commit"
  - "stopNavigation() restores camera to .automatic and switches sheet to .routeInfo/.half for smooth UX after navigation ends"

patterns-established:
  - "Navigation urgency hysteresis: < 50m activates, > 65m deactivates — prevents flickering at threshold boundary"
  - "Static icon mapper as part of the HUD component, shared via NavigationHUDView.iconForInstruction(_:) call site"

requirements-completed: [UI-01, UI-04, NAV-06]

# Metrics
duration: 5min
completed: 2026-03-20
---

# Phase 02 Plan 01: Navigation UI Components Summary

**SwiftUI navigation HUD + recenter button + sheet content + start button wired to MapViewModel with urgency hysteresis and camera heading lock**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-20T08:21:45Z
- **Completed:** 2026-03-20T08:26:20Z
- **Tasks:** 2
- **Files modified:** 6 (3 created, 3 modified)

## Accomplishments

- Three new SwiftUI view files created: NavigationHUDView (glassmorphism HUD with urgency state), MapRecenterButton (sakuraPink capsule), NavigationSheetContent (peek/expanded layouts)
- MapViewModel extended with isUrgent/isOffNavCenter, recenterNavigation(), tripContextLabel, etaString, and .navigation sheet case with camera heading lock transitions
- MapRouteContent "НАЧАТЬ НАВИГАЦИЮ" solid sakuraPink button added at bottom

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend MapViewModel with navigation UI state and camera transitions** - `29d6f2b` (feat)
2. **Task 2: Create NavigationHUDView, MapRecenterButton, NavigationSheetContent, start button** - `655e969` (feat)

**Plan metadata:** (docs commit to follow)

## Files Created/Modified

- `Travel app/Views/Map/NavigationHUDView.swift` - Floating HUD card with direction icon, instruction, distance, urgency state, dismiss button
- `Travel app/Views/Map/MapRecenterButton.swift` - Capsule button for map re-centering during navigation
- `Travel app/Views/Map/NavigationSheetContent.swift` - Sheet body with peek row and expanded step list
- `Travel app/Views/Map/MapViewModel.swift` - isUrgent, isOffNavCenter, recenterNavigation(), tripContextLabel, etaString, .navigation case, camera transitions
- `Travel app/Views/Map/MapRouteContent.swift` - "НАЧАТЬ НАВИГАЦИЮ" button at bottom of route info
- `Travel app/Views/Map/TripMapView.swift` - .navigation case in sheetBody switch wired to NavigationSheetContent

## Decisions Made

- `iconForInstruction` is a `static func` on `NavigationHUDView` so `NavigationSheetContent`'s `StepRow` can call it without duplication or a separate utility file.
- TripMapView exhaustive switch needed a `.navigation` case immediately after adding it to the enum — used `MapRouteContent` as placeholder, then updated to `NavigationSheetContent` within the same task commit.
- `stopNavigation()` now restores sheet to `.routeInfo/.half` so the user sees their route summary after stopping navigation (clean UX flow).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added .navigation case to TripMapView exhaustive switch**
- **Found during:** Task 1 build verification
- **Issue:** Adding `.navigation` to `MapSheetContent` enum caused "switch must be exhaustive" error in `TripMapView.sheetBody`
- **Fix:** Added `.navigation: MapRouteContent(vm: vm)` placeholder to TripMapView, then updated to `NavigationSheetContent(vm: vm)` at end of Task 2
- **Files modified:** Travel app/Views/Map/TripMapView.swift
- **Verification:** Build succeeded after fix
- **Committed in:** `29d6f2b` (part of Task 1 commit), updated in `655e969`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Required fix — new enum case always requires exhaustive switch update. No scope creep.

## Issues Encountered

None beyond the exhaustive switch deviation documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All navigation UI components exist and compile clean
- NavigationHUDView and MapRecenterButton ready to be added as overlay layers in TripMapView (Plan 02)
- NavigationSheetContent ready to replace MapRouteContent for the .navigation sheet case (already wired)
- MapViewModel has full UI state surface for Plan 02 to wire gesture recognizers (isOffNavCenter via drag gesture)

---
*Phase: 02-navigation-ui*
*Completed: 2026-03-20*

## Self-Check: PASSED

- NavigationHUDView.swift: FOUND
- MapRecenterButton.swift: FOUND
- NavigationSheetContent.swift: FOUND
- Commit 29d6f2b (Task 1): FOUND
- Commit 655e969 (Task 2): FOUND
