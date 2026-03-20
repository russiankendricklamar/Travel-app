---
phase: 03-route-selection
verified: 2026-03-20T12:00:00Z
status: human_needed
score: 7/7 must-haves verified
re_verification: false
human_verification:
  - test: "Route carousel visible in simulator"
    expected: "1-3 route cards appear between transport pills and route stats after requesting a route; first card has sakuraPink border; ETA shown in large bold mode-colored text; distance on lower row"
    why_human: "Visual glassmorphism rendering, card sizing, and layout correctness cannot be verified via grep"
  - test: "Tapping a non-selected card updates map polyline and route stats"
    expected: "Polyline on map switches to the tapped route's polyline; route stats (ETA, distance) in routeStatsRow reflect the newly selected route"
    why_human: "Real-time MapKit polyline swap and state sync require runtime observation"
  - test: "Switching transport mode resets carousel selection"
    expected: "Tapping a different transport pill triggers skeleton loading (2 shimmer cards), then new alternatives load with first card selected (index 0)"
    why_human: "Animation sequencing and skeleton → cards transition require runtime observation"
  - test: "Transit mode shows transfer count instead of distance"
    expected: "Transit card's lower row shows Russian-declined transfer count (e.g. '2 пересадки') instead of a distance string"
    why_human: "Transit mode requires live Google Directions API data to verify correct transfer count display"
  - test: "Badges 'Быстрый' and 'Короткий' appear on different cards when 2+ alternatives"
    expected: "'Быстрый' badge on the fastest route card; 'Короткий' badge on the shortest (if different from fastest); no badges when only 1 route"
    why_human: "Badge assignment depends on Google Routes API returning multiple alternatives, which requires a live API call"
  - test: "Shimmer skeleton appears during route calculation"
    expected: "Exactly 2 skeleton cards with pulsing opacity animation appear in the carousel during isCalculatingRoute=true state"
    why_human: "Animation timing and state transition require runtime observation"
---

# Phase 3: Route Selection Verification Report

**Phase Goal:** User can compare alternative routes and transport modes before starting navigation
**Verified:** 2026-03-20
**Status:** human_needed (all automated checks pass; 6 items need runtime/visual confirmation)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | RoutingService.calculateRoute returns [RouteResult] with 2-3 alternatives for drive/walk/cycle | VERIFIED | `func calculateRoute(...) async -> [RouteResult]` at line 138; `routes.prefix(3).map` at line 221 |
| 2 | Transit mode returns single-element array (not empty, not multiple) | VERIFIED | Lines 163-166: `if let googleResult { return [googleResult] }`; fallback to `[aiResult]` for region unavailable; final `return []` on total failure |
| 3 | MapViewModel tracks alternativeRoutes array and selectedRouteIndex | VERIFIED | Lines 78-83 in MapViewModel.swift: `var alternativeRoutes: [RouteResult] = []`, `var selectedRouteIndex: Int = 0`, `var selectedRoute: RouteResult?` computed property |
| 4 | Switching transport mode resets selectedRouteIndex to 0 | VERIFIED | `recalculateRoute()` in MapRouteContent calls `calculateDirectionRoute(to:)` or `calculateRouteToSearchedItem(_:)`; both set `selectedRouteIndex = 0` with `alternativeRoutes = results` atomically |
| 5 | Edge Function sends computeAlternativeRoutes: true to Google Routes API | VERIFIED | Line 209 in api-proxy/index.ts: `computeAlternativeRoutes: true`; `routes.staticDuration` added to fieldMask at line 235 |
| 6 | 1-3 route cards appear in horizontal carousel between transport pills and route stats | VERIFIED (code) | `routeAlternativesCarousel` inserted at line 19 in MapRouteContent.swift body between `transportModePills` and `routeStatsRow`; `ForEach(Array(vm.alternativeRoutes.enumerated()), id: \.offset)` at line 165 |
| 7 | ETA displayed for each transport mode simultaneously (transport pills) | VERIFIED | `RoutingService.shared.etaPreviews[mode]` consumed in transport mode pills (line 125 MapRouteContent); `fetchETAPreviews` called in background after route calculation |

**Score:** 7/7 truths verified (automated)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/functions/api-proxy/index.ts` | computeAlternativeRoutes flag for Google Routes API | VERIFIED | Line 209: `computeAlternativeRoutes: true`; line 235: `routes.staticDuration` in fieldMask |
| `Travel app/Services/RoutingService.swift` | Multi-route return from calculateRoute | VERIFIED | Returns `[RouteResult]`; `calculateRoutesAPIRoute` returns `[RouteResult]`; transit wraps in array; cache hit returns `[cached]`; all failures return `[]` |
| `Travel app/Views/Map/MapViewModel.swift` | alternativeRoutes array, selectedRouteIndex, selectedRoute computed property | VERIFIED | Lines 78-84: all three properties present; 8 reset sites confirmed (clearRoute, stopNavigation, onPlaceSelected, clearSelection, dismissDetail, rerouteNavigation) |
| `Travel app/Views/Map/RouteAlternativeCard.swift` | Route alternative card view + skeleton + badge enum | VERIFIED | 141-line file; `RouteBadge` enum with fastest/shortest; `RouteAlternativeCard` with all required props; `RouteAlternativeCardSkeleton` with shimmer; Russian declension `transfersLabel`; accessibility labels |
| `Travel app/Views/Map/MapRouteContent.swift` | Carousel inserted between transport pills and route stats | VERIFIED | `routeAlternativesCarousel` at line 19 in body; `badgeFor(index:)` at line 185; skeleton on `isCalculatingRoute`; tap handler sets `vm.selectedRouteIndex` and `vm.activeRoute` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `api-proxy/index.ts` | `routes.googleapis.com` | `computeAlternativeRoutes: true` in body | WIRED | Line 209: `computeAlternativeRoutes: true` |
| `RoutingService.swift` | `MapViewModel.swift` | `calculateRoute` returns `[RouteResult]`; VM sets `alternativeRoutes = results` | WIRED | Lines 354-360 MapViewModel: `let results = await RoutingService.shared.calculateRoute(...)`; `alternativeRoutes = results` |
| `MapViewModel.swift` | `MapRouteContent.swift` | `activeRoute` kept in sync with `selectedRoute` via card tap | WIRED | `onTap` at lines 170-175: `vm.selectedRouteIndex = index` + `vm.activeRoute = route` inside `withAnimation` |
| `MapRouteContent.swift` | `MapViewModel.swift` | reads `vm.alternativeRoutes` and `vm.selectedRouteIndex` | WIRED | Lines 164, 168: `vm.alternativeRoutes.isEmpty`, `index == vm.selectedRouteIndex` |
| `MapRouteContent.swift` | `RouteAlternativeCard.swift` | ForEach instantiation in carousel | WIRED | Line 166: `RouteAlternativeCard(route: route, isSelected: ..., badge: ..., onTap: ...)` |
| `RouteAlternativeCard.swift` | `MapViewModel.swift` via `MapRouteContent` | onTap sets `vm.selectedRouteIndex` and `vm.activeRoute` | WIRED | Closure passed through `onTap:` parameter; executed in MapRouteContent.routeAlternativesCarousel |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ROUTE-01 | 03-01-PLAN, 03-02-PLAN | Построение маршрута с 2-3 альтернативными вариантами | SATISFIED | `routes.prefix(3).map` in RoutingService; `alternativeRoutes = results` in MapViewModel; carousel ForEach in MapRouteContent |
| ROUTE-02 | 03-01-PLAN, 03-02-PLAN | Переключение транспортного режима (пешком, авто, транспорт, велосипед) | SATISFIED | Transport mode pills wired to `recalculateRoute()` which calls route calculation with new `selectedTransportMode`; alternatives reset to index 0 |
| ROUTE-03 | 03-02-PLAN | Отображение ETA и расстояния для каждого транспортного режима одновременно | SATISFIED | `fetchETAPreviews` populates `RoutingService.shared.etaPreviews`; transport pills render ETA from `etaPreviews[mode]` for non-active modes; active mode shows route stats |

No orphaned requirements found. ROUTE-04 (turn-by-turn step list) is mapped to Phase 1, not Phase 3 — correctly excluded from these plans.

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `Travel app/Services/RoutingService.swift` | Multiple `print()` statements (debug logging) | Info | Not blocking; debug statements not removed. Style rule targets JS `console.log`, Swift `print` in services is lower priority. No impact on goal. |

No stub implementations, no TODO/FIXME markers, no empty returns in phase deliverables.

### Human Verification Required

#### 1. Route Carousel Visual Rendering

**Test:** Open the app in simulator (iPhone 17 Pro Max), navigate to any trip's map tab, tap a place pin, tap "Маршрут".
**Expected:** A horizontal carousel of 1-3 glassmorphism cards appears between transport pills and route stats. First card has a sakuraPink stroke border. Each card shows ETA in large bold mode-colored text (22pt rounded) and distance below.
**Why human:** Visual glassmorphism rendering, 140x88pt card sizing, and overall layout correctness require running the app.

#### 2. Card Tap Updates Map Polyline and Route Stats

**Test:** With 2+ route cards visible, tap a non-selected card.
**Expected:** The map polyline changes to reflect the newly selected route. Route stats (ETA and distance) in the section below the carousel update to match the tapped route. The tapped card gains the sakuraPink border; the previously selected card loses it.
**Why human:** Real-time MapKit polyline rendering and animated state synchronization require runtime observation.

#### 3. Transport Mode Switch Resets Carousel

**Test:** With a route active and carousel showing, tap a different transport mode pill (e.g., switch from Walking to Auto).
**Expected:** The carousel immediately shows 2 skeleton shimmer cards (pulsing opacity animation). After route calculation completes, new alternative cards appear with the first card selected (sakuraPink border). Route stats below update accordingly.
**Why human:** Animation sequencing (skeleton → cards) and state reset timing require runtime observation.

#### 4. Transit Mode Shows Transfer Count

**Test:** Tap the "ОТ" (transit) pill to request a transit route.
**Expected:** The carousel shows a single card. The lower row of that card displays a Russian-declined transfer count (e.g., "0 пересадок", "1 пересадка", "2 пересадки") rather than a distance string.
**Why human:** Transit routing requires a live Google Directions API response with transit step data.

#### 5. Fastest/Shortest Badges on Correct Cards

**Test:** Request a walking or driving route in an area likely to yield 2-3 alternatives (e.g., a major city center). Observe badge labels on cards.
**Expected:** The fastest route card shows "Быстрый" badge (sakuraPink, 10pt bold). If a different route is the shortest, it shows "Короткий". No badges appear when only 1 route is returned.
**Why human:** Badge assignment depends on Google Routes API returning multiple alternatives with differing time/distance values.

#### 6. Shimmer Skeleton Animation

**Test:** During the few seconds while a route is calculating, observe the carousel area.
**Expected:** Exactly 2 skeleton cards with pulsing opacity (0.4 to 1.0, easeInOut 1s, repeating) appear in the carousel. They transition smoothly to real cards when calculation completes.
**Why human:** Animation timing and visual smoothness require runtime observation.

### Gaps Summary

No gaps identified. All automated checks pass. The phase data layer (Plan 01) and UI layer (Plan 02) are fully implemented and wired. The six human verification items are runtime/visual behaviors that cannot be assessed from static code analysis alone.

---

_Verified: 2026-03-20_
_Verifier: Claude (gsd-verifier)_
