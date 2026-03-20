---
phase: quick
plan: 260321-4ke
subsystem: ui
tags: [mapkit, polyline, catmull-rom, douglas-peucker, gps, swift]

requires:
  - phase: 06-offline-cache-wiring
    provides: TripMapView with polyline rendering infrastructure

provides:
  - PolylineSmoother utility (Douglas-Peucker + Catmull-Rom pipeline)
  - Smooth GPS route tracks via spline interpolation
  - Dual-layer depth rendering for active navigation route

affects: [TripMapView, map rendering, GPS track display]

tech-stack:
  added: []
  patterns:
    - "Dual-layer MapPolyline: translucent wide outer + narrow solid inner for visual depth"
    - "Pipeline pre-processing: simplify GPS noise (DP) then interpolate (Catmull-Rom) before rendering"

key-files:
  created:
    - "Travel app/Views/Map/PolylineSmoother.swift"
  modified:
    - "Travel app/Views/Map/TripMapView.swift"

key-decisions:
  - "epsilon=0.00005 degrees (~5m) for Douglas-Peucker — removes GPS noise without over-smoothing city walks"
  - "8 interpolated points per segment for Catmull-Rom — smooth curves with minimal coordinate overhead"
  - "Active route dual-layer: 10pt/0.3 opacity outer + 4pt solid inner (larger than train 6pt/3pt for navigation prominence)"
  - "No smoothing on active routes — MKDirections/Google Routes already returns smooth polylines"

requirements-completed: [SMOOTH-GPS, AESTHETIC-ROUTE]

duration: 12min
completed: 2026-03-21
---

# Quick Task 260321-4ke: Smooth and Aesthetic Route Polylines Summary

**Catmull-Rom spline smoothing for GPS tracks (Douglas-Peucker pre-simplification) and dual-layer depth rendering for active navigation routes in TripMapView**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-03-21T00:00:00Z
- **Completed:** 2026-03-21
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Created `PolylineSmoother` utility enum with Douglas-Peucker simplification and Catmull-Rom spline interpolation
- GPS route tracks now render through smooth spline curves instead of jagged straight-line segments
- Active navigation route uses dual-layer rendering (10pt translucent outer glow + 4pt solid inner core) matching the existing train route visual pattern
- Train routes and flight arcs are untouched

## Task Commits

1. **Task 1: Create PolylineSmoother utility** - `feef06f` (feat)
2. **Task 2: Apply smoothing to GPS tracks and dual-layer to active route** - `949d105` (feat)

## Files Created/Modified

- `/Users/egorgalkin/Travel app/Travel app/Views/Map/PolylineSmoother.swift` - Douglas-Peucker simplification + Catmull-Rom spline interpolation pipeline; `PolylineSmoother.smooth()` and `PolylineSmoother.simplify()` static methods
- `/Users/egorgalkin/Travel app/Travel app/Views/Map/TripMapView.swift` - GPS track section uses `PolylineSmoother.smooth(coordinates: rawCoords)`; active route section replaced with two `MapPolyline` layers

## Decisions Made

- Used epsilon=0.00005 degrees (~5 meters) for Douglas-Peucker: removes sub-5m GPS jitter while preserving actual path shape through city streets
- 8 interpolated points per Catmull-Rom segment balances visual smoothness against coordinate array size
- Active route dual-layer sized slightly larger (10pt/4pt) than train routes (6pt/3pt) since active navigation needs more visual prominence
- No smoothing applied to active routes — routing APIs already return smooth geometries, adding Catmull-Rom would over-smooth sharp turns at intersections

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Build verification showed `CompileAssetCatalogVariant` failure in `tail -5` output, but full build check confirmed `BUILD SUCCEEDED`. Pre-existing asset catalog warning unrelated to this task.

## Next Phase Readiness

- Map polyline rendering is now visually polished
- `PolylineSmoother` is a standalone utility available for any future coordinate smoothing needs
- No blockers

---
*Phase: quick*
*Completed: 2026-03-21*

## Self-Check: PASSED

- PolylineSmoother.swift: FOUND
- SUMMARY.md: FOUND
- Commit feef06f: VERIFIED
- Commit 949d105: VERIFIED
- TripMapView references `PolylineSmoother.smooth`: VERIFIED (line 261)
- TripMapView dual-layer active route with `opacity(0.3)`: VERIFIED (line 298)
- Train routes (lines 269-292): UNTOUCHED
- Flight arcs (lines 304+): UNTOUCHED
