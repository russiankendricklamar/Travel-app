---
phase: 06-offline-cache-wiring
plan: 01
subsystem: map-routing
tags: [offline, routing, swiftdata, cache]
dependency_graph:
  requires: [RoutingService.calculateRoute(fromPlace:toPlace:mode:tripID:context:), OfflineCacheManager.preCacheDay]
  provides: [MapViewModel.modelContext, MapViewModel.calculateDirectionRoute offline path]
  affects: [TripMapView, MapViewModel, RoutingCacheService lookup]
tech_stack:
  added: []
  patterns: [modelContext injection via onAppear, place-UUID routing overload, coordinate fallback]
key_files:
  created: []
  modified:
    - Travel app/Views/Map/MapViewModel.swift
    - Travel app/Views/Map/TripMapView.swift
decisions:
  - "modelContext injected via .onAppear (not init) — TripMapView already holds @Environment(\.modelContext), onAppear is the earliest safe injection point"
  - "Place-UUID overload only when routeOriginPlace is set — GPS origin has no UUID so cannot use L2 cache keyed by UUID pair; GPS→Place offline remains unavailable (acceptable per OFFL-02 scope)"
metrics:
  duration: "<5 min"
  completed: 2026-03-21
---

# Phase 06 Plan 01: Wire Offline Cache Route Lookup Summary

**One-liner:** Routed MapViewModel.calculateDirectionRoute through the place-UUID RoutingService overload so pre-cached SwiftData routes are served offline instead of returning an error.

## What Was Built

OFFL-02 gap closure: the place-UUID overload in RoutingService (with L1+L2 SwiftData cache) was implemented in Phase 4 but never called from MapViewModel. The coordinate-only overload was called instead, bypassing the cache entirely.

Two surgical changes:

1. **MapViewModel.swift** — added `import SwiftData`, `var modelContext: ModelContext?` stored property, and updated `calculateDirectionRoute(to:)` to branch: when `modelContext != nil` and `routeOriginPlace != nil`, calls `RoutingService.shared.calculateRoute(fromPlace:toPlace:mode:tripID:context:)` (cache-first); otherwise falls back to coordinate overload.

2. **TripMapView.swift** — added `vm.modelContext = modelContext` at the top of `.onAppear`, injecting the SwiftData context into the VM so the cache path is available.

## Verification

All acceptance criteria met:
- `var modelContext: ModelContext?` present in MapViewModel (line 160)
- `import SwiftData` present in MapViewModel (line 3)
- Place-UUID overload called at lines 493-499
- Coordinate fallback retained at lines 502-504 (single occurrence in calculateDirectionRoute)
- `vm.modelContext = modelContext` injected in TripMapView.onAppear (line 160)
- Build succeeded: `** BUILD SUCCEEDED **` (no new errors, pre-existing warnings only)

## Deviations from Plan

None — plan executed exactly as written (minimal correct fix variant from plan's analysis section).

## Self-Check: PASSED

- Modified files exist and contain expected patterns
- Commit 1d1f6e7 exists in git log
