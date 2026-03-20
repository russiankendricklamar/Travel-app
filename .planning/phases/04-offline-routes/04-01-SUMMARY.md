---
phase: 04-offline-routes
plan: 01
subsystem: database
tags: [swiftdata, routing, offline, cache, coredata, swift]

# Dependency graph
requires:
  - phase: 03-route-alternatives
    provides: RouteResult struct, TransportMode enum, RoutingService.calculateRoute(from:to:mode:)
  - phase: 01-navigation-engine
    provides: NavigationStep struct, TransitStep struct
provides:
  - CachedRoute @Model with JSON-encoded polyline + navigation steps (SwiftData persistence)
  - RoutingCacheService L1 in-memory + L2 SwiftData two-tier cache
  - RoutingService.calculateRoute(fromPlace:toPlace:mode:tripID:context:) offline-aware overload
affects:
  - 04-02 (offline pre-cache UI will call RoutingCacheService.store and isDayCached)
  - 04-03 (offline navigation will rely on cached routes returned by the new overload)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "L1 (in-memory dict) + L2 (SwiftData FetchDescriptor) two-tier cache with TTL"
    - "Codable DTO structs (CoordDTO, NavigationStepDTO, TransitStepDTO) to serialize non-Codable CoreLocation/domain types"
    - "Upsert pattern: delete existing L2 entry before insert to maintain unique key semantics"

key-files:
  created:
    - Travel app/Models/CachedRoute.swift
    - Travel app/Services/RoutingCacheService.swift
  modified:
    - Travel app/Services/RoutingService.swift
    - Travel app/Travel_appApp.swift

key-decisions:
  - "CachedRoute uses JSON-encoded Data fields (not @Attribute(.externalStorage)) because route data is small and must be queryable by predicate"
  - "RoutingCacheService is @MainActor @Observable singleton matching OfflineCacheManager pattern"
  - "Online path always uses API and stores to cache; offline path reads cache only — never writes (matches CONTEXT.md decision)"
  - "calculateRoute(fromPlace:) is a new overload, not a replacement — coordinate-based method untouched for GPS-origin routes"
  - "isDayCached checks walking + automobile pairs for all ordered place pairs (not just adjacent), matching UI-SPEC badge semantics"

patterns-established:
  - "DTO serialization: domain structs -> Codable DTO -> Data stored in @Model field; reverse on read"
  - "Cache key format: {originUUID}_{destUUID}_{mode.rawValue} used consistently across L1 dict and isDayCached string matching"

requirements-completed: [OFFL-01, OFFL-02]

# Metrics
duration: 3min
completed: 2026-03-20
---

# Phase 4 Plan 1: CachedRoute Model + RoutingCacheService Summary

**CachedRoute SwiftData model with JSON-encoded polylines and two-tier RoutingCacheService (L1 dict + L2 SwiftData), with RoutingService offline-transparent Place-UUID overload**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-20T15:01:31Z
- **Completed:** 2026-03-20T15:04:41Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- CachedRoute @Model persists route data (polyline + nav steps + transit steps) as JSON-encoded Data fields across app restarts
- RoutingCacheService provides L1 in-memory session cache + L2 SwiftData 7-day TTL persistence with lookup, store, isDayCached, clearAll, clearForTrip
- RoutingService.calculateRoute(fromPlace:toPlace:mode:tripID:context:) returns cached routes when offline and auto-stores when online
- CachedRoute registered in SwiftData ModelContainer alongside existing models

## Task Commits

1. **Task 1: CachedRoute @Model + DTO serialization + RoutingCacheService** - `aae1c8a` (feat)
2. **Task 2: RoutingService offline Place-UUID overload** - `63103d8` (feat)

## Files Created/Modified
- `Travel app/Models/CachedRoute.swift` - @Model with CoordDTO/NavigationStepDTO/TransitStepDTO, toRouteResult(), from() factory, 7-day TTL
- `Travel app/Services/RoutingCacheService.swift` - @MainActor @Observable singleton, L1+L2 cache, isDayCached for UI badges
- `Travel app/Services/RoutingService.swift` - Added calculateRoute(fromPlace:toPlace:mode:tripID:context:) overload + import SwiftData
- `Travel app/Travel_appApp.swift` - Added CachedRoute.self to ModelContainer

## Decisions Made
- JSON-encoded Data fields chosen over @Attribute(.externalStorage) because route sizes are small (< 10KB) and we need predicate-based queries on origin/destination UUIDs
- Online path always calls API and updates cache (cache is never read when online), matching CONTEXT.md architecture decision
- New overload pattern preserves backward compatibility — all existing callers of coordinate-based calculateRoute are unaffected

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- iPhone 16 Pro Max simulator not available (OS 26.3.1 only ships with iPhone 17 Pro Max); used iPhone 17 Pro Max — build succeeded

## Next Phase Readiness
- CachedRoute model and RoutingCacheService API are ready for 04-02 (pre-cache UI will call store + isDayCached)
- RoutingService offline overload ready for 04-03 (navigation will call calculateRoute(fromPlace:) for cache-aware routing)
- No blockers

---
*Phase: 04-offline-routes*
*Completed: 2026-03-20*
