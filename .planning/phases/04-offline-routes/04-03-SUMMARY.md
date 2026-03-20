---
phase: 04-offline-routes
plan: 03
subsystem: ui
tags: [swiftui, offline, routing, navigation, cache]

# Dependency graph
requires:
  - phase: 04-01
    provides: RoutingCacheService (lookup/clearAll/clearL1), OfflineCacheManager.isOnline
provides:
  - Offline graceful degradation for map routing UI
  - Carousel hidden offline, no-cache message shown, transport pills degraded
  - Off-route reroute suppressed offline with warning toast
  - Settings cache clear button with confirmation dialog
  - L1 cache invalidated on every app foreground entry
affects: [04-offline-routes, map-routing-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "isOfflineMode: Bool flag on NavigationEngine — set from MapViewModel at navigation start, avoids async @MainActor access from background GPS thread"
    - "onOfflineRerouteWarning callback with Task.sleep 4s auto-dismiss — pure async, no Timer dependencies"

key-files:
  created: []
  modified:
    - Travel app/Views/Map/MapRouteContent.swift
    - Travel app/Services/NavigationEngine.swift
    - Travel app/Views/Map/MapViewModel.swift
    - Travel app/Views/Map/TripMapView.swift
    - Travel app/Views/Settings/SettingsView.swift
    - Travel app/Travel_appApp.swift

key-decisions:
  - "NavigationEngine stores isOfflineMode: Bool (set at start) instead of reading OfflineCacheManager.shared.isOnline — avoids @MainActor isolation issue since NavigationEngine is called from GPS thread"
  - "onOfflineRerouteWarning fired on every off-route tick (not debounced separately) — existing rerouteDebounce in triggerRerouteIfReady still applies in online path, offline path now has separate warning callback"
  - "Carousel hidden entirely offline (not just empty) — avoids unnecessary empty-state and matches CONTEXT.md decision that offline = single route per mode"

patterns-established:
  - "Offline feature gates: OfflineCacheManager.shared.isOnline checks inline in SwiftUI body — reactive because @Observable propagates changes"

requirements-completed: [OFFL-02, OFFL-04]

# Metrics
duration: 22min
completed: 2026-03-20
---

# Phase 04 Plan 03: Offline Graceful Degradation Summary

**Offline-aware route UI: carousel hidden, transport pills show '—' for uncached modes, off-route warning toast replaces reroute attempt, Settings cache clear button with confirmation dialog**

## Performance

- **Duration:** 22 min
- **Started:** 2026-03-20T14:54:00Z
- **Completed:** 2026-03-20T15:16:46Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- MapRouteContent hides alternatives carousel when offline and shows "Маршрут недоступен офлайн" no-cache message when activeRoute == nil
- Transport mode pills show "—" at 0.5 opacity for uncached modes offline; ETA previews still shown when available from in-memory cache
- NavigationEngine suppresses reroute and fires onOfflineRerouteWarning when isOfflineMode is true; MapViewModel wires 4-second auto-dismiss toast
- SettingsView has "Очистить кэш маршрутов" destructive button (trash.fill, toriiRed) with confirmation dialog calling RoutingCacheService.shared.clearAll
- L1 in-memory cache cleared on every scene .active transition to prevent stale data after app resume

## Task Commits

Each task was committed atomically:

1. **Task 1: MapRouteContent offline behavior + NavigationEngine reroute suppression** - `75cbf1f` (feat)
2. **Task 2: Settings cache clear button + L1 invalidation on foreground** - `87b4eea` (feat)

## Files Created/Modified
- `Travel app/Views/Map/MapRouteContent.swift` - Offline carousel hide, no-cache message, transport pill disabled state
- `Travel app/Services/NavigationEngine.swift` - isOfflineMode flag, onOfflineRerouteWarning callback
- `Travel app/Views/Map/MapViewModel.swift` - showOfflineRerouteWarning property, callback wiring with 4s auto-dismiss
- `Travel app/Views/Map/TripMapView.swift` - Offline reroute warning toast overlay during navigation
- `Travel app/Views/Settings/SettingsView.swift` - Cache clear button + confirmation dialog in dataSection
- `Travel app/Travel_appApp.swift` - RoutingCacheService.shared.clearL1() on scene .active

## Decisions Made
- NavigationEngine uses stored `isOfflineMode: Bool` (set from MapViewModel at navigation start) rather than reading `OfflineCacheManager.shared.isOnline` directly — avoids @MainActor isolation violation since processLocation is called from GPS thread without MainActor context
- onOfflineRerouteWarning callback fires whenever off-route is detected offline (not separately debounced) — the existing 8-second rerouteDebounce in triggerRerouteIfReady only applies in online path; offline warning is intentionally more immediate

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
- Linter reverted first-pass edits to MapRouteContent body after MapViewModel edit — re-applied carousel/no-cache message changes to body immediately after. Root cause: concurrent tool writes to different files triggered a format pass that overwrote intermediate state.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 04 is now fully complete: CachedRoute model (04-01), per-day pre-cache UI (04-02), offline UI degradation (04-03)
- Offline routing gracefully degrades: cached routes work, uncached routes explain why, navigation warns instead of rerouting
- Ready for v1.0 release or Phase 05 if planned

---
*Phase: 04-offline-routes*
*Completed: 2026-03-20*
