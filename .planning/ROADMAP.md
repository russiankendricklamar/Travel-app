# Roadmap: Map Navigation Overhaul

## Overview

Transform the Travel app's existing MapKit integration into a complete turn-by-turn navigation system. The work follows a strict dependency chain: core navigation engine first (pure logic, no UI), then the navigation UI layer, then route selection UX, and finally offline caching. Each phase delivers independently verifiable capability, building on the previous phase's stable API.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Navigation Engine** - Core navigation logic: step tracking, off-route detection, voice guidance, background GPS (completed 2026-03-20)
- [x] **Phase 2: Navigation UI** - HUD overlay, start button, map camera lock, navigation sheet detent, trip context (completed 2026-03-20)
- [x] **Phase 3: Route Selection** - Alternative routes picker, transport mode ETA bar, step list in bottom sheet (completed 2026-03-20)
- [x] **Phase 4: Offline Routes** - SwiftData route cache, pre-calculation, cache-first lookup, offline degradation (completed 2026-03-20)
- [x] **Phase 5: Offline Route Fixes** - Gap closure: fix auto-cached navigationSteps + unreachable offlineNoCacheMessage (completed 2026-03-20)

## Phase Details

### Phase 1: Navigation Engine
**Goal**: User's position is tracked along a route with voice announcements and automatic rerouting — all logic works before any new UI exists
**Depends on**: Nothing (first phase)
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04, NAV-05, ROUTE-04
**Success Criteria** (what must be TRUE):
  1. When the user follows a route, NavigationEngine advances through steps as the user passes each maneuver point
  2. When the user deviates more than 30m from the route, the engine detects the deviation and requests a new route (with at least 8s between reroute requests)
  3. Voice announcements play at 500m, 200m, and arrival distance for each maneuver, and background music resumes after each announcement
  4. GPS tracking continues when the app is backgrounded or the screen is locked
  5. The turn-by-turn step list (text instructions from MKRouteStep) is available as data for UI consumption
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — NavigationStep model, MKDirections step fetch, LocationManager navigation mode
- [x] 01-02-PLAN.md — NavigationVoiceService with distance-triggered announcements
- [x] 01-03-PLAN.md — NavigationEngine state machine + MapViewModel integration

### Phase 2: Navigation UI
**Goal**: User sees a floating HUD with the next maneuver, can start/stop navigation, and the map follows their position with heading lock
**Depends on**: Phase 1
**Requirements**: UI-01, UI-02, UI-03, UI-04, NAV-06
**Success Criteria** (what must be TRUE):
  1. User can tap "Начать навигацию" on a route to enter active navigation mode
  2. A floating glassmorphism card shows the next maneuver icon, instruction text, and distance remaining
  3. The map camera auto-pans to follow the user's position with heading lock during navigation
  4. The bottom sheet collapses to a minimal navigation detent showing current step, and can be expanded for the full step list
  5. The trip context label ("День 2 из 7 — Токио") is visible during navigation
**Plans**: 2 plans

Plans:
- [ ] 02-01-PLAN.md — Navigation UI components: MapViewModel state, NavigationHUDView, MapRecenterButton, NavigationSheetContent, start button
- [ ] 02-02-PLAN.md — TripMapView wiring: HUD overlay, recenter button, sheet case, dismiss guard, pan detection

### Phase 3: Route Selection
**Goal**: User can compare alternative routes and transport modes before starting navigation
**Depends on**: Phase 1
**Requirements**: ROUTE-01, ROUTE-02, ROUTE-03
**Success Criteria** (what must be TRUE):
  1. When a route is requested, 2-3 alternative routes are displayed as selectable cards with ETA and distance
  2. User can switch between transport modes (walk, drive, transit, bicycle) and see ETA for all modes simultaneously
  3. Selecting an alternative route updates the map polyline and step list immediately
**Plans**: 2 plans

Plans:
- [ ] 03-01-PLAN.md — Edge Function + RoutingService multi-route return + MapViewModel state extension
- [ ] 03-02-PLAN.md — RouteAlternativeCard component + carousel wiring in MapRouteContent + visual verification

### Phase 4: Offline Routes
**Goal**: User can navigate pre-cached routes without internet connection
**Depends on**: Phase 1, Phase 3
**Requirements**: OFFL-01, OFFL-02, OFFL-03, OFFL-04
**Success Criteria** (what must be TRUE):
  1. User can tap "Подготовить офлайн" to pre-calculate and cache routes between all places in a trip day
  2. When offline, RoutingService returns cached routes transparently (user sees no difference in route display)
  3. When offline with no cached route available, user sees a clear message explaining that routes are unavailable offline and suggesting to pre-cache while connected
  4. Cached routes persist across app restarts via SwiftData
**Plans**: 3 plans

Plans:
- [ ] 04-01-PLAN.md — CachedRoute @Model + RoutingCacheService L1/L2 cache + RoutingService offline overload
- [ ] 04-02-PLAN.md — preCacheDay parallel fetching + OfflinePrecacheButton + TripMapView integration
- [ ] 04-03-PLAN.md — Offline graceful degradation: carousel hide, no-cache message, reroute suppression, Settings cache clear

### Phase 5: Offline Route Fixes
**Goal**: Fix two integration bugs found during milestone audit: auto-cached routes missing navigationSteps and unreachable offline no-cache message
**Depends on**: Phase 4
**Requirements**: OFFL-02, OFFL-04
**Gap Closure**: Closes gaps from v1.0-MILESTONE-AUDIT.md
**Success Criteria** (what must be TRUE):
  1. Auto-cached routes (stored during online browsing) include navigationSteps, enabling offline navigation startup
  2. When offline with no cached route, user sees "Маршрут недоступен офлайн" message with pre-cache suggestion
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Navigation Engine | 3/3 | Complete   | 2026-03-20 |
| 2. Navigation UI | 2/2 | Complete   | 2026-03-20 |
| 3. Route Selection | 2/2 | Complete   | 2026-03-20 |
| 4. Offline Routes | 3/3 | Complete   | 2026-03-20 |
| 5. Offline Route Fixes | 1/1 | Complete   | 2026-03-20 |
