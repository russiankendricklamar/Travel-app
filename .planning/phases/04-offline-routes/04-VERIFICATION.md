---
phase: 04-offline-routes
verified: 2026-03-21T00:00:00Z
status: passed
score: 10/10 must-haves verified
re_verification: false
gaps: []
human_verification:
  - test: "Pre-cache a day with 3+ places while online, then enable Airplane Mode and open TripMapView"
    expected: "Cached routes load normally; 'МАРШРУТЫ ГОТОВЫ' badge visible; uncached modes show '—'"
    why_human: "Network state toggling and MapKit rendering cannot be verified programmatically"
  - test: "Start navigation on a cached offline route, then deviate from the route path"
    expected: "Warning toast 'Перестроение недоступно офлайн' appears for ~4 seconds, no reroute attempt"
    why_human: "GPS simulation and NavigationEngine live callbacks require device/simulator interaction"
---

# Phase 4: Offline Route Caching Verification Report

**Phase Goal:** Offline route caching — CachedRoute model, two-tier L1/L2 cache, route pre-caching UI with 3-state button, offline graceful degradation (hide alternatives, suppress reroute, cache clear).
**Verified:** 2026-03-21
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | CachedRoute persists route data across app restarts via SwiftData | VERIFIED | `@Model final class CachedRoute` in `Models/CachedRoute.swift`; registered in ModelContainer in `Travel_appApp.swift` line 25 |
| 2 | RoutingCacheService provides L1 in-memory + L2 SwiftData two-tier cache | VERIFIED | `private var l1: [String: RouteResult]` (L1) + `FetchDescriptor<CachedRoute>` query (L2) in `RoutingCacheService.swift` lines 11, 30-41 |
| 3 | When offline, RoutingService returns cached route transparently | VERIFIED | `calculateRoute(fromPlace:toPlace:mode:tripID:context:)` overload in `RoutingService.swift` lines 196-231; offline branch calls `RoutingCacheService.shared.lookup` |
| 4 | When online, RoutingService always uses API (no cache read) | VERIFIED | `if await OfflineCacheManager.shared.isOnline` at line 204 of `RoutingService.swift` routes to live API; cache only written on success |
| 5 | When offline with no cache, RoutingService sets lastError and returns [] | VERIFIED | `lastError = "Маршрут недоступен офлайн. Подготовьте маршруты заранее при наличии сети."` at line 229; returns `[]` |
| 6 | User can tap 'Подготовить офлайн' to pre-cache all day routes | VERIFIED | `OfflinePrecacheButton.swift` — idle state has "ПОДГОТОВИТЬ ОФЛАЙН" button; calls `OfflineCacheManager.shared.preCacheDay`; integrated in `TripMapView.swift` line 79 |
| 7 | Progress ring shows real-time percentage during pre-caching | VERIFIED | `Circle().trim(from: 0, to: progress)` at line 76 of `OfflinePrecacheButton.swift`; animated with `.easeInOut(duration: 0.3)` |
| 8 | Offline graceful degradation: carousel hidden, no-cache message, pills degraded | VERIFIED | `MapRouteContent.swift` — carousel wrapped in `if OfflineCacheManager.shared.isOnline` (line 25); `offlineNoCacheMessage` shown when `isOnline == false && vm.activeRoute == nil` (line 19); transport pills show "—" at 0.5 opacity offline (lines 136, 147) |
| 9 | Off-route while offline shows warning instead of reroute | VERIFIED | `NavigationEngine.swift` — `isOfflineMode: Bool` (line 27); `if !isOfflineMode` guards `triggerRerouteIfReady` (line 93); `onOfflineRerouteWarning?()` fires instead (line 96); `MapViewModel.swift` wires 4s auto-dismiss toast; `TripMapView.swift` shows "Перестроение недоступно офлайн" (line 113) |
| 10 | Settings has 'Очистить кэш маршрутов' button with confirmation dialog | VERIFIED | `SettingsView.swift` lines 1002-1033: `trash.fill` icon, `toriiRed` styling, `confirmationDialog("Удалить кэш маршрутов?")` calls `RoutingCacheService.shared.clearAll(context: modelContext)` |

**Score:** 10/10 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Travel app/Models/CachedRoute.swift` | @Model with JSON-encoded polyline and navigation steps | VERIFIED | Contains `@Model`, all UUID fields, `CoordDTO`/`NavigationStepDTO`/`TransitStepDTO`, `toRouteResult()`, `from()` factory, 7-day TTL constant |
| `Travel app/Services/RoutingCacheService.swift` | L1+L2 cache singleton with lookup, store, clearL1, clearAll | VERIFIED | `@MainActor @Observable` singleton; `lookup`, `store`, `isDayCached`, `clearL1`, `clearAll`, `clearForTrip` all present and substantive |
| `Travel app/Services/RoutingService.swift` | New `calculateRoute(fromPlace:toPlace:mode:context:)` overload | VERIFIED | Overload present at lines 196-231 with full online/offline branching |
| `Travel app/Views/Shared/OfflinePrecacheButton.swift` | 3-state button: idle/loading/done with progress ring | VERIFIED | `PrecacheState` enum; idle/loading/done states; `Circle().trim` progress ring; bambooGreen done state; "Недоступно без сети" subtitle when offline |
| `Travel app/Services/OfflineCacheManager.swift` | `preCacheDay` method with parallel route fetching | VERIFIED | `preCacheDay` uses `withTaskGroup` for N^2 pairs in walking+automobile; captures coords/IDs before task entry; stores results via `RoutingCacheService.shared.store` |
| `Travel app/Views/Map/TripMapView.swift` | Precache button placement + day-cached badge | VERIFIED | `currentDayForPrecache` computed property; `checkmark.icloud.fill` badge with bambooGreen and `.accessibilityLabel("День подготовлен офлайн")`; `OfflinePrecacheButton` in idle mode; `backgroundRefreshIfNeeded` on `.task` |
| `Travel app/Views/Map/MapRouteContent.swift` | Offline-aware carousel hiding, no-cache message, transport pill disabled state | VERIFIED | Carousel gated on `isOnline`; `offlineNoCacheMessage` with `wifi.exclamationmark`; "—" text and 0.5 opacity for offline uncached pills |
| `Travel app/Services/NavigationEngine.swift` | `onOfflineRerouteWarning` callback, offline reroute suppression | VERIFIED | `var isOfflineMode: Bool = false`; `var onOfflineRerouteWarning: (() -> Void)?`; `if !isOfflineMode` guard before `triggerRerouteIfReady` |
| `Travel app/Views/Map/MapViewModel.swift` | `showOfflineRerouteWarning` + callback wiring with 4s auto-dismiss | VERIFIED | `var showOfflineRerouteWarning: Bool = false` at line 149; `onOfflineRerouteWarning` callback wired at lines 635-640 with `Task.sleep` 4s dismiss |
| `Travel app/Views/Settings/SettingsView.swift` | Clear route cache button with confirmation | VERIFIED | `trash.fill`, `toriiRed`, `showClearCacheConfirmation` state, `confirmationDialog`, `RoutingCacheService.shared.clearAll` all present |
| `Travel app/Travel_appApp.swift` | CachedRoute registered in ModelContainer + L1 clearL1 on foreground | VERIFIED | `CachedRoute.self` in `ModelContainer` at line 25; `RoutingCacheService.shared.clearL1()` in `.onChange(of: scenePhase)` when `.active` at line 80 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `RoutingCacheService.swift` | `CachedRoute.swift` | `FetchDescriptor<CachedRoute>` query and `context.insert` | WIRED | Lines 30-41 (lookup) and lines 56-69 (store) |
| `RoutingService.swift` | `RoutingCacheService.swift` | `RoutingCacheService.shared.lookup` in offline branch | WIRED | Lines 221-226; `RoutingCacheService.shared.store` in online branch at lines 212-215 |
| `OfflinePrecacheButton.swift` | `OfflineCacheManager.swift` | `preCacheDay` called on tap | WIRED | `startPrecaching()` calls `OfflineCacheManager.shared.preCacheDay` at line 124 |
| `TripMapView.swift` | `OfflinePrecacheButton.swift` | Embedded in idle mode | WIRED | `OfflinePrecacheButton(day: day, tripID: trip.id)` at line 79 |
| `MapRouteContent.swift` | `OfflineCacheManager.swift` | `OfflineCacheManager.shared.isOnline` check | WIRED | Lines 19, 25, 136, 147 — all inline in SwiftUI body |
| `NavigationEngine.swift` | `OfflineCacheManager.swift` | `isOfflineMode` flag (set from MapViewModel, avoids @MainActor violation) | WIRED | `isOfflineMode` set at `MapViewModel.swift` line 634; guards `triggerRerouteIfReady` at `NavigationEngine.swift` line 93 |
| `MapViewModel.swift` | `NavigationEngine.swift` | `onOfflineRerouteWarning` callback wiring | WIRED | Lines 635-640; fires `showOfflineRerouteWarning = true`; `TripMapView.swift` reads this property to show toast |
| `SettingsView.swift` | `RoutingCacheService.swift` | `clearAll(context:)` called from confirmation dialog | WIRED | `RoutingCacheService.shared.clearAll(context: modelContext)` at line 129 |
| `Travel_appApp.swift` | `RoutingCacheService.swift` | `clearL1()` on scene `.active` | WIRED | Line 80 inside `scenePhase` onChange handler |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| OFFL-01 | 04-01 | CachedRoute @Model в SwiftData для хранения сериализованных маршрутов | SATISFIED | `CachedRoute.swift` — full @Model with JSON-serialized polyline, nav steps, transit steps; registered in ModelContainer |
| OFFL-02 | 04-01, 04-03 | Cache-first lookup в RoutingService (офлайн маршрут если есть в кэше) | SATISFIED | `RoutingService.calculateRoute(fromPlace:)` offline branch returns cached route; also covers carousel/pill degradation in MapRouteContent |
| OFFL-03 | 04-02 | Кнопка "Подготовить офлайн" — предзагрузка маршрутов между всеми местами дня | SATISFIED | `OfflinePrecacheButton` 3-state button in `TripMapView` idle mode; `preCacheDay` N^2 parallel fetch |
| OFFL-04 | 04-03 | Graceful degradation при отсутствии сети — сообщение, alternatives скрыты, reroute заблокирован | SATISFIED | Carousel hidden; "Маршрут недоступен офлайн" message; transport pills degraded; reroute warning toast; Settings cache clear |

All 4 requirements SATISFIED. No orphaned requirements.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `RoutingService.swift` | 241 | `print(...)` statement in `calculateRoutesAPIRoute` | Info | Logging artifact; does not affect offline functionality |

No blocker or warning-level anti-patterns found in phase deliverables.

---

## Human Verification Required

### 1. End-to-End Offline Pre-Cache Flow

**Test:** On a real device or simulator, create a trip day with 3+ places. Ensure device is online. Open TripMapView. Tap "ПОДГОТОВИТЬ ОФЛАЙН". Wait for "МАРШРУТЫ ГОТОВЫ" green state. Enable Airplane Mode. Reopen the map and select a route between two cached places.
**Expected:** Route loads from cache; "МАРШРУТЫ ГОТОВЫ" badge shows; alternatives carousel is hidden; uncached transport modes show "—" at reduced opacity.
**Why human:** Network toggling and live MapKit rendering cannot be driven programmatically in this codebase.

### 2. Offline Reroute Warning Toast

**Test:** Start navigation on a cached offline route (Airplane Mode active). Physically deviate from the route path (or simulate GPS offset).
**Expected:** "Перестроение недоступно офлайн" toast appears near the top of the navigation HUD, auto-dismisses after ~4 seconds, and no reroute computation occurs.
**Why human:** NavigationEngine's `processLocation` is triggered by live CLLocationManager updates; cannot be tested without GPS simulation.

---

## Gaps Summary

No gaps. All 10 observable truths verified, all 11 artifacts exist and are substantive, all 9 key links are wired, all 4 requirements are satisfied. Phase goal achieved.

---

_Verified: 2026-03-21_
_Verifier: Claude (gsd-verifier)_
