# Technology Stack

**Project:** Travel App — Map Navigation Overhaul
**Researched:** 2026-03-20
**Mode:** Ecosystem / Stack dimension

---

## Recommended Stack

### Core Map Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| MapKit (SwiftUI) | iOS 17+ | Primary map rendering, annotations, overlays | Native, free, Apple Maps style out of the box. WWDC23 SwiftUI APIs (`Map`, `MapPolyline`, `Marker`, `Annotation`) replaced legacy UIKit wrappers — use these, not `MKMapViewRepresentable` |
| `Map` view (SwiftUI) | iOS 17+ | Map container with camera control | `MapCameraPosition` + `@Binding` gives declarative camera control. Supports `MapPolyline` stroke directly — no `MKOverlayRenderer` boilerplate |
| `MapPolyline` | iOS 17+ | Route polylines on map | Draws `MKRoute.polyline` natively in SwiftUI `Map` scope. Use `stroke(style:)` with `StrokeStyle` for dashes/width |

**Confidence: HIGH** — verified via WWDC23 session "Meet MapKit for SwiftUI" and Apple developer docs.

---

### Routing

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `MKDirections` | iOS 7+ (stable) | Route calculation | Only Apple-provided routing engine. Returns `MKRoute` with `steps`, `polyline`, `distance`, `expectedTravelTime`. App already uses `RoutingService.swift` — extend, don't replace |
| `MKDirections.Request` | iOS 7+ | Route request config | Set `transportType` (`.automobile`, `.walking`, `.transit`). Set `requestsAlternateRoutes = true` for 2-3 alternatives |
| `MKRoute.Step` | iOS 7+ | Turn-by-turn step data | Each step has `instructions` (human-readable), `distance`, `polyline`, `transportType`. This is the data source for voice prompts |
| `MKDirections.Response` | iOS 7+ | Route results | Array of `MKRoute` objects. Sort by `expectedTravelTime` or `distance` to surface best route |

**Confidence: HIGH** — official Apple docs confirmed, stable API since iOS 7.

**Critical limitation:** Transit routing via `MKDirections` returns `MKRoute` steps but **does not expose individual transit legs** (e.g., "take Metro Line 3 for 4 stops"). Step text is human-readable but structured transit data is not available. For combined metro + walk routes, you get a single fused polyline with mixed `transportType` steps — acceptable for this project.

---

### Turn-by-Turn Navigation Engine

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `CLLocationManager` | iOS 2+ | Real-time user position during navigation | `startUpdatingLocation()` with `desiredAccuracy = kCLLocationAccuracyBestForNavigation`. Delegate or async stream. App already has `LocationManager.swift` — extend it |
| `CLLocation.distance(from:)` | iOS 2+ | Off-route deviation detection | Compare current position to nearest `MKRoute.Step` polyline point. If distance > threshold (e.g. 50m), trigger recalculation via new `MKDirections` request |
| Custom `NavigationEngine` (@Observable) | — | Navigation state machine | Tracks: currentStepIndex, distanceToNextStep, isNavigating, hasDeviated. Updates on each CLLocation callback. Triggers `AVSpeechSynthesizer` at right moments |

**Confidence: HIGH** — standard pattern, confirmed by multiple developer resources. No higher-level Apple navigation engine exists for third-party apps (only Apple Maps internal).

**Route recalculation pattern:** On deviation detected → issue new `MKDirections` request from current location to original destination → replace active route. No Apple API for auto-recalc — must implement manually.

---

### Voice Guidance

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `AVSpeechSynthesizer` | iOS 7+ | Text-to-speech voice prompts | Free, offline, supports all iOS languages including Russian. No API key, no network required |
| `AVSpeechUtterance` | iOS 7+ | Individual voice prompt | Set `.voice` to `AVSpeechSynthesisVoice(language: "ru-RU")` for Russian. Set `.rate` to `AVSpeechUtteranceDefaultSpeechRate` |
| `AVAudioSession` | iOS 2+ | Audio session management | Set category `.playback` with `.duckOthers` option to lower music volume during prompts — same pattern as Apple Maps |

**Confidence: HIGH** — well-documented, widely used. iOS 17 introduced "Personal Voice" support (opt-in). Confirmed working for navigation prompts in multiple third-party apps.

**Trigger logic:** Announce step instruction when `distanceToNextStep < 300m` (early warning) and `< 50m` (turn now). Use `AVSpeechSynthesizer.stopSpeaking(at: .immediate)` before queuing new utterance to prevent overlap.

---

### UI Components

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `.sheet` + `presentationDetents` | iOS 16+ | Apple Maps-style bottom sheet | Native SwiftUI. Use `[.height(100), .medium, .large]` detents. `.presentationBackgroundInteraction(.enabled)` keeps map interactive while sheet is open. `.presentationCornerRadius(32)` for rounded top |
| `presentationBackgroundInteraction(.enabled)` | iOS 16.4+ | Non-blocking sheet | Critical for Apple Maps feel — without it, map is dimmed and non-interactive behind sheet |
| `@GestureState` + `DragGesture` | iOS 13+ | Custom sheet drag handle | For glassmorphism-styled handle indicator inside sheet header |
| `ZStack` + `.ignoresSafeArea` | iOS 13+ | Floating search pill over map | Layer search bar on top of Map view. Already used in `MapFloatingSearchPill.swift` |

**Confidence: HIGH** — `presentationDetents` and `presentationBackgroundInteraction` verified in Apple docs, available iOS 16+. Project targets iOS 17+ so all available.

---

### Offline Maps

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `MKMapSnapshotter` | iOS 7+ | Tile snapshots per region | Already in app (`OfflineCacheManager`). Captures raster snapshots at zoom levels. Suitable for viewing offline, not interactive tile streaming |
| `MKTileOverlay` (UIKit bridge) | iOS 7+ | Custom tile overlay | Only accessible via `UIViewRepresentable` wrapper — SwiftUI `Map` does not support `MKOverlayRenderer` directly. Needed if streaming tiles from custom source |
| `SwiftData` (existing) | iOS 17+ | Persist cached routes offline | Store serialized `MKRoute` data (polyline coordinates + steps) as `CachedRoute` @Model. Retrieve by origin/destination hash when offline |

**Confidence: MEDIUM** — Apple's ToS prohibits caching Apple Maps tiles for offline use. `MKMapSnapshotter` snapshots are a gray area used widely in apps. For offline routing, route caching (not tile caching) is the compliant approach. The project already made this architectural decision correctly.

**Offline routing approach:** Cache `MKRoute` responses in SwiftData when online. On offline request, match origin+destination (fuzzy, within ~500m radius) to return cached route. No separate routing engine needed. Mark routes with `cachedAt` timestamp, expire after 7 days.

---

### Live Activity / Dynamic Island

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `ActivityKit` | iOS 16.1+ | Live Activity for active navigation | Project already has `LiveActivityManager.swift`. Extend existing widget for navigation state: current step instruction, distance, ETA |
| `WidgetKit` | iOS 14+ | Live Activity UI rendering | Navigation Dynamic Island: compact view shows next turn icon + distance. Expanded view shows full step text |

**Confidence: HIGH** — project already uses this stack (Session 8). Navigation Live Activity is a natural extension.

---

### Supporting Libraries (No Third-Party SDKs Required)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Combine` / Swift Concurrency | Swift 5.5+ | Async route requests | Use `async/await` for `MKDirections.calculate()`. Already project pattern |
| `CoreLocation` framework | iOS 2+ | Full location services | Already in `LocationManager.swift`. For navigation: switch to `kCLLocationAccuracyBestForNavigation` during active nav, revert to `kCLLocationAccuracyHundredMeters` when idle to save battery |
| `SwiftData` | iOS 17+ | Route + offline cache persistence | Already used project-wide. `CachedRoute` model for offline routing |

---

## Alternatives Considered and Rejected

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Map rendering | MapKit (SwiftUI native) | Mapbox SDK, MapLibre | Project constraint: MapKit only. Also: Mapbox costs money, adds 10MB+ binary, different visual style |
| Offline tiles | MKMapSnapshotter cache | Mapbox Offline, OpenStreetMap tiles | ToS violation for Apple tiles; Mapbox requires SDK; OSM tiles need custom renderer (MapLibre) |
| Voice TTS | AVSpeechSynthesizer | Amazon Polly, Google TTS | Requires network, API key, cost. System TTS is offline, free, no latency. Quality sufficient for navigation prompts |
| Route calculation | MKDirections | OSRM, GraphHopper, Valhalla | All require server infrastructure or third-party SDK. MKDirections is free, no server needed, returns Apple Maps quality routes |
| Turn-by-turn engine | Custom NavigationEngine | NavigationKit (OSS) | NavigationKit wraps Mapbox under the hood — incompatible with MapKit-only constraint |
| Bottom sheet | `presentationDetents` | Custom UIKit sheet, third-party libs | Native iOS 16+ API is sufficient. Third-party libs (BottomSheet, etc.) add dependencies with no meaningful benefit on iOS 17+ |

---

## iOS Version Requirements

| API | Minimum iOS | Notes |
|-----|------------|-------|
| `Map` SwiftUI view (new APIs) | iOS 17 | `MapCameraPosition`, `MapPolyline` in Map scope |
| `presentationDetents` | iOS 16 | Project already targets iOS 17+, no issue |
| `presentationBackgroundInteraction` | iOS 16.4 | Project already targets iOS 17+, no issue |
| `ActivityKit` Live Activity | iOS 16.1 | Already in use |
| `SwiftData` | iOS 17 | Already in use |
| `CLLocationUpdate` (modern async) | iOS 17 | Optional — use if refactoring `LocationManager` |

Project targets iOS 17+ — all APIs are available without conditional checks.

---

## Key Architecture Constraint

Apple provides **no public API for offline vector tile streaming or offline routing** on MapKit. This is not a documentation gap — it is intentional. The compliant offline strategy is:

1. `MKMapSnapshotter` for offline map viewing (raster, already implemented)
2. SwiftData-cached `MKRoute` responses for offline navigation (serialize polyline + steps when online)
3. Accept that deep-zoom offline interactivity is not possible with MapKit alone

Any feature spec that requires "full offline interactive map" without third-party SDKs must be scoped to cached snapshots + cached routes only.

---

## Sources

- [Meet MapKit for SwiftUI — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10043/) — HIGH confidence, official
- [MKDirections — Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/mkdirections) — HIGH confidence, official
- [AVSpeechSynthesizer — Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) — HIGH confidence, official
- [CLLocationManager — Apple Developer Documentation](https://developer.apple.com/documentation/corelocation/cllocationmanager) — HIGH confidence, official
- [presentationDetents — Sarunw](https://sarunw.com/posts/swiftui-bottom-sheet/) — MEDIUM confidence, community verified
- [SwiftUI MapKit iOS 17 Missing Features — Medium](https://medium.com/@gerdcastan/swiftui-mapkit-ios-17-the-missing-features-4b08fa42ee9f) — MEDIUM confidence, documents SwiftUI MapKit gaps including MKTileOverlay limitation
- [presentationBackgroundInteraction — Apple Developer Forums](https://developer.apple.com/forums/thread/711702) — MEDIUM confidence, confirmed working pattern
- [Getting Directions in MapKit with SwiftUI — CreateWithSwift](https://www.createwithswift.com/getting-directions-in-mapkit-with-swiftui/) — MEDIUM confidence
- [Core Location Modern API Tips — TwoCentStudios](https://twocentstudios.com/2024/12/02/core-location-modern-api-tips/) — MEDIUM confidence, 2024 post
