# Project Research Summary

**Project:** Travel App — Map Navigation Overhaul
**Domain:** iOS MapKit turn-by-turn navigation for travel planner
**Researched:** 2026-03-20
**Confidence:** HIGH

## Executive Summary

This is a navigation overhaul of an existing, well-structured iOS travel app — not a greenfield navigation app. The codebase already contains MapKit integration, a RoutingService backed by Google Routes API via Supabase proxy, a custom bottom sheet, location management, and offline map snapshots. The task is to build a complete turn-by-turn navigation experience on top of this foundation using exclusively Apple-native APIs: MapKit (iOS 17 SwiftUI APIs), MKDirections, AVSpeechSynthesizer, CLLocationManager, and ActivityKit. No third-party SDKs are needed or appropriate given the MapKit-only constraint.

The recommended approach follows a strict dependency order: build the core NavigationEngine and NavigationVoiceService first (pure Swift, no UI), then layer NavigationHUD on top, then add alternative route selection, then offline route caching, and finally Live Activity integration. This order ensures each phase is independently testable and prevents the most common failure mode — building UI before the state machine is stable. The architecture is an extension of the existing single-source-of-truth MapViewModel pattern, with NavigationEngine as a new @Observable component owned by MapViewModel rather than a parallel top-level service.

The key risks are: (1) background location silently killed by iOS when the screen turns off — requires both `allowsBackgroundLocationUpdates = true` in code AND `UIBackgroundModes: [location]` in Info.plist, which is the most commonly missed step; (2) AVSpeechSynthesizer permanently ducking background music if the audio session is not explicitly deactivated with a 0.5s delay after speech ends; (3) rerouting flooding the Google Routes API without debouncing. All three are well-understood and preventable with specific patterns documented in PITFALLS.md.

## Key Findings

### Recommended Stack

The entire feature set can be delivered using Apple-native APIs available on iOS 17+ — which the project already targets. MapKit's SwiftUI APIs (`Map`, `MapPolyline`, `MapCameraPosition`) replace legacy UIKit wrappers. MKDirections handles route calculation including alternatives. AVSpeechSynthesizer provides offline, free, Russian-language voice guidance. CLLocationManager (already in `LocationManager.swift`) needs configuration for continuous navigation mode. ActivityKit (already in `LiveActivityManager.swift`) extends to show navigation turns in the Dynamic Island.

**Core technologies:**
- `Map` + `MapPolyline` (iOS 17 SwiftUI): Route rendering — WWDC23 APIs, no MKMapViewRepresentable needed
- `MKDirections` (stable): Route calculation — supports alternatives, all transport modes, already wired via RoutingService
- `CLLocationManager` (existing): Continuous GPS during navigation — must set `pausesLocationUpdatesAutomatically = false`
- `AVSpeechSynthesizer` (iOS 7+): Voice guidance — offline, Russian-language, no API key, single instance pattern required
- `presentationDetents` + `presentationBackgroundInteraction` (iOS 16.4+): Apple Maps-style sheet — already in MapBottomSheet.swift
- `SwiftData` (existing): Offline route caching — `CachedRoute` @Model for serialised polylines + steps
- `ActivityKit` (existing): Navigation Live Activity — extend `LiveActivityManager` for turn display

**Critical limitation:** MKDirections transit mode does not expose structured transit legs (line numbers, stop counts). Step text is human-readable only. Full offline interactive map tiles are not possible with MapKit — accept this platform constraint.

### Expected Features

**Must have (table stakes):**
- Alternative routes panel (2-3 options with ETA chips) — MKDirections already returns these
- Turn-by-turn step list in bottom sheet — MKRouteStep text already available
- Transport mode ETA bar (all 4 modes simultaneously) — etaPreviews already loaded
- Navigation mode: map auto-pan + heading lock + next-turn banner
- Voice guidance via AVSpeechSynthesizer (Russian, reads next step on approach)
- Route deviation detection + automatic recalculation

**Should have (travel-specific differentiators):**
- Navigate to itinerary places directly — one-tap routing from saved places
- Pre-cached routes for offline playback — store RouteResult JSON per trip day
- Trip context overlay during navigation — "День 2 из 7 — Токио"
- Day-by-day route overview with color coding per day

**Defer to later milestones:**
- Weather-aware transport suggestion — needs orchestration service, complex
- Multi-city inter-city routing — low traveler demand relative to complexity
- Live Activity navigation integration — tie in after core navigation is stable

**Anti-features (explicitly excluded):**
- Custom tile rendering (Mapbox/MapLibre), truck/motorcycle routing, AR navigation, CarPlay, live traffic toggle, speed cameras, subscription gating

### Architecture Approach

The overhaul extends the existing architecture rather than replacing it. `MapViewModel` remains the single source of truth and gains navigation sub-state. A new `NavigationEngine` (@Observable) sits between `LocationManager` (raw GPS) and the UI, owning the active session: step index, distance to next maneuver, off-route detection, and rerouting triggers. A new `NavigationVoiceService` wraps `AVSpeechSynthesizer` with distance-triggered announcement logic. `OfflineRouteCache` is a new SwiftData @Model that stores serialised RouteResult entries keyed by origin + destination + mode. The existing `MapBottomSheet`, `MapRouteContent`, and `TripMapView` are extended, not replaced.

**Major components:**
1. `NavigationEngine` (NEW) — active session state machine: step tracking, off-route detection, rerouting orchestration
2. `NavigationVoiceService` (NEW) — AVSpeechSynthesizer wrapper with 500m/200m/0m trigger distances and audio session lifecycle
3. `NavigationHUD` (NEW) — floating next-maneuver overlay card, rendered above the Map view
4. `OfflineRouteCache` (NEW SwiftData @Model) — persisted RouteResult entries for offline navigation
5. `MapViewModel` (EXTEND) — gains `isNavigating`, `navigationStepIndex`, `distanceToNextStep`, owns NavigationEngine instance
6. `RoutingService` (EXTEND) — returns `[RouteResult]` for alternatives, checks OfflineRouteCache before network

### Critical Pitfalls

1. **Background location silently killed** — iOS stops GPS when screen turns off unless BOTH `allowsBackgroundLocationUpdates = true` AND `UIBackgroundModes: [location]` in Info.plist are set. The plist entry is the step most commonly missed. Must set `pausesLocationUpdatesAutomatically = false` and `activityType = .otherNavigation`. Test on physical device only — simulator behaves differently.

2. **AVSpeechSynthesizer ducks music permanently** — The synthesizer activates the AVAudioSession but never deactivates it. Must call `AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)` in `speechSynthesizer(_:didFinish:)` delegate with a 0.5s `asyncAfter` delay (synchronous call fails with error 560030580).

3. **MKMapSnapshotter cannot provide interactive offline maps** — Snapshots are static UIImages at a fixed zoom; they cannot be panned or zoomed. The compliant offline strategy is: cache `RouteResult` polylines in SwiftData (routes, not tiles), display them as overlays on a degraded Map view, and accept that tile availability depends on iOS's own URLCache.

4. **Rerouting floods the API without debouncing** — `CLLocationManager` fires at 1 Hz; a single off-route segment can trigger 15+ API calls in 30 seconds. Must enforce: 20–50m off-route threshold, 8–10s debounce between reroute requests, snap origin to nearest step start before computing cache key.

5. **@Observable MapViewModel causes 1 Hz map re-renders during navigation** — Navigation state (step index, distance, voice queue) must be in a separate `NavigationSessionState` struct or isolated @Observable. Camera position should only update when user moves >5m, not on every GPS tick.

## Implications for Roadmap

Based on research, the architecture's dependency graph dictates a clear 5-phase order. Each phase is independently buildable and testable.

### Phase 1: NavigationEngine + VoiceService (Core Logic, No UI)
**Rationale:** Everything else depends on this. NavigationEngine is pure Swift — testable without UI, no rendering concerns. Building it first ensures the state machine is stable before any UI is layered on.
**Delivers:** Step advancement logic, off-route detection, polyline snapping, AVSpeechSynthesizer integration with correct audio session lifecycle.
**Addresses:** Table-stakes navigation features (route deviation, voice guidance).
**Avoids:** Pitfall 1 (background location — configure here), Pitfall 2 (audio session deactivation — implement here), Pitfall 4 (rerouting debounce — build the guard here), Pitfall 6 (step matching with segment snapping, not nearest-start).

### Phase 2: NavigationHUD + Active Navigation UI
**Rationale:** Requires Phase 1's stable NavigationEngine API. UI directly renders NavigationEngine state.
**Delivers:** `NavigationHUD` floating overlay (next maneuver card + distance), START navigation button in MapRouteContent, map camera auto-pan with heading lock, `.navigating` sheet detent.
**Uses:** `MapCameraPosition.userLocation(followsHeading: true)`, `presentationDetents`, existing MapBottomSheet extension.
**Avoids:** Pitfall 5 (isolate NavigationSessionState from map-redraw path), Pitfall 9 (use `.regularMaterial` for navigation sheet, not `.ultraThinMaterial`).

### Phase 3: Route UX Completion (Alternative Routes + Step List)
**Rationale:** Enhances RoutingService independently of active navigation session. Can be built in parallel with Phase 2 by a second developer, or immediately after.
**Delivers:** Alternative routes picker (2-3 swipeable cards with ETA), full turn-by-turn step list in bottom sheet full detent, transport mode ETA bar (all 4 modes).
**Uses:** `MKDirections.requestsAlternateRoutes = true`, existing `etaPreviews` loading.
**Avoids:** Pitfall 7 (transit fallback — auto-switch to walking with clear explanation when transit unavailable), Pitfall 8 (lane guidance treated as optional render, no dedicated phase).

### Phase 4: Offline Route Cache
**Rationale:** SwiftData model is independent of navigation UI; NavigationEngine's rerouting logic can integrate it once it exists.
**Delivers:** `OfflineRouteCache` @Model, pre-calculation of routes between all trip places via "Подготовить офлайн" button, cache-first lookup in RoutingService, graceful offline error messaging.
**Uses:** SwiftData (existing), extend OfflineCacheManager.
**Avoids:** Pitfall 3 (accept tile limitation, document honestly — "маршруты сохранены, тайлы зависят от подключения"), Pitfall 12 (cache key must include transport mode).

### Phase 5: Live Activity Navigation Integration
**Rationale:** Requires stable NavigationEngine state (Phase 1) and NavigationHUD (Phase 2). ActivityKit widget target changes are separate from app logic — appropriate to do last.
**Delivers:** `NavigationActivityAttributes` with next maneuver + distance + ETA, Dynamic Island compact turn display, per-step updates from NavigationEngine to LiveActivityManager.
**Uses:** ActivityKit (existing `LiveActivityManager.swift` extension), WidgetKit.
**Implements:** LiveActivityManager extension.

### Phase Ordering Rationale

- NavigationEngine first because it is the shared dependency of HUD (Phase 2), step list (Phase 3), offline rerouting (Phase 4), and Live Activity (Phase 5) — all four phases read its state.
- UI in Phase 2 before alternative routes in Phase 3 because the START button and navigation mode are prerequisites for users to benefit from route alternatives.
- Offline cache in Phase 4 before Live Activity because offline is higher user value for a travel app (users go abroad without data); Live Activity is enhancement.
- All critical pitfalls (background location, audio session, rerouting debounce, state isolation) are addressed in Phases 1-2, before any polish phases.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1:** CLLocation polyline segment snapping algorithm — specific math for perpendicular projection; needs implementation research or reference implementation
- **Phase 4:** SwiftData serialisation of `MKRoute` / `RouteResult` — MKPolyline is not Codable natively; coordinate array serialisation approach needs validation

Phases with standard patterns (skip research-phase):
- **Phase 2:** NavigationHUD UI layout follows established Apple Maps pattern; MapKit camera APIs are well-documented
- **Phase 3:** MKDirections alternative routes — single flag change, well-documented; ETA bar already partially built
- **Phase 5:** ActivityKit extension — project already has LiveActivityManager; extension is additive

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All APIs are Apple-native, iOS 17+, official WWDC23 documentation verified. No third-party SDKs introduced. |
| Features | HIGH | Table stakes derived from existing codebase analysis; differentiators are logical extensions of existing services (WeatherService, RoutingService). Anti-features clearly justified by platform constraints. |
| Architecture | HIGH | Derived directly from codebase analysis — every component named exists; extension points are explicit. No external architecture sources needed. |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls verified against Apple Developer Forums and official docs. Audio session deactivation bug confirmed in Apple forums. Background location plist requirement is official. Rerouting debounce is inferred from platform behavior. |

**Overall confidence:** HIGH

### Gaps to Address

- **MKRoute Codable serialisation:** Storing routes in SwiftData requires serialising `CLLocationCoordinate2D` arrays manually (they are not Codable). Validate chosen encoding format (JSON coordinates array vs binary) during Phase 4 planning.
- **Transit step granularity:** MKDirections transit steps are human-readable text only — no structured line/stop data. If the product requires "take Metro Line 3 for 4 stops" display, this must come from Google Directions API `transitDetails` field, not MKDirections. Clarify requirement before Phase 3.
- **Physical device testing timeline:** Pitfalls 1, 2, and 5 cannot be validated on simulator. Physical device must be available before Phase 1 is considered complete.
- **UIBackgroundModes plist entry:** This is a manual Xcode configuration step (noted in MEMORY.md as pending). Must be completed before any navigation testing — it cannot be done in code.

## Sources

### Primary (HIGH confidence)
- [WWDC23: Meet MapKit for SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10043/) — Map, MapPolyline, MapCameraPosition APIs
- [Apple Developer: MKDirections](https://developer.apple.com/documentation/mapkit/mkdirections) — routing, alternatives, transport modes
- [Apple Developer: AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) — TTS, audio session
- [Apple Developer: CLLocationManager](https://developer.apple.com/documentation/corelocation/cllocationmanager) — background location, navigation accuracy
- [Apple Developer: MKMapSnapshotter](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter) — offline tile limitation
- [Apple Developer: usesApplicationAudioSession](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/usesapplicationaudiosession) — audio session control
- [WWDC24: What's new in location authorization](https://developer.apple.com/videos/play/wwdc2024/10212/) — background location config
- Existing codebase: `MapViewModel.swift`, `RoutingService.swift`, `LocationManager.swift`, `LiveActivityManager.swift`

### Secondary (MEDIUM confidence)
- [Sarunw: SwiftUI bottom sheet](https://sarunw.com/posts/swiftui-bottom-sheet/) — presentationDetents pattern
- [Kodeco: Routing with MapKit and Core Location](https://www.kodeco.com/10028489-routing-with-mapkit-and-core-location) — MKDirections usage
- [Apple Developer Forums: AVSpeechSynthesizer session deactivation (error 560030580)](https://developer.apple.com/forums/thread/45599) — confirmed audio bug
- [Apple Developer Forums: CLLocationManager background location](https://developer.apple.com/forums/thread/87256) — background mode config
- [Medium: SwiftUI MapKit iOS 17 Missing Features](https://medium.com/@gerdcastan/swiftui-mapkit-ios-17-the-missing-features-4b08fa42ee9f) — MKTileOverlay SwiftUI limitation

### Tertiary (LOW confidence)
- [GitHub: react-native-background-geolocation iOS background gaps (Feb 2026)](https://github.com/transistorsoft/react-native-background-geolocation/issues/2494) — corroborates background location pause behavior

---
*Research completed: 2026-03-20*
*Ready for roadmap: yes*
