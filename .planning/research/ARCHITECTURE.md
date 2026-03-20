# Architecture Patterns: MapKit Navigation

**Domain:** iOS travel app — turn-by-turn navigation, multimodal routing, offline maps
**Researched:** 2026-03-20
**Confidence:** HIGH (based on existing codebase analysis + MapKit platform constraints)

---

## Existing Architecture (What Is Already Built)

The codebase already has a well-structured map subsystem. The overhaul builds on top of it — it does not replace it.

### Current Component Inventory

| File | Role | State |
|------|------|-------|
| `MapViewModel.swift` | Central @Observable state machine for all map interactions | Exists, extend |
| `RoutingService.swift` | Google Routes API v2 + Directions + Distance Matrix via SupabaseProxy | Exists, extend |
| `TripMapView.swift` | Root SwiftUI Map view, layer switching, toolbar | Exists, extend |
| `MapBottomSheet.swift` | Custom draggable sheet (peek/half/full detents) | Exists, complete |
| `MapRouteContent.swift` | Route info panel, transport mode pills, transit steps | Exists, extend |
| `MapPlaceDetailContent.swift` | Place detail in bottom sheet | Exists |
| `MapSearchContent.swift` | Search bar + results list | Exists |
| `MapFloatingSearchPill.swift` | Idle-mode floating search button | Exists |
| `MapPinViews.swift` | Place, search result, AI result pin renderers | Exists |
| `MapTransportOverlays.swift` | Flight arcs, train route polylines | Exists |
| `LocationManager.swift` | CLLocationManager wrapper, GPS tracking, Live Activity | Exists, extend |
| `LiveActivityManager.swift` | ActivityKit for trip events | Exists |
| `MapOfflineGallery.swift` | Offline fallback — MKMapSnapshotter static images | Exists, replace/extend |

### Current Data Flow (Routing)

```
User taps "Route" button
    → MapViewModel.calculateDirectionRoute(to:)
        → LocationManager.shared.requestCurrentLocation()  [one-shot GPS]
        → RoutingService.shared.calculateRoute(from:to:mode:)
            → SupabaseProxy.request(service: "google_routes" | "google_directions")
                → Supabase Edge Function → Google Routes API v2 / Directions API
            → Returns RouteResult (polyline, duration, distance, transitSteps)
        → vm.activeRoute = result
        → vm.sheetContent = .routeInfo
        → TripMapView renders MapPolyline over Map
        → MapRouteContent renders stats + transit steps in bottom sheet
    → Background: RoutingService.fetchETAPreviews() (all 4 modes in parallel)
```

---

## Recommended Architecture for Navigation Overhaul

### Component Boundaries

| Component | Responsibility | Reads From | Writes To |
|-----------|---------------|-----------|----------|
| `MapViewModel` | UI state machine — sheet content, navigation mode, step index | LocationManager, RoutingService, NavigationEngine | Self (published state) |
| `RoutingService` | Route calculation — Google APIs via proxy, result caching, ETA previews | SupabaseProxy | Cache dictionary, etaPreviews |
| `NavigationEngine` | NEW — active turn-by-turn session state; step advancement, rerouting triggers, off-route detection | LocationManager, RoutingService | vm.navigationState |
| `NavigationVoiceService` | NEW — AVSpeechSynthesizer wrapper; instruction queuing, distance-triggered playback | NavigationEngine | AVSpeechSynthesizer |
| `LocationManager` | GPS stream — continuous updates during navigation, one-shot for routing | CLLocationManager | currentLocation, routePoints |
| `OfflineRouteCache` | NEW — SwiftData model storing serialised RouteResult per origin+dest+mode | RoutingService | SwiftData store |
| `OfflineMapPreloader` | NEW — MKMapSnapshotter tile batching for regions | MapViewModel | OfflineMapCache (SwiftData) |
| `LiveActivityManager` | ActivityKit — extend for navigation turn display | NavigationEngine | Activity<> |
| `TripMapView` | Root view — assembles map layers, routes sheet content, owns MapViewModel | MapViewModel | cameraPosition |
| `MapRouteContent` | Route info panel — stats, mode switcher, transit steps, START button | MapViewModel, RoutingService | MapViewModel.selectedTransportMode |
| `NavigationHUD` | NEW — turn-by-turn overlay (next maneuver card, distance, lane guidance) | MapViewModel.navigationState | — |

### New Component: NavigationEngine

This is the core missing piece. It sits between LocationManager (raw GPS) and the UI (MapViewModel + NavigationHUD).

```
NavigationEngine (@Observable)
  ├── currentRoute: RouteResult           — active route being navigated
  ├── currentStepIndex: Int               — which maneuver we're on
  ├── distanceToNextStep: CLLocationDistance
  ├── isNavigating: Bool
  ├── isRerouting: Bool
  └── offRouteThreshold: CLLocationDistance = 50m

Responsibilities:
  1. Consume LocationManager.currentLocation updates
  2. Project user position onto active route polyline
  3. Detect step completion (crossed waypoint within threshold)
  4. Detect off-route (perpendicular distance > offRouteThreshold)
  5. Trigger NavigationVoiceService.announce(step:distanceRemaining:)
  6. On off-route: call RoutingService.calculateRoute() from new position → update route
  7. On arrival: set isNavigating = false, trigger LiveActivity end
```

### New Component: NavigationVoiceService

```
NavigationVoiceService
  ├── synthesizer: AVSpeechSynthesizer
  ├── queue: [AnnouncementEvent]
  └── Language: device locale (no config needed)

Trigger distances (standard navigation UX):
  - Prepare:   500m before step
  - Warning:   200m before step ("В 200 метрах повернуть направо")
  - Execute:   at step boundary ("Повернуть направо")
  - Arrival:   at destination
```

### NavigationState in MapViewModel

Extend MapViewModel with a navigation sub-state rather than adding a new top-level view model. This preserves the existing single-source-of-truth pattern.

```swift
// Add to MapViewModel:
var isNavigating: Bool = false
var navigationStepIndex: Int = 0
var distanceToNextStep: CLLocationDistance = 0
var navigationEngine: NavigationEngine?

func startNavigation() {
    guard let route = activeRoute else { return }
    navigationEngine = NavigationEngine(route: route)
    isNavigating = true
    // Camera: follow user heading, tilt for 3D feel
    cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
}

func stopNavigation() {
    navigationEngine = nil
    isNavigating = false
}
```

---

## Data Flow

### Route Calculation Flow (existing, unchanged)

```
User → MapViewModel → RoutingService → SupabaseProxy → Google API
                                     ← RouteResult
         ↓
   vm.activeRoute set → TripMapView renders MapPolyline
                      → MapRouteContent shows stats + START button
```

### Active Navigation Flow (new)

```
User taps START
    → vm.startNavigation()
    → NavigationEngine.start(route:)
        → subscribes to LocationManager.currentLocation

Every GPS update:
    LocationManager → NavigationEngine.processLocation(coord)
        → project onto polyline
        → check step threshold
        → check off-route
        → publish distanceToNextStep, currentStepIndex

    NavigationEngine → NavigationVoiceService.check(distance:step:)
        → if trigger distance → AVSpeechSynthesizer.speak()

    NavigationEngine → MapViewModel (via @Observable binding)
        → NavigationHUD re-renders next maneuver

    NavigationEngine → LiveActivityManager
        → update Dynamic Island with next turn + distance

Off-route detected:
    NavigationEngine → RoutingService.calculateRoute(from: currentLocation, ...)
        → try offline cache first (OfflineRouteCache.find())
        → if miss: SupabaseProxy (requires connection)
        → update vm.activeRoute, reset stepIndex to 0
```

### Offline Route Flow (new)

```
Online (before travel):
    User taps "Подготовить офлайн"
    → OfflineMapPreloader.preload(region:)
        → MKMapSnapshotter batches tiles at zoom 12, 14, 16
        → saves to OfflineMapCache (SwiftData)
    → RoutingService calculates routes between all trip places
        → serialises RouteResult → OfflineRouteCache (SwiftData)

Offline (in foreign country):
    RoutingService.calculateRoute() checks OfflineRouteCache first
        → cache hit: return immediately (no network)
        → cache miss: surface "Маршрут недоступен офлайн" error

    NavigationEngine rerouting:
        → checks OfflineRouteCache for nearby cached route
        → if none: disable rerouting, show "Маршрут может быть неточным"

    TripMapView:
        → OfflineCacheManager.isOnline = false
        → shows live MapKit map (tiles cached by iOS) — NOT MapOfflineGallery
        → MapOfflineGallery fallback only when MapKit tiles also fail
```

---

## Suggested Build Order

Dependencies determine this order. Each phase can be built and tested independently.

### Phase 1: NavigationEngine + VoiceService (core, no UI)
**Why first:** Everything else depends on this. Pure Swift, testable without UI.
- `NavigationEngine.swift` — step tracking, off-route detection, polyline projection
- `NavigationVoiceService.swift` — AVSpeechSynthesizer wrapper, distance triggers
- Unit tests: step advancement, off-route threshold, voice trigger distances
- **No UI changes in this phase.**

### Phase 2: NavigationHUD (UI overlay during active navigation)
**Why second:** Requires NavigationEngine to have stable API.
- `NavigationHUD.swift` — next maneuver card floating above map
- `ManeuverIcon.swift` — SF Symbol mapping for turn types (turn.left, merge, etc.)
- Extend `MapViewModel` with `isNavigating`, `navigationStepIndex`, `distanceToNextStep`
- Add START button to `MapRouteContent`
- Camera: switch to `.userLocation(followsHeading: true)` when navigating
- **Requires Phase 1.**

### Phase 3: Alternative Routes (2-3 options before starting)
**Why third:** Enhances RoutingService independently of navigation session.
- Extend `RoutingService.calculateRoute()` to return `[RouteResult]` (up to 3 alternatives)
- `MapViewModel.routeAlternatives: [RouteResult]`
- `MapRouteContent` route alternatives picker (swipeable cards like Apple Maps)
- Render alternatives as dimmed polylines, active route highlighted
- **Requires Phase 2 for the START button integration.**

### Phase 4: Offline Route Cache (OfflineRouteCache SwiftData model)
**Why fourth:** Can be built independently; NavigationEngine depends on it for rerouting.
- `OfflineRouteCache` @Model — stores serialised RouteResult + origin/dest/mode key
- Extend `RoutingService` to check cache before network call
- Extend "Подготовить офлайн" button in SettingsView to pre-calculate routes between trip places
- **Integrates into NavigationEngine rerouting (Phase 1 extension).**

### Phase 5: Live Activity for Navigation (Dynamic Island turn display)
**Why last:** Requires NavigationEngine state to be stable; ActivityKit attributes need separate Widget target.
- New `NavigationActivityAttributes` — next maneuver, distance, ETA
- Extend `LiveActivityManager` with `startNavigationActivity()` / `updateNavigationActivity()`
- Wire NavigationEngine → LiveActivityManager updates on each step
- **Requires Phases 1-2.**

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Storing navigation state in RoutingService
**What goes wrong:** RoutingService is a stateless calculator. Mixing active session state into it creates threading issues when rerouting fires a new calculation mid-navigation.
**Instead:** NavigationEngine owns the session. RoutingService remains a pure async calculator.

### Anti-Pattern 2: Polling LocationManager from NavigationEngine
**What goes wrong:** Polling creates lag and misses rapid GPS updates.
**Instead:** NavigationEngine observes `LocationManager.currentLocation` via `@Observable` change tracking, or receives updates via a dedicated delegate/callback registered at navigation start.

### Anti-Pattern 3: Replacing MapBottomSheet with UIKit sheet
**What goes wrong:** The existing custom `MapBottomSheet` with peek/half/full detents already works and matches the glassmorphism design. Switching to `UISheetPresentationController` breaks the glassmorphism background and requires bridging.
**Instead:** Extend the existing sheet with a `.navigating` detent (small strip showing next turn).

### Anti-Pattern 4: One OfflineMapCache entry per zoom level
**What goes wrong:** MKMapSnapshotter renders a single image at the current viewport — it is not a tile cache. Treating it as one creates a massive data set that still doesn't work for interactive panning.
**Instead:** Pre-render fixed-region snapshots per trip day (current behaviour). For interactive offline panning, rely on iOS's built-in MapKit tile cache (which persists automatically for recently viewed areas).

### Anti-Pattern 5: AVSpeechSynthesizer one instance per announcement
**What goes wrong:** Creating a new synthesizer per announcement causes voice overlaps and memory churn.
**Instead:** `NavigationVoiceService` holds a single `AVSpeechSynthesizer` instance and uses `speak()` with `stopSpeaking(at: .word)` to interrupt before queuing the next announcement.

---

## Scalability Considerations

| Concern | Current State | Navigation Added |
|---------|--------------|-----------------|
| GPS update frequency | One-shot for routing | Continuous (kCLLocationAccuracyBest) — already configured in LocationManager |
| RouteResult memory | Single route in-memory | Up to 3 alternatives in-memory; polylines are arrays of CLLocationCoordinate2D (~16 bytes each × ~500 points = ~8KB per route) — negligible |
| Offline cache size | MKMapSnapshotter JPEG per day | OfflineRouteCache adds ~2-5KB per cached route (serialised polyline) — negligible |
| Background location | Already enabled (allowsBackgroundLocationUpdates = true) | Navigation needs this; already configured |
| Live Activity updates | 30s timer (event tracking) | Navigation needs per-step updates (~every 30-200m) — acceptable within ActivityKit rate limits |

---

## Component Dependency Graph

```
TripMapView
    └── MapViewModel (@Observable, owns navigation sub-state)
            ├── RoutingService (route calculation)
            │       ├── SupabaseProxy (network)
            │       └── OfflineRouteCache (SwiftData) [NEW Phase 4]
            ├── NavigationEngine [NEW Phase 1]
            │       ├── LocationManager (GPS stream)
            │       ├── RoutingService (rerouting)
            │       └── NavigationVoiceService [NEW Phase 1]
            │               └── AVSpeechSynthesizer
            └── LiveActivityManager (navigation turn display) [NEW Phase 5]

TripMapView renders:
    ├── Map (MapPolyline overlays, UserAnnotation)
    ├── NavigationHUD [NEW Phase 2] — floats over map
    └── MapBottomSheet
            ├── MapSearchContent
            ├── MapPlaceDetailContent
            └── MapRouteContent (+ START button) [extend Phase 2]
```

---

## Sources

- Codebase analysis: `MapViewModel.swift`, `RoutingService.swift`, `TripMapView.swift`, `MapBottomSheet.swift`, `MapRouteContent.swift`, `LocationManager.swift`, `LiveActivityManager.swift`, `MapOfflineGallery.swift`
- Platform: AVSpeechSynthesizer, ActivityKit, MapKit — iOS 17+, no third-party dependencies
- Architecture confidence: HIGH (derived from existing code patterns; no external sources needed for component boundaries)
