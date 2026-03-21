---
phase: 09-floating-controls
plan: "01"
subsystem: map-ui
tags: [mapkit, floating-controls, overlay, compass, traffic, elevation]
dependency_graph:
  requires: [MapViewModel, TripMapView, AppTheme, LocationManager]
  provides: [FloatingControlsOverlay, showTraffic toggle, show3DElevation toggle]
  affects: [TripMapView, MapViewModel]
tech_stack:
  added: []
  patterns: [MapKit namespace scope wiring, @Bindable on @Observable VM, ultraThinMaterial blur container]
key_files:
  created:
    - "Travel app/Views/Map/FloatingControlsOverlay.swift"
  modified:
    - "Travel app/Views/Map/MapViewModel.swift"
    - "Travel app/Views/Map/TripMapView.swift"
decisions:
  - "Used @Bindable var vm: MapViewModel (not @ObservedObject) for toggle writes with @Observable pattern"
  - "view.3d / view.2d SF Symbols used for elevation toggle with .contentTransition(.symbolEffect(.replace))"
  - "Haptic via UIImpactFeedbackGenerator(.light) consistent with Phase 8 pattern"
  - "MapCompass count 1 in TripMapView grep is from comment string, not a view call — confirmed via line-number check"
metrics:
  duration_seconds: 189
  completed_date: "2026-03-21"
  tasks_completed: 2
  files_changed: 3
---

# Phase 09 Plan 01: Floating Controls Overlay Summary

Native Apple Maps-style floating controls (compass + blur container with transit/3D/location buttons) added to TripMapView using MapKit namespace scope wiring, @Observable/@Bindable pattern, and ultraThinMaterial blur container.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add VM properties and create FloatingControlsOverlay view | d8c657e | MapViewModel.swift (+4 lines), FloatingControlsOverlay.swift (new, 113 lines) |
| 2 | Wire FloatingControlsOverlay into TripMapView | 8664354 | TripMapView.swift (+11/-37 lines) |

## What Was Built

**FloatingControlsOverlay.swift** — New SwiftUI view at `Travel app/Views/Map/FloatingControlsOverlay.swift`:
- Native `MapCompass(scope: mapScope)` above the container (auto-hides when north-facing)
- 8pt gap between compass and container
- `ultraThinMaterial` blur container (44pt wide, cornerRadius 12, shadow 14pt)
- Three buttons: transit (`bus.fill`), elevation (`view.3d`/`view.2d` toggle), location (`location` outline)
- Visibility condition: `sheetDetent == .peek && !isNavigating && !showPrecipitation && !isOfflineWithCache`
- Spring animation `response:0.35 dampingFraction:0.85` on opacity transitions
- Accessibility labels and hints in Russian for all three buttons
- `UIImpactFeedbackGenerator(.light)` haptic on each tap

**MapViewModel.swift** changes:
- `var showTraffic: Bool = true` (starts ON per D-15)
- `var show3DElevation: Bool = false` (starts flat per UI-SPEC)

**TripMapView.swift** changes:
- `@Namespace private var mapScope` added
- `scope: mapScope` added to `Map()` initializer
- `.mapScope(mapScope)` added to outer ZStack
- Old floating location button block (32 lines) replaced by `FloatingControlsOverlay(vm: vm, mapScope: mapScope, isOfflineWithCache: isOfflineWithCache)`
- `MapCompass()` removed from `.mapControls` block
- `.mapStyle` changed from hardcoded `showsTraffic: true, elevation: .realistic` to dynamic `vm.showTraffic` and `vm.show3DElevation ? .realistic : .flat`

## Requirements Addressed

All 7 requirements met:
- CTRL-01: Three buttons visible in blur container on right side at peek
- CTRL-02: MapCompass above container, auto-hides when north-facing
- CTRL-03: Location button centers map at 0.01 degree zoom
- CTRL-04: Transit button toggles traffic overlay
- CTRL-05: 3D button toggles elevation between flat and realistic
- CTRL-06: All controls fade when sheet moves above peek (opacity animation)
- CTRL-07: Controls hidden during navigation, precipitation, and offline cache mode

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

Files exist:
- FloatingControlsOverlay.swift: FOUND
- MapViewModel.swift (modified): FOUND
- TripMapView.swift (modified): FOUND

Commits exist:
- d8c657e: FOUND
- 8664354: FOUND

## Self-Check: PASSED
