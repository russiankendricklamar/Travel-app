---
phase: 05
plan: 01
subsystem: offline-navigation
tags: [bugfix, offline, routing, navigation-steps]
requires: [04-offline-routes]
provides: [OFFL-02, OFFL-04]
affects: [MapRouteContent, RoutingService]
tech-stack-added: []
tech-stack-patterns: [RouteResult-immutable-rebuild]
key-files-created: []
key-files-modified:
  - "Travel app/Views/Map/MapRouteContent.swift"
  - "Travel app/Services/RoutingService.swift"
key-decisions:
  - "offlineNoCacheMessage moved to top-level else-if branch — only reachable when vm.activeRoute == nil AND offline"
  - "RouteResult rebuilt immutably with navigationSteps before caching — mirrors OfflineCacheManager.preCacheDay pattern"
metrics:
  duration: 4m
  completed_date: "2026-03-20T15:39:02Z"
  tasks_completed: 2
  files_modified: 2
---

# Phase 05 Plan 01: Fix offline route integration bugs Summary

Fixed two integration bugs found during v1.0 milestone audit: unreachable offline UI message and empty navigationSteps in auto-cached routes.

## What Was Built

**Bug 1 — offlineNoCacheMessage unreachable (OFFL-04):**
The message block was inside `if let route = vm.activeRoute { ... }` with the condition `vm.activeRoute == nil`, which is always false inside that guard. Restructured the `body` to use a top-level `else if !OfflineCacheManager.shared.isOnline` branch so the message renders correctly when offline with no cached route.

**Bug 2 — empty navigationSteps in auto-cached routes (OFFL-02):**
`calculateRoute(fromPlace:toPlace:mode:tripID:context:)` was calling `RoutingCacheService.shared.store()` with the raw API result which has empty `navigationSteps` (parseRoutesAPIResponse never populates them). Added a `fetchNavigationSteps` call between the API response and the store call, then immutably rebuilt the `RouteResult` with steps attached before caching. Caller receives the enriched result. Pattern matches `OfflineCacheManager.preCacheDay`.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Fix offlineNoCacheMessage unreachable dead code | a2191fd | MapRouteContent.swift |
| 2 | Store navigationSteps in auto-cached routes | dc65bab | RoutingService.swift |

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- `Travel app/Views/Map/MapRouteContent.swift` — modified, contains `else if !OfflineCacheManager.shared.isOnline` at top level
- `Travel app/Services/RoutingService.swift` — modified, calls `fetchNavigationSteps` before `store()`
- Commits a2191fd and dc65bab verified in git log
