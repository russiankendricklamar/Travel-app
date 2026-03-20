---
phase: 01-navigation-engine
plan: "03"
subsystem: navigation-engine
tags: [navigation, core-logic, state-machine, routing]
dependency_graph:
  requires: ["01-01", "01-02"]
  provides: ["02-01", "02-02", "02-03"]
  affects: ["MapViewModel", "LocationManager"]
tech_stack:
  added: []
  patterns: ["@Observable state machine", "weak self capture", "perpendicular segment projection"]
key_files:
  created:
    - "Travel app/Services/NavigationEngine.swift"
  modified:
    - "Travel app/Views/Map/MapViewModel.swift"
decisions:
  - "[weak self] in onLocationUpdate captures self?.navigationEngine (stored property), not [weak engine] on local variable that goes out of scope when startNavigation() returns"
  - "startNavigation() is async to await step fetch inline if background Task hasn't finished — prevents silent no-op when user taps Start immediately after route calculation"
  - "cancelReroute() public method exposes isRerouting reset without violating private(set) access control"
metrics:
  duration: "15 minutes"
  completed: "2026-03-20"
  tasks_completed: 2
  files_modified: 2
---

# Phase 01 Plan 03: NavigationEngine + MapViewModel Integration Summary

**One-liner:** `@Observable` NavigationEngine state machine with perpendicular polyline snapping (30m off-route), 8s reroute debounce, and step tracking (15m arrival) wired into MapViewModel via async startNavigation.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create NavigationEngine | 5b0ad35 | Travel app/Services/NavigationEngine.swift |
| 2 | Integrate into MapViewModel | 15cc82d | Travel app/Views/Map/MapViewModel.swift |

## What Was Built

### NavigationEngine.swift (221 lines)

`@Observable final class NavigationEngine` — standalone state machine owning route navigation logic:

- `processLocation(_:)`: called on every GPS tick — computes step endpoint distance, checks step advancement at 15m, triggers voice distance checks, detects off-route at 30m perpendicular distance
- `perpendicularDistanceFromPolyline(_:)`: iterates all polyline segments using Cartesian projection (111,320 m/deg lat, lon corrected by cos(lat)); avoids nearest-vertex pitfall
- `triggerRerouteIfReady(from:)`: 8s debounce via `lastRerouteTime` guard; sets `isRerouting = true` before firing callback
- `cancelReroute()`: public method allowing MapViewModel to reset `isRerouting` (which is `private(set)`) on reroute failure without violating access control
- `didReceiveNewRoute(_:steps:)`: resets step index, clears rerouting flag, announces first step via voice service
- Callbacks: `onStepAdvanced`, `onRerouteNeeded`, `onNavigationFinished`

### MapViewModel.swift (additions)

New properties: `isNavigating`, `navigationEngine`, `navigationSteps`, `currentStepIndex`, `distanceToNextStep`, `voiceService` (private), `activeRouteDestination`

New methods:
- `startNavigation() async`: awaits step fetch inline if empty (race condition prevention), creates engine, wires `[weak self]` GPS callback via `self?.navigationEngine?.processLocation`
- `stopNavigation()`: destroys engine, calls `voiceService.resetAll()`, clears `onLocationUpdate`, calls `stopNavigationMode()`
- `rerouteNavigation(from:) async`: fetches new route + steps, calls `cancelReroute()` on both failure paths

Updated:
- `calculateDirectionRoute(to:)`: stores `activeRouteDestination`, launches background Task for `fetchNavigationSteps`
- `calculateRouteToSearchedItem(_:)`: same additions
- `clearRoute()`: calls `stopNavigation()` if navigating before clearing route state

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- NavigationEngine.swift: FOUND
- Commit 5b0ad35 (Task 1): FOUND
- Commit 15cc82d (Task 2): FOUND
