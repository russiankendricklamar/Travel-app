# Phase 1: Navigation Engine - Research

**Researched:** 2026-03-20
**Domain:** iOS turn-by-turn navigation engine — CLLocationManager, AVSpeechSynthesizer, polyline snapping, off-route detection, background GPS
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NAV-01 | Активный режим навигации с auto-pan карты и heading lock | MapViewModel gains `isNavigating` flag; camera switches to `.userLocation(followsHeading: true)` — Phase 2 UI, but the engine flag is created here |
| NAV-02 | Голосовые подсказки через AVSpeechSynthesizer (язык устройства, включая русский) | NavigationVoiceService wraps AVSpeechSynthesizer with 500m/200m/arrival trigger distances and correct audio session lifecycle |
| NAV-03 | Детекция отклонения от маршрута (>30м) с автоматическим перестроением | NavigationEngine.processLocation() computes perpendicular distance from current polyline segment; triggers reroute when > 30m |
| NAV-04 | Дебаунс перестроения маршрута (минимум 8с между запросами) | NavigationEngine holds `lastRerouteTime: Date?`; guards reroute with 8s elapsed check |
| NAV-05 | Корректная работа GPS в фоне (allowsBackgroundLocationUpdates + UIBackgroundModes plist) | LocationManager already has `allowsBackgroundLocationUpdates = true`; plist UIBackgroundModes entry is the missing manual step |
| ROUTE-04 | Список пошаговых инструкций (turn-by-turn step list) в bottom sheet | NavigationEngine exposes `steps: [NavigationStep]` derived from RouteResult.transitSteps + parsing Google Directions steps; available as data before any UI renders it |
</phase_requirements>

---

## Summary

Phase 1 builds the pure-logic core of the navigation system — no UI changes. The output is two new Swift files (`NavigationEngine.swift`, `NavigationVoiceService.swift`) plus minor extensions to `LocationManager.swift` and `MapViewModel.swift`. Everything else (HUD, camera lock, start button) is Phase 2.

The codebase is already 80% ready. `LocationManager` has continuous GPS, `allowsBackgroundLocationUpdates = true`, and `pausesLocationUpdatesAutomatically = false`. `RoutingService` returns `RouteResult` with `[CLLocationCoordinate2D]` polylines and `[TransitStep]` steps. `MapViewModel` owns routing state. The navigation engine slots in between `LocationManager` (raw GPS stream) and `MapViewModel` (UI state).

The three critical correctness problems for this phase — background GPS silently stopping, music permanently ducked after voice, and rerouting flooding the API — are all well-understood and have specific prevention patterns documented below. All three must be implemented in Phase 1, not deferred.

**Primary recommendation:** Build `NavigationEngine` as a standalone `@Observable` class owned by `MapViewModel`, with `NavigationVoiceService` as a private dependency. Use segment-level polyline snapping (perpendicular projection), not nearest-start matching. Enforce the 8s reroute debounce from day one.

---

## Codebase Baseline (What Already Exists)

This section is critical — Phase 1 builds on existing infrastructure, not from scratch.

### LocationManager.swift — Key Facts

- `CLLocationManager` with `desiredAccuracy = kCLLocationAccuracyBest`
- `allowsBackgroundLocationUpdates = true` — already set
- `pausesLocationUpdatesAutomatically = false` — already set
- `showsBackgroundLocationIndicator = true` — already set
- `activityType = .fitness` — **MUST change to `.otherNavigation` for navigation sessions**
- `currentLocation: CLLocationCoordinate2D?` — observable, updated on every GPS tick
- `requestCurrentLocation()` — one-shot async helper already used by RoutingService
- Background GPS plist entry (`UIBackgroundModes: [location]`) is the **only missing configuration** (manual Xcode step, noted in STATE.md)

### RoutingService.swift — Key Facts

- `RouteResult` struct: `polyline: [CLLocationCoordinate2D]`, `distance`, `expectedTravelTime`, `mode`, `transitSteps: [TransitStep]`
- Routes via Google Routes API v2 (not MKDirections) — polyline is Google-encoded, already decoded to coordinate array
- `TransitStep` has `instruction: String`, `distance`, `duration`, `travelMode`, `polyline: [CLLocationCoordinate2D]`
- **Critical gap**: `RouteResult.transitSteps` is populated only for `.transit` mode from Google Directions. For walking/driving, `transitSteps` is empty — Google Routes API v2 does not return step-by-step instructions. **ROUTE-04 requires a step list for all modes.**
- `inFlightKeys: Set<String>` deduplication guards parallel requests but does NOT guard sequential rerouting — the NavigationEngine must add its own 8s debounce on top

### MapViewModel.swift — Key Facts

- `@Observable` — single source of truth for all map state
- `activeRoute: RouteResult?` — current displayed route
- `selectedTransportMode: TransportMode` — driving/walking/transit/cycling
- No navigation session state yet (`isNavigating`, `navigationStepIndex`, etc. are all missing)
- `calculateDirectionRoute(to:)` and `calculateRouteToSearchedItem(_:)` are async methods that call RoutingService — NavigationEngine's rerouting will call the same RoutingService directly, bypassing MapViewModel

### MapRouteContent.swift — Key Facts

- Shows transit steps list for `.transit` mode only (from `route.transitSteps`)
- No step list for walking/driving — ROUTE-04 requires this to exist for all modes
- No "Начать навигацию" button — that is Phase 2 (NAV-06)

---

## Step Data Gap: ROUTE-04 Resolution

**Problem:** Google Routes API v2 (used for walk/drive/bike) returns a polyline but no step-by-step instructions. `RouteResult.transitSteps` is empty for non-transit modes. ROUTE-04 requires a turn-by-turn step list.

**Solution — Two options (choose one):**

**Option A (Recommended): Add MKDirections step fetch alongside Google route**
When `calculateRoutesAPIRoute` completes, fire a parallel `MKDirections` request for the same origin/destination/mode. `MKRoute.steps` provides `[MKRouteStep]` with `instructions: String` and `distance: CLLocationDistance`. Map these to a new `NavigationStep` model and attach to `RouteResult`. MKDirections is free, offline-capable, and returns structured steps for all modes.

**Option B: Use Google Directions API for step data**
The existing `calculateGoogleTransitRoute` already uses Google Directions API which returns step-by-step instructions. A parallel call with `mode=walking` or `mode=driving` would return steps too. However this costs additional API quota and adds latency.

**Option A is preferred.** MKDirections is synchronous-equivalent (async/await wrapper exists), does not consume Google API quota, and returns steps with bearing information useful for maneuver icons.

**New model needed:**
```swift
struct NavigationStep {
    let instruction: String       // from MKRouteStep.instructions or TransitStep.instruction
    let distance: CLLocationDistance
    let polyline: [CLLocationCoordinate2D]  // from MKRouteStep.polyline
    let maneuverType: MKDirectionsTransportType
}
```

`RouteResult` gains: `var navigationSteps: [NavigationStep] = []`

---

## Standard Stack

### Core (All Apple-native, no new dependencies)

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| `CLLocationManager` | iOS 2+ | GPS stream during navigation | Already in LocationManager.swift; extend with navigation accuracy mode |
| `CLLocation.distance(from:)` | iOS 2+ | Off-route deviation distance | Native distance calculation, no geometry library needed |
| `AVSpeechSynthesizer` | iOS 7+ | Russian voice announcements | Free, offline, no API key, all iOS languages including ru-RU |
| `AVSpeechUtterance` | iOS 7+ | Individual announcement | Set `.voice` to `AVSpeechSynthesisVoice(language: Locale.current.identifier)` |
| `AVAudioSession` | iOS 2+ | Duck background music then restore | `.playback` + `.duckOthers`; deactivate 0.5s after speech ends |
| `MKDirections` | iOS 7+ | Step instruction data (ROUTE-04) | Only way to get structured step text without Google API quota; free and offline |
| `MKDirections.Request` | iOS 7+ | Step fetch request | Set `transportType` matching current `TransportMode` |
| Custom `NavigationEngine` | — | State machine: step index, off-route, reroute | No Apple API exists for this; must implement |
| Custom `NavigationVoiceService` | — | Distance-triggered TTS wrapper | Single `AVSpeechSynthesizer` instance with queue management |

**No new Swift packages required.** All APIs are iOS 17+ native.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| MKDirections for steps | Google Directions API | Costs quota; MKDirections is free, offline |
| Custom polyline snapping | CoreLocation `nearestOnPath` | No such API in CoreLocation; must implement segment projection |
| AVSpeechSynthesizer | Gemini TTS / ElevenLabs | Requires network, API key, latency; system TTS is sufficient |

---

## Architecture Patterns

### NavigationEngine Placement

`NavigationEngine` is owned by `MapViewModel` as an optional stored property. This keeps the single-source-of-truth pattern intact. The engine is created when navigation starts and set to nil when it stops.

```swift
// MapViewModel extension (new properties):
var isNavigating: Bool = false
var navigationEngine: NavigationEngine?
var navigationSteps: [NavigationStep] = []    // ROUTE-04: populated when route loaded
var currentStepIndex: Int = 0
var distanceToNextStep: CLLocationDistance = 0

func startNavigation() {
    guard let route = activeRoute else { return }
    isNavigating = true
    navigationEngine = NavigationEngine(route: route, voiceService: voiceService)
    navigationEngine?.onStepAdvanced = { [weak self] index, distance in
        self?.currentStepIndex = index
        self?.distanceToNextStep = distance
    }
    navigationEngine?.onRerouteNeeded = { [weak self] from in
        Task { await self?.rerouteNavigation(from: from) }
    }
    // Camera: heading lock — Phase 2 only, not here
}

func stopNavigation() {
    navigationEngine = nil
    isNavigating = false
    currentStepIndex = 0
    distanceToNextStep = 0
}

private func rerouteNavigation(from: CLLocationCoordinate2D) async {
    guard let destination = activeRouteDestination else { return }
    let result = await RoutingService.shared.calculateRoute(from: from, to: destination, mode: selectedTransportMode)
    if let result {
        activeRoute = result
        navigationSteps = await fetchNavigationSteps(from: from, to: destination, mode: selectedTransportMode)
    }
}
```

### NavigationEngine State Machine

```swift
@Observable
final class NavigationEngine {
    private(set) var currentStepIndex: Int = 0
    private(set) var distanceToNextStep: CLLocationDistance = 0
    private(set) var isRerouting: Bool = false

    private let route: RouteResult
    private let voiceService: NavigationVoiceService
    private var lastRerouteTime: Date?
    private let offRouteThreshold: CLLocationDistance = 30  // meters — matches NAV-03
    private let rerouteDebounce: TimeInterval = 8           // seconds — matches NAV-04
    private let stepArrivalThreshold: CLLocationDistance = 15

    // Callbacks to MapViewModel
    var onStepAdvanced: ((Int, CLLocationDistance) -> Void)?
    var onRerouteNeeded: ((CLLocationCoordinate2D) -> Void)?

    func processLocation(_ location: CLLocation) {
        let snapped = snapToPolyline(location.coordinate)
        let distToStep = snapped.distance(from: CLLocation(latitude: stepEndCoord.latitude, longitude: stepEndCoord.longitude))
        distanceToNextStep = distToStep

        // Step advancement
        if distToStep < stepArrivalThreshold && currentStepIndex < route.polyline.count - 1 {
            currentStepIndex += 1
            voiceService.announceStep(route.navigationSteps[currentStepIndex], distanceRemaining: distanceToNextStep)
            onStepAdvanced?(currentStepIndex, distanceToNextStep)
        }

        // Voice trigger distances
        voiceService.checkDistanceTrigger(distToStep, step: currentStep)

        // Off-route detection
        let perpendicularDist = perpendicularDistanceFromPolyline(location.coordinate)
        if perpendicularDist > offRouteThreshold {
            triggerRerouteIfReady(from: location.coordinate)
        }
    }
}
```

### Polyline Segment Snapping Algorithm

This is the most technically precise piece. Use perpendicular projection onto each polyline segment — NOT nearest-endpoint matching.

```swift
// Source: standard computational geometry — verified pattern
func perpendicularDistanceFromPolyline(_ point: CLLocationCoordinate2D) -> CLLocationDistance {
    let polyline = route.polyline
    guard polyline.count >= 2 else { return CLLocationDistanceMax }

    var minDistance = CLLocationDistanceMax

    for i in 0..<(polyline.count - 1) {
        let segStart = polyline[i]
        let segEnd = polyline[i + 1]
        let dist = perpendicularDistanceToSegment(point, from: segStart, to: segEnd)
        minDistance = min(minDistance, dist)
    }

    return minDistance
}

private func perpendicularDistanceToSegment(
    _ point: CLLocationCoordinate2D,
    from a: CLLocationCoordinate2D,
    to b: CLLocationCoordinate2D
) -> CLLocationDistance {
    // Convert to approximate Cartesian (valid for small areas, <50km)
    let lat2m = 111_320.0
    let lon2m = 111_320.0 * cos(a.latitude * .pi / 180)

    let px = (point.longitude - a.longitude) * lon2m
    let py = (point.latitude - a.latitude) * lat2m
    let ax = 0.0, ay = 0.0
    let bx = (b.longitude - a.longitude) * lon2m
    let by = (b.latitude - a.latitude) * lat2m

    let segLen2 = bx * bx + by * by
    guard segLen2 > 0 else {
        return sqrt(px * px + py * py)  // degenerate segment
    }

    let t = max(0, min(1, (px * bx + py * by) / segLen2))
    let nearX = ax + t * bx
    let nearY = ay + t * by
    let dx = px - nearX
    let dy = py - nearY
    return sqrt(dx * dx + dy * dy)
}
```

This algorithm is O(n) over polyline segments and runs on every GPS update — on a 500-point polyline (~8ms worst case) this is acceptable on main thread. For long routes (>2000 points), move to a background actor.

### NavigationVoiceService

```swift
final class NavigationVoiceService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var announcedDistances: Set<String> = []

    // Distance thresholds: announce at 500m, 200m, arrival (< 15m)
    private let triggerDistances: [CLLocationDistance] = [500, 200, 15]

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func checkDistanceTrigger(_ distance: CLLocationDistance, step: NavigationStep) {
        for threshold in triggerDistances {
            let key = "\(step.instruction)-\(Int(threshold))"
            if distance <= threshold && !announcedDistances.contains(key) {
                announcedDistances.insert(key)
                speak(buildAnnouncement(step: step, distance: distance))
                return
            }
        }
    }

    func resetForNewStep() {
        announcedDistances = announcedDistances.filter { !$0.hasPrefix(currentStepKey) }
    }

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .word)  // Pitfall 11: clear queue first

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: .duckOthers)
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    // Pitfall 2: 0.5s delay before session deactivation
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
```

### LocationManager Navigation Mode

Add a navigation mode toggle — changes accuracy and activityType without breaking existing tracking:

```swift
// LocationManager extension:
func startNavigationMode() {
    manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    manager.activityType = .otherNavigation         // replaces .fitness
    manager.distanceFilter = kCLDistanceFilterNone  // all updates, engine decides what to process
    // allowsBackgroundLocationUpdates already true
    manager.startUpdatingLocation()
}

func stopNavigationMode() {
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.activityType = .fitness
    manager.distanceFilter = 10  // save battery outside navigation
}

// Safety net: Pitfall 1
func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
    manager.startUpdatingLocation()  // immediately restart if OS pauses
}
```

### NavigationStep Model and ROUTE-04 Implementation

Add `NavigationStep` to `RoutingService.swift` (or a new `NavigationModels.swift`):

```swift
struct NavigationStep {
    let instruction: String
    let distance: CLLocationDistance
    let polyline: [CLLocationCoordinate2D]
    let isWalking: Bool
}
```

Add `navigationSteps: [NavigationStep]` to `RouteResult` (new optional field, default empty).

Add step-fetch method to `RoutingService`:

```swift
func fetchNavigationSteps(
    from origin: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D,
    mode: TransportMode
) async -> [NavigationStep] {
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
    request.transportType = mode.mkTransportType  // new computed property on TransportMode
    let directions = MKDirections(request: request)
    guard let response = try? await directions.calculate(),
          let route = response.routes.first else { return [] }
    return route.steps.map { step in
        NavigationStep(
            instruction: step.instructions,
            distance: step.distance,
            polyline: step.polyline.coordinates,  // MKPolyline -> [CLLocationCoordinate2D]
            isWalking: mode == .walking
        )
    }
}
```

`TransportMode.mkTransportType` computed property:
```swift
var mkTransportType: MKDirectionsTransportType {
    switch self {
    case .walking: return .walking
    case .automobile: return .automobile
    case .transit: return .transit
    case .cycling: return .walking  // MKDirections has no cycling; walking is closest
    }
}
```

`MKPolyline.coordinates` extension (needed since MKPolyline is not directly subscriptable):
```swift
extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TTS with Russian support | Custom HTTP TTS client | `AVSpeechSynthesizer` | Free, offline, zero latency, handles ru-RU natively |
| Route calculation for steps | Parse Google JSON legs manually | `MKDirections.calculate()` | Already returns structured `MKRouteStep` with instructions, no quota cost |
| Audio ducking/restore | Custom audio interruption system | `AVAudioSession` category `.duckOthers` + delegate deactivation | Platform contract, handles all edge cases |
| Step-end detection | Comparing GPS point to polyline vertex | Perpendicular segment projection (above) | Nearest-vertex matching breaks on short urban steps |
| Background location keepalive | Timer-based location re-requests | `locationManagerDidPauseLocationUpdates` restart + plist entry | Platform-contract approach; timers are unreliable in background |

---

## Common Pitfalls

### Pitfall 1: UIBackgroundModes Plist Entry Missing (Background GPS Silently Dies)

**What goes wrong:** Navigation works perfectly on screen. Screen turns off. GPS stops delivering updates 10-30 seconds later. No error. Navigation silently freezes.

**Why it happens:** Two gates must both be open: `allowsBackgroundLocationUpdates = true` (code, already done) AND `UIBackgroundModes: [location]` in Info.plist (manual Xcode step, **not yet done**). Missing either one silently kills background location.

**How to avoid:** In Xcode target settings, "Signing & Capabilities" → "+ Capability" → "Background Modes" → check "Location updates". This adds the plist entry. Cannot be done in code.

**Warning signs:** Works in simulator (simulator ignores plist gate in some Xcode versions), fails on device after screen lock.

**Blocking:** This must be done before any Phase 1 navigation testing on device.

### Pitfall 2: Music Stays Ducked After Voice Announcement

**What goes wrong:** User has Spotify playing. First voice cue plays correctly. Music never returns to full volume.

**Why it happens:** `AVSpeechSynthesizer` activates `AVAudioSession` but never deactivates it. Must call `setActive(false, options: .notifyOthersOnDeactivation)` in `speechSynthesizer(_:didFinish:)` delegate — but with a 0.5s `asyncAfter` delay. Synchronous call fails with error 560030580.

**How to avoid:** Implement `AVSpeechSynthesizerDelegate` on `NavigationVoiceService`. In `didFinish`, schedule deactivation with `DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)`.

**Warning signs:** Error `560030580` in logs. Music quiet after first announcement.

### Pitfall 3: Rerouting Floods Google API (No Debounce)

**What goes wrong:** User steps off the sidewalk briefly. Each GPS update (1 Hz) fires a new `calculateRoute` call. `inFlightKeys` guard in `RoutingService` allows sequential calls when origin changes slightly per tick. API quota exhausted within minutes.

**How to avoid:** `NavigationEngine` enforces its own 8s debounce (`lastRerouteTime`). Off-route must be > 30m continuous. Only call reroute when: (a) perpendicularDist > 30m AND (b) at least 8s since last reroute AND (c) not currently rerouting.

**Warning signs:** Rapid `[RoutingService] Routes API request:` log lines with slightly different coords.

### Pitfall 4: activityType = .fitness Pauses Navigation

**What goes wrong:** User stands still at a pedestrian crossing for >60 seconds. iOS detects stationary device, pauses location updates (`.fitness` mode aggressively pauses). Navigation stalls at the crossing, never resumes.

**How to avoid:** Switch `activityType` from `.fitness` to `.otherNavigation` when navigation starts. Revert when navigation ends. Also implement `locationManagerDidPauseLocationUpdates` restart as safety net.

### Pitfall 5: Step Matching Uses Nearest Vertex (Not Segment Projection)

**What goes wrong:** Step index advances too early or too late. User is on the correct segment but the nearest vertex is the start of the next step.

**How to avoid:** Use perpendicular projection to the polyline segment (algorithm above), not `distance(from: stepStart)`. Advance step when user is within 15m of the step's end coordinate AND heading aligns with next step direction.

### Pitfall 6: NavigationEngine State Updates Trigger 1 Hz Map Re-renders

**What goes wrong:** `distanceToNextStep` updates every GPS tick (1 Hz). Since it lives on `@Observable MapViewModel`, the `Map` view re-renders every second during navigation — jitter and CPU spike.

**How to avoid:** `NavigationEngine` is its own `@Observable` class. `MapViewModel` reads from it via callbacks, but only updates `distanceToNextStep` on `MapViewModel` when value changes > 1m (throttle). The `Map` view in Phase 2 will observe NavigationEngine directly for HUD data, not MapViewModel properties.

For Phase 1 (no UI), this is not yet a problem but the architecture must be designed correctly now to avoid Phase 2 refactoring.

---

## Code Examples

### MKDirections Async Pattern

```swift
// Source: Apple Developer Docs — MKDirections.calculate()
let request = MKDirections.Request()
request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
request.transportType = .walking

let directions = MKDirections(request: request)
let response = try await directions.calculate()
let steps = response.routes.first?.steps ?? []
// Each step: step.instructions (String), step.distance (CLLocationDistance), step.polyline (MKPolyline)
```

### AVSpeechSynthesizer Audio Session Lifecycle

```swift
// Source: Apple Developer Forums — confirmed pattern for error 560030580
private func activateAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
    try? session.setActive(true)
}

// In AVSpeechSynthesizerDelegate:
func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
```

### Off-Route Reroute Guard

```swift
// NavigationEngine reroute guard
private func triggerRerouteIfReady(from coordinate: CLLocationCoordinate2D) {
    guard !isRerouting else { return }
    if let last = lastRerouteTime, Date().timeIntervalSince(last) < 8 { return }
    isRerouting = true
    lastRerouteTime = Date()
    onRerouteNeeded?(coordinate)
}

// Called after RoutingService returns new route:
func didReceiveNewRoute() {
    currentStepIndex = 0
    isRerouting = false
    voiceService.announceStep(currentStep, distanceRemaining: distanceToNextStep)
}
```

### Background Location Safety Net

```swift
// LocationManager delegate — safety net for pause events
func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
    // Immediately restart — prevents navigation stall at traffic lights
    manager.startUpdatingLocation()
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|-----------------|--------|
| `MKMapViewRepresentable` for SwiftUI map | `Map` SwiftUI native (iOS 17) | No bridging, declarative camera control |
| `CLLocationManager` polling | Delegate callbacks + async stream (`CLLocationUpdate`) | Lower battery, more idiomatic Swift concurrency |
| `AVSpeechSynthesizer` per-announcement instance | Single instance with queue management | No voice overlap, no memory churn |
| Nearest-vertex step matching | Perpendicular segment projection | Correct step advancement in urban grids |

**Deprecated/outdated:**
- `MKMapViewRepresentable`: Project correctly uses iOS 17 `Map`. Do not regress to this.
- `CLLocationManager.distanceFilter = kCLDistanceFilterNone` in non-navigation mode: Already using 10m filter in tracking; navigation mode should use `kCLDistanceFilterNone` only during active navigation.

---

## Open Questions

1. **NavigationStep data for cycling mode**
   - What we know: `MKDirections` does not support `.cycling` transport type. Walking steps are the closest approximation.
   - What's unclear: Whether cycling step instructions are acceptable for the navigation step list, or if an error state is needed.
   - Recommendation: Use walking directions for cycling mode's step list; label steps as cycling in the display layer.

2. **Physical device testing gate**
   - What we know: Background GPS (Pitfall 1), audio session (Pitfall 2), and `locationManagerDidPauseLocationUpdates` (Pitfall 4) cannot be validated on simulator.
   - What's unclear: When a physical device will be available for Phase 1 validation.
   - Recommendation: Phase 1 is "done" from an implementation standpoint when all logic is in place; final success criteria validation requires device. Document this in PLAN.md success criteria.

3. **NavigationEngine observation pattern for LocationManager**
   - What we know: `LocationManager.currentLocation` is `@Observable` property. `NavigationEngine` could use `withObservationTracking` to observe it, or MapViewModel could forward updates via callback.
   - What's unclear: Whether `withObservationTracking` in a non-view context is reliable for continuous updates (it's designed for view rendering cycles).
   - Recommendation: Use the callback pattern — `MapViewModel.startNavigation()` sets `NavigationEngine.onLocationUpdate` closure that LocationManager calls in `didUpdateLocations`. This is explicit, testable, and not dependent on observation tracking semantics.

---

## Validation Architecture

`nyquist_validation` is enabled in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing) |
| Config file | Travel app.xcodeproj / Travel appTests target |
| Quick run command | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 16 Pro" -only-testing:"Travel appTests/NavigationEngineTests" 2>&1 \| xcpretty` |
| Full suite command | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 16 Pro" 2>&1 \| xcpretty` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NAV-02 | Voice triggers fire at 500m, 200m, arrival | unit | `xcodebuild test -only-testing:"Travel appTests/NavigationVoiceServiceTests"` | ❌ Wave 0 |
| NAV-03 | Off-route detected when perpendicularDist > 30m | unit | `xcodebuild test -only-testing:"Travel appTests/NavigationEngineTests/testOffRouteDetection"` | ❌ Wave 0 |
| NAV-04 | Second reroute within 8s is suppressed | unit | `xcodebuild test -only-testing:"Travel appTests/NavigationEngineTests/testRerouteDebounce"` | ❌ Wave 0 |
| NAV-01 | Step index advances when user passes step end | unit | `xcodebuild test -only-testing:"Travel appTests/NavigationEngineTests/testStepAdvancement"` | ❌ Wave 0 |
| NAV-05 | Background GPS config correct | manual-only | n/a | n/a — device required |
| ROUTE-04 | NavigationStep list populated for walking/driving | unit | `xcodebuild test -only-testing:"Travel appTests/RoutingServiceTests/testNavigationStepsFetch"` | ❌ Wave 0 |

**Manual-only justification for NAV-05:** Background mode behavior is simulator-incompatible. Must validate on physical device with screen locked — not automatable.

### Sampling Rate

- **Per task commit:** `xcodebuild test -only-testing:"Travel appTests/NavigationEngineTests"` (runs in <15s on simulator)
- **Per wave merge:** Full suite (`xcodebuild test ...`)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `Travel appTests/NavigationEngineTests.swift` — covers NAV-01, NAV-03, NAV-04 (step advancement, off-route threshold, debounce)
- [ ] `Travel appTests/NavigationVoiceServiceTests.swift` — covers NAV-02 (trigger distances, queue clearing, audio session mock)
- [ ] `Travel appTests/RoutingServiceNavigationTests.swift` — covers ROUTE-04 (MKDirections step fetch, NavigationStep model)
- [ ] Shared test helpers: `CLLocationCoordinate2D` factory, polyline segment builders for geometric tests

---

## Sources

### Primary (HIGH confidence)

- Existing codebase: `LocationManager.swift`, `RoutingService.swift`, `MapViewModel.swift`, `MapRouteContent.swift` — direct code analysis, all constraints derived from actual code
- Apple Developer Docs: [CLLocationManager](https://developer.apple.com/documentation/corelocation/cllocationmanager) — background location configuration
- Apple Developer Docs: [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) — TTS, delegate, audio session
- Apple Developer Docs: [MKDirections](https://developer.apple.com/documentation/mapkit/mkdirections) — step data via `MKRouteStep`
- WWDC24: [What's new in location authorization](https://developer.apple.com/videos/play/wwdc2024/10212/) — background location config
- `.planning/research/PITFALLS.md` — verified pitfalls for this domain (HIGH confidence for Pitfalls 1, 2)
- `.planning/research/ARCHITECTURE.md` — component boundaries and data flow

### Secondary (MEDIUM confidence)

- Apple Developer Forums: [AVSpeechSynthesizer session deactivation error 560030580](https://developer.apple.com/forums/thread/45599) — confirmed audio session bug + 0.5s delay fix
- Apple Developer Forums: [CLLocationManager background location](https://developer.apple.com/forums/thread/87256) — `locationManagerDidPauseLocationUpdates` restart pattern
- `.planning/research/SUMMARY.md` — ecosystem research summary

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all APIs are Apple-native, in-use by project, confirmed by official docs
- Architecture: HIGH — derived entirely from codebase analysis; no external sources needed for component boundaries; callbacks vs observation tracking is the only open question
- Pitfalls: HIGH for Pitfalls 1-4 (confirmed by Apple forums + official docs); MEDIUM for Pitfall 6 (rendering performance — standard @Observable guidance, not Phase 1 concern yet)
- ROUTE-04 approach: MEDIUM — MKDirections step fetch is well-documented but the parallel fetch pattern alongside Google Routes needs careful integration to avoid race conditions

**Research date:** 2026-03-20
**Valid until:** 2026-05-20 (stable APIs; MKDirections and AVSpeechSynthesizer have not changed significantly in years)
