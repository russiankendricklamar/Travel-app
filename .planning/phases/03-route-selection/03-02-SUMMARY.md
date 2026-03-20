---
phase: 03-route-selection
plan: 02
subsystem: ui
tags: [swiftui, glassmorphism, maproutes, carousel, skeletonloading]

# Dependency graph
requires:
  - phase: 03-01
    provides: "MapViewModel.alternativeRoutes + selectedRouteIndex + RouteResult struct with multi-route data"
provides:
  - RouteAlternativeCard component (glassmorphism card, badge enum, shimmer skeleton, transit transfer labels)
  - routeAlternativesCarousel inserted in MapRouteContent between transport pills and route stats
  - Badge computation logic identifying fastest/shortest routes by min comparison
affects: [03-03-offline, future navigation UI polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "RouteAlternativeCard wraps Button(action:) so card itself is the tap target (no nested gesture conflicts)"
    - "badgeFor(index:) uses min(by:) on both time and distance; fastest badge takes priority when same route wins both"
    - "Russian declension for transfer counts via rem10/rem100 modular arithmetic"
    - "Skeleton shimmer: @State opacity 0.4→1.0 repeatForever(autoreverses:true) easeInOut 1s"

key-files:
  created:
    - "Travel app/Views/Map/RouteAlternativeCard.swift"
  modified:
    - "Travel app/Views/Map/MapRouteContent.swift"

key-decisions:
  - "Card tap sets both vm.selectedRouteIndex and vm.activeRoute wrapped in withAnimation(.easeInOut(0.35)) for smooth polyline transition"
  - "Fastest badge takes priority over shortest when same route wins both metrics (per UI-SPEC)"
  - "Transit mode shows Russian-declined transfer count instead of distance to match domain expectations"
  - "Carousel hidden entirely when alternativeRoutes is empty and not loading (no empty-state placeholder needed)"

patterns-established:
  - "RouteAlternativeCard: glassmorphism 140x88pt card, ultraThinMaterial bg, sakuraPink stroke when selected"
  - "Accessibility: .accessibilityLabel with full sentence + .accessibilityAddTraits(.isSelected) on selected card"

requirements-completed: [ROUTE-01, ROUTE-02, ROUTE-03]

# Metrics
duration: 25min
completed: 2026-03-20
---

# Phase 3 Plan 02: Route Alternatives Carousel Summary

**Glassmorphism route alternatives carousel with fastest/shortest badges, shimmer skeletons, and transit transfer counts wired into MapRouteContent between transport pills and route stats.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-03-20
- **Completed:** 2026-03-20
- **Tasks:** 3 (2 auto + 1 checkpoint:human-verify, approved)
- **Files modified:** 2

## Accomplishments
- RouteAlternativeCard.swift: glassmorphism card (140x88pt, ultraThinMaterial, sakuraPink selected stroke), RouteBadge enum (fastest/shortest), RouteAlternativeCardSkeleton with pulsing shimmer animation, Russian transfer count declension, full accessibility labels
- MapRouteContent.swift: horizontal ScrollView carousel inserted between transport pills and route stats, skeleton loading on isCalculatingRoute, badge computation via min(by:) on time/distance
- Visual checkpoint approved by user — carousel renders correctly in simulator

## Task Commits

Each task was committed atomically:

1. **Task 1: RouteAlternativeCard + skeleton + badge enum** - `e60eb1f` (feat)
2. **Task 2: Wire carousel into MapRouteContent** - `4b94a17` (feat)
3. **Task 3: Visual verification checkpoint** - approved (no code commit — checkpoint only)

## Files Created/Modified
- `Travel app/Views/Map/RouteAlternativeCard.swift` - RouteAlternativeCard view, RouteAlternativeCardSkeleton, RouteBadge enum
- `Travel app/Views/Map/MapRouteContent.swift` - routeAlternativesCarousel + badgeFor(index:) inserted

## Decisions Made
- Card tap sets both `vm.selectedRouteIndex` and `vm.activeRoute` wrapped in `withAnimation(.easeInOut(duration: 0.35))` to ensure smooth polyline transition without separate animation trigger
- Fastest badge takes priority over shortest when the same route wins both metrics — matches UI-SPEC
- Carousel is hidden entirely when `alternativeRoutes` is empty and not loading — avoids empty placeholder clutter

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Route carousel UI is complete; ROUTE-01/02/03 requirements fulfilled
- Phase 03 is now complete (both plans done)
- Phase 04 (offline) can begin — depends only on route engine (03-01) which was completed in the previous plan

---
*Phase: 03-route-selection*
*Completed: 2026-03-20*
