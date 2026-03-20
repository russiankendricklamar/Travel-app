---
phase: 04-offline-routes
plan: 02
subsystem: ui
tags: [swiftui, swiftdata, offline, routing, mapkit, taskgroup]

requires:
  - phase: 04-offline-routes-plan-01
    provides: RoutingCacheService with store/isDayCached, CachedRoute @Model, RoutingService.calculateRoute

provides:
  - OfflineCacheManager.preCacheDay: parallel N^2 pair fetching in walking+automobile via withTaskGroup
  - OfflinePrecacheButton: 3-state component (idle/loading/done) with progress ring
  - TripMapView: precache button and day-cached badge in idle mode, background refresh on appear

affects: [04-offline-routes-plan-03]

tech-stack:
  added: []
  patterns:
    - "withTaskGroup for parallel route pre-fetching with collected results stored post-group"
    - "3-state PrecacheState enum driving View switch for idle/loading/done UI"
    - "Circle().trim progress ring with .easeInOut(0.3) animation matching PackingListView pattern"

key-files:
  created:
    - Travel app/Services/OfflineCacheManager.swift (preCacheDay method added)
    - Travel app/Views/Shared/OfflinePrecacheButton.swift
  modified:
    - Travel app/Views/Map/TripMapView.swift

key-decisions:
  - "preCacheDay captures Place coordinate + UUID before entering task group (avoids MainActor isolation warning from accessing Place properties inside nonisolated task)"
  - "TripMapView shows checkmark.icloud.fill badge when isDayCached returns true, otherwise shows OfflinePrecacheButton — no separate state needed"
  - "backgroundRefreshIfNeeded skips silently if isDayCached returns true (TTL still valid), only runs preCacheDay when stale"
  - "Task 2 TripMapView changes were committed as part of commit 75cbf1f (04-03) since both plans modified the same file in the same session"

patterns-established:
  - "Parallel pre-cache with withTaskGroup: collect results into array, then store all on @MainActor after group completes"
  - "Button state machine: PrecacheState enum + switch in body, onAppear checks existing cache status"

requirements-completed: [OFFL-03]

duration: 3min
completed: 2026-03-20
---

# Phase 04 Plan 02: Pre-cache Route Button Summary

**Parallel N^2 route pre-caching via withTaskGroup, 3-state OfflinePrecacheButton with progress ring, and TripMapView idle-mode integration with day-cached badge**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-20T15:13:00Z
- **Completed:** 2026-03-20T15:16:38Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added `preCacheDay` to `OfflineCacheManager`: fetches all N^2 ordered place pairs in walking+automobile in parallel via `withTaskGroup`, then stores results in `RoutingCacheService` on `@MainActor`
- Created `OfflinePrecacheButton` with idle/loading/done state machine, 44pt progress ring (6pt stroke, easeInOut), sakuraPink idle state, bambooGreen done state, offline-disabled with subtitle
- Integrated button and day-cached badge into `TripMapView` idle mode (trailing-aligned above search pill), with silent background refresh on appear for stale caches

## Task Commits

1. **Task 1: preCacheDay + OfflinePrecacheButton** - `01218e4` (feat)
2. **Task 2: TripMapView integration** - `75cbf1f` (feat, bundled with 04-03 changes)

## Files Created/Modified
- `Travel app/Services/OfflineCacheManager.swift` - Added preCacheDay with withTaskGroup parallel fetching
- `Travel app/Views/Shared/OfflinePrecacheButton.swift` - New 3-state precache button component
- `Travel app/Views/Map/TripMapView.swift` - modelContext, currentDayForPrecache, button/badge in idle mode, backgroundRefreshIfNeeded

## Decisions Made
- Captured `origin.coordinate` and `origin.id` as local constants before entering `group.addTask` closure to avoid Swift 6 MainActor isolation warnings on `Place` property access inside nonisolated task
- TripMapView shows badge (`checkmark.icloud.fill` + bambooGreen) when `isDayCached` returns true, otherwise renders `OfflinePrecacheButton` — button handles its own state on appear so no redundant state needed in the map view
- `backgroundRefreshIfNeeded` is intentionally silent (no UI feedback) and only triggers when online + stale; it guards against re-fetching already-valid caches

## Deviations from Plan

None - plan executed exactly as written. The only note: TripMapView modifications were committed together with plan 04-03 changes in commit `75cbf1f` since both plans modified the same file in the same session.

## Issues Encountered
- None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `preCacheDay` is fully callable from any view that has `modelContext`
- `OfflinePrecacheButton` is self-contained and reusable (e.g., could be surfaced in SettingsView or DayDetailView)
- TripMapView integration complete — users can tap "ПОДГОТОВИТЬ ОФЛАЙН" in idle map mode to pre-cache routes for offline use

---
*Phase: 04-offline-routes*
*Completed: 2026-03-20*
