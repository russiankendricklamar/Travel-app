---
phase: 03-route-selection
plan: "01"
subsystem: routing-data-layer
tags: [routing, multi-route, alternatives, edge-function, swift]
dependency_graph:
  requires: []
  provides: [multi-route-data-flow, alternativeRoutes-state]
  affects: [MapViewModel, RoutingService, api-proxy]
tech_stack:
  added: []
  patterns: [array-return-type-upgrade, cache-first-array-wrap]
key_files:
  created: []
  modified:
    - supabase/functions/api-proxy/index.ts
    - Travel app/Services/RoutingService.swift
    - Travel app/Views/Map/MapViewModel.swift
decisions:
  - "calculateRoute returns [RouteResult] not Optional — callers use results.first pattern for backward compat with activeRoute"
  - "Cache stores only first (fastest) route — cache hit returns [cached] as single-element array"
  - "Transit path stays RouteResult? internally (calculateGoogleTransitRoute), calculateRoute wraps in array"
  - "rerouteNavigation clears alternativeRoutes to prevent stale carousel during active navigation"
metrics:
  duration: "3 minutes"
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_modified: 3
---

# Phase 3 Plan 01: Multi-Route Data Layer Summary

**One-liner:** RoutingService.calculateRoute now returns [RouteResult] with up to 3 alternatives from Google Routes API; MapViewModel tracks alternativeRoutes/selectedRouteIndex/selectedRoute for carousel UI consumption.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Edge Function + RoutingService multi-route return | 6264893 | supabase/functions/api-proxy/index.ts, RoutingService.swift |
| 2 | MapViewModel state extension + caller updates | 4fd9392 | MapViewModel.swift |

## What Was Built

### Edge Function (api-proxy/index.ts)
- `computeAlternativeRoutes: false` changed to `true` in `handleGoogleRoutes` body
- Added `"routes.staticDuration"` to fieldMask for traffic duration comparison at route level

### RoutingService.swift
- `calculateRoute(from:to:mode:)` return type changed from `RouteResult?` to `[RouteResult]`
- Cache hit returns `[cached]` (single-element array) for backward compatibility
- In-flight dedup guard returns `[]` instead of `nil`
- Transit path wraps `googleResult` in `[googleResult]` and `aiResult` in `[aiResult]`
- `calculateRoutesAPIRoute` return type changed to `[RouteResult]`
- Multi-route parsing: `routes.prefix(3).map { parseRoutesAPIResponse($0, mode:) }`
- Cache stores `results[0]` (fastest) only; returns full results array to caller

### MapViewModel.swift
New properties added to routing section:
- `var alternativeRoutes: [RouteResult] = []`
- `var selectedRouteIndex: Int = 0`
- `var selectedRoute: RouteResult?` computed property with bounds check

All callers updated:
- `calculateDirectionRoute`: uses `results`/`firstRoute` pattern; sets `alternativeRoutes = results`, `selectedRouteIndex = 0`, `activeRoute = firstRoute`
- `calculateRouteToSearchedItem`: same pattern
- `rerouteNavigation`: uses `results.first`, clears `alternativeRoutes = []` and `selectedRouteIndex = 0` (no carousel during active navigation)
- `clearRoute`, `stopNavigation`, `onPlaceSelected`, `clearSelection`, `dismissDetail`: all reset `alternativeRoutes = []` and `selectedRouteIndex = 0`

## Decisions Made

1. **Cache strategy:** Cache stores only `results[0]` (fastest route). Cache hit returns single-element array. This avoids storing 3 routes per cache key and keeps existing cache behavior.
2. **Transit internal type unchanged:** `calculateGoogleTransitRoute` keeps `RouteResult?` return — it's private and called only from `calculateRoute` which wraps the result.
3. **activeRoute stays in sync:** On route calculation, `activeRoute = firstRoute`. On carousel selection (Plan 02), `activeRoute` will be updated to `selectedRoute`. Navigation engine continues to consume `activeRoute` without changes.
4. **rerouteNavigation clears alternatives:** During active navigation reroute, alternatives are cleared to prevent showing stale carousel. Navigation mode has no carousel UI.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `supabase/functions/api-proxy/index.ts` contains `computeAlternativeRoutes: true`
- [x] `supabase/functions/api-proxy/index.ts` fieldMask contains `"routes.staticDuration"`
- [x] `RoutingService.swift` `calculateRoute` returns `async -> [RouteResult]`
- [x] `RoutingService.swift` `calculateRoutesAPIRoute` returns `async -> [RouteResult]`
- [x] `RoutingService.swift` contains `routes.prefix(3).map`
- [x] `RoutingService.swift` cache check returns `[cached]`
- [x] `RoutingService.swift` in-flight guard returns `[]`
- [x] `MapViewModel.swift` contains `var alternativeRoutes: [RouteResult] = []`
- [x] `MapViewModel.swift` contains `var selectedRouteIndex: Int = 0`
- [x] `MapViewModel.swift` contains `var selectedRoute: RouteResult?` computed
- [x] Build succeeds with zero errors

## Self-Check: PASSED
