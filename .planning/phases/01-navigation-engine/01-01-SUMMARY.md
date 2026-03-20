---
phase: 01-navigation-engine
plan: "01"
subsystem: navigation
tags: [navigation, routing, location, mkdirections, gps]
dependency_graph:
  requires: []
  provides: [NavigationStep, MKPolyline.coordinates, TransportMode.mkTransportType, RoutingService.fetchNavigationSteps, LocationManager.startNavigationMode, LocationManager.stopNavigationMode, LocationManager.onLocationUpdate]
  affects: [RoutingService, LocationManager]
tech_stack:
  added: [MKDirections, kCLLocationAccuracyBestForNavigation, CLActivityType.otherNavigation]
  patterns: [MKDirections step extraction, navigation GPS mode toggle, location update callback]
key_files:
  created:
    - Travel app/Models/NavigationModels.swift
  modified:
    - Travel app/Services/RoutingService.swift
    - Travel app/Services/LocationManager.swift
decisions:
  - "NavigationModels.swift is a standalone model file — TransportMode extension lives here, not in RoutingService, to keep RoutingService focused on network/routing logic"
  - "cycling maps to MKDirections .walking because MKDirections has no cycling transport type"
  - "locationManagerDidPauseLocationUpdates restarts updates immediately as a safety net for background navigation"
metrics:
  duration_minutes: 8
  completed_date: "2026-03-20"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 2
---

# Phase 01 Plan 01: NavigationStep Model and GPS Mode Setup Summary

**One-liner:** NavigationStep struct, MKPolyline.coordinates extension, MKDirections-based turn-by-turn step fetching, and navigation-optimized GPS mode with background safety net.

## What Was Built

### NavigationModels.swift (new)
- `NavigationStep` struct with `instruction: String`, `distance: CLLocationDistance`, `polyline: [CLLocationCoordinate2D]`, `isTransit: Bool`
- `MKPolyline.coordinates` computed property using `getCoordinates(_:range:)` for safe extraction
- `TransportMode.mkTransportType` mapping all 4 modes — cycling falls back to `.walking` (MKDirections limitation)

### RoutingService.swift (extended)
- `navigationSteps: [NavigationStep]` added to `RouteResult` with default `[]` — backward-compatible, all existing callsites unaffected
- `fetchNavigationSteps(from:to:mode:existingTransitSteps:)` — uses `MKDirections.Request` for walk/drive/bike; converts `existingTransitSteps` for transit

### LocationManager.swift (extended)
- `startNavigationMode()` — sets `kCLLocationAccuracyBestForNavigation`, `.otherNavigation` activity type, no distance filter
- `stopNavigationMode()` — reverts to `kCLLocationAccuracyBest`, `.fitness`, 10m filter; only stops updates if not actively tracking a route
- `locationManagerDidPauseLocationUpdates` safety net — immediately restarts location updates if iOS pauses them during navigation
- `onLocationUpdate: ((CLLocation) -> Void)?` callback — called on every `didUpdateLocations` for NavigationEngine step matching

### UIBackgroundModes (verified)
- `Info.plist` confirmed to contain `UIBackgroundModes` array with `location` string — NAV-05 plist requirement satisfied

## Verification

- Build: 0 errors, 0 new warnings
- All grep checks passed (struct NavigationStep, var coordinates:, var mkTransportType:, func fetchNavigationSteps, func startNavigationMode, func stopNavigationMode, locationManagerDidPauseLocationUpdates, onLocationUpdate, UIBackgroundModes location)

## Deviations from Plan

None — plan executed exactly as written.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 8e881fd | feat(01-01): add NavigationStep model, MKPolyline.coordinates, TransportMode.mkTransportType |
| 2 | b227a6a | feat(01-01): add fetchNavigationSteps, navigation GPS mode, onLocationUpdate callback |

## Self-Check: PASSED
