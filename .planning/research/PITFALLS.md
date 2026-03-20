# Domain Pitfalls: MapKit Navigation on iOS

**Domain:** iOS turn-by-turn navigation, offline maps, Apple Maps-style UI
**Project:** Travel App — Map Navigation Overhaul
**Researched:** 2026-03-20
**Confidence:** MEDIUM-HIGH (verified against Apple Developer Forums, official docs, community post-mortems)

---

## Critical Pitfalls

Mistakes that cause rewrites, App Store rejections, or navigation that simply stops working.

---

### Pitfall 1: Background Location Silently Killed During Navigation

**What goes wrong:** Navigation audio cues stop mid-route. The user's dot stops moving on the map. No crash, no error — the OS just stops delivering location updates.

**Why it happens:** Two separate configuration gates must both be open:
1. `CLLocationManager.allowsBackgroundLocationUpdates = true` in code
2. `UIBackgroundModes: [location]` in `Info.plist` (must be added in Xcode target settings under "Signing & Capabilities" → Background Modes)

Missing either one means location updates are suspended the moment the app goes to background. The plist entry is commonly forgotten because it is not a code change.

Additionally, `activityType` must be set correctly. When set to `.automotiveNavigation` or `.otherNavigation`, iOS pauses location when the device becomes stationary — **but does not automatically restart it**. If the user stops at a traffic light and the system pauses, navigation never resumes.

**Consequences:** Rerouting never triggers because no new location comes in. Voice cues stop. App appears frozen to the user.

**Prevention:**
- Set `activityType = .otherNavigation` (covers walking, transit, cycling, driving without auto-pause risk)
- Set `pausesLocationUpdatesAutomatically = false` for active navigation sessions
- Set `allowsBackgroundLocationUpdates = true` only when navigation is active; clear it when navigation ends
- Add `UIBackgroundModes: [location]` to `Info.plist` — this is the step most commonly missed
- In `CLLocationManagerDelegate.locationManagerDidPauseLocationUpdates(_:)`, immediately call `startUpdatingLocation()` again as a safety net

**Warning signs:**
- Navigation works perfectly in simulator (background mode behaves differently)
- Navigation works with screen on but fails after ~10 seconds of screen off
- No `locationManager(_:didFailWithError:)` calls during the failure

**Phase:** Background location + rerouting phase. Must be tested on physical device, not simulator.

---

### Pitfall 2: AVSpeechSynthesizer Ducks Music Permanently (Audio Session Not Deactivated)

**What goes wrong:** After a voice cue plays, Spotify/Apple Music stays at 30% volume permanently. No crash. The synthesizer spoke, job done — but it activated the audio session and never deactivated it, leaving every other audio source ducked.

**Why it happens:** `AVSpeechSynthesizer` activates the `AVAudioSession` on its own when speaking. It does NOT deactivate it when done. If the app does not explicitly call `AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)` after speech ends, the session stays active and ducks everything else.

Calling `setActive(false)` immediately from the synthesizer delegate also fails with error `560030580` ("Session deactivation failed") if called synchronously — the synthesizer internally holds the session open briefly after the delegate fires.

**Consequences:** User's music stays ducked for the duration of navigation, or until app is killed. Very visible UX bug.

**Prevention:**
```swift
// After speaking ends:
func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                        didFinish utterance: AVSpeechUtterance) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}
```
- Use `AVAudioSession.Category.playback` with `.duckOthers` option while speaking; deactivate after
- Set `usesApplicationAudioSession = true` on the synthesizer (the default) so the app controls the session
- Do NOT set `usesApplicationAudioSession = false` — this prevents ducking control entirely

**Warning signs:**
- Music plays quietly and never returns to full volume after first voice cue
- The bug only occurs when background audio (music) is already playing
- Deactivation error `560030580` in logs

**Phase:** Voice guidance implementation phase. Test with background music playing on physical device.

---

### Pitfall 3: MKMapSnapshotter Does Not Provide Offline Map Tiles

**What goes wrong:** The app calls `MKMapSnapshotter` to "cache" the map for offline use. The user goes offline in Tokyo. The map is blank. The snapshots are static images — they cannot be zoomed or panned.

**Why it happens:** `MKMapSnapshotter` produces a static `UIImage` of a map region at a fixed zoom level. It is not a tile cache. Zooming in on the snapshot degrades it. Panning is impossible. Apple Maps tiles themselves are served by Apple's CDN and have no public API for bulk offline download.

The `NSURLCache` that MapKit uses to store tiles is not guaranteed to persist. Cache eviction can remove tiles at any time. There is no contract for offline availability.

**Consequences:** The feature listed in PROJECT.md — "полный офлайн: предзагрузка карт региона" — cannot be delivered with `MKMapSnapshotter` alone as an interactive map.

**Prevention:**
- Use `MKMapSnapshotter` only for static thumbnail previews (e.g. trip overview cards), not interactive navigation
- For interactive offline maps: cache pre-built route polylines as `Codable` coordinate arrays in SwiftData; display them as overlays on a `Map` view that gracefully degrades when tiles fail to load
- Pre-calculate and cache routes (`RouteResult`) for planned itinerary legs before the user travels
- Accept that offline map tiles are a platform limitation — document this honestly for users: "маршруты сохранены, тайлы карты зависят от подключения"

**Warning signs:**
- Any plan that says "cache map tiles offline with MKMapSnapshotter for interactive use"
- Assuming Apple Maps tile cache survives memory pressure or app restarts

**Phase:** Offline caching phase. The architecture decision must be made before implementation starts, not after.

---

### Pitfall 4: Rerouting Floods the API with Repeated Route Calculations

**What goes wrong:** The user deviates 5 meters from the route. Rerouting triggers. They walk back on route. Rerouting triggers again. Within 30 seconds, 15 API calls go to the Google Routes proxy. Rate limits hit. Navigation dies.

**Why it happens:** The naive implementation calls `calculateRoute()` on every `CLLocation` update that is off-route. `CLLocationManager` can fire 1 Hz or faster. Without debouncing, a single deviation causes a cascade.

The existing `RoutingService` has an `inFlightKeys` deduplication guard, but it only prevents parallel duplicates for the same cache key. If the origin shifts slightly each update, the cache key changes, defeating deduplication.

**Consequences:** Google Routes API quota exhausted. Navigation becomes unresponsive. Supabase Edge Function throttled.

**Prevention:**
- Only trigger rerouting when the user is off-route by more than a meaningful threshold (20–50m for walking, 100m for driving)
- Debounce rerouting: no new request for at least 8–10 seconds after the last reroute
- Snap the origin coordinate to the nearest route step start (prevents cache-key churn from GPS jitter)
- Use `CLLocationManager.distanceFilter = kCLDistanceFilterNone` only during active navigation; use `distanceFilter = 10` (meters) otherwise

**Warning signs:**
- Rapid repeated log entries: `[RoutingService] Routes API request: ...` with slightly different origin coords
- API calls spike during navigation sessions
- Battery drain during navigation is unusually high

**Phase:** Rerouting implementation phase. Rate limiting must be built before the first reroute test.

---

### Pitfall 5: `@Observable` MapViewModel Causes Excessive Map Re-renders During Navigation

**What goes wrong:** During active navigation, the map view flickers or lags. Every location update mutates state on `MapViewModel`, which triggers full SwiftUI body re-evaluation on the `Map` view — including re-laying out polylines, re-pinning annotations, and re-computing camera position.

**Why it happens:** `@Observable` is granular about property access, but a `Map` view that reads `cameraPosition`, `activeRoute`, and annotation arrays all from the same `@Observable` object will re-render whenever any of those change. Location updates during navigation change position frequently (1 Hz), hitting this path on every tick.

**Consequences:** Visible map stutter at 1 Hz. High CPU during navigation. Battery drain. Degraded rendering on older devices.

**Prevention:**
- Extract navigation-specific state (current step index, distance to next maneuver, voice queue) into a separate `NavigationSessionState` struct or `@Observable` class
- Only update `cameraPosition` when the user has moved more than 5m, not on every location tick
- Use `MapPolyline` with stable identity — do not recreate the entire polyline array on each update
- The camera auto-follow during navigation should animate to the next waypoint, not the raw GPS coordinate (reduces jitter)

**Warning signs:**
- CPU usage >40% during navigation in Instruments
- Map view re-renders visible via "Debug View Hierarchy" flashes
- `zoomToRoute` called more than once per second in logs

**Phase:** Navigation session UI phase. Profile with Instruments before considering it done.

---

## Moderate Pitfalls

---

### Pitfall 6: Step-Matching Logic Misidentifies Current Step

**What goes wrong:** The turn-by-turn instruction says "Turn left in 50m" but the user already turned 200m ago and is on the next street. The step counter is stuck.

**Why it happens:** Matching the current location to the correct route step requires more than "distance to step start." The simplest approach — find the nearest step start point — fails when steps are short (urban grid) or when GPS drifts to an adjacent street. The correct approach is to find the nearest point on the entire step polyline, then advance when the user passes the step's end point.

**Prevention:**
- Implement segment-level snapping: for each route step's polyline, find the closest segment, compute the perpendicular projection, and use that as the snapped position
- Advance to the next step when: (a) user is within 15m of the step end coordinate AND (b) heading toward the next step start (dot-product check)
- Fall back to rerouting if no step matches within 50m

**Phase:** Step-by-step instruction phase.

---

### Pitfall 7: Transit Mode Unavailability Treated as a Hard Error

**What goes wrong:** The user requests transit directions in a city where Google Directions has no transit data (many cities in Central Asia, Africa, parts of Eastern Europe). The app shows a generic "Маршрут не найден" error and offers nothing.

**Why it happens:** The `RoutingService` correctly detects `transitUnavailableRegion` but the fallback (JapanTransitService / AI routing) is Japan-specific. For most of the world, both paths fail.

**Prevention:**
- When transit is unavailable, automatically show walking or driving ETA as a fallback with a clear explanation: "ОТ недоступен в этом регионе — показан пешеходный маршрут"
- Offer the "Open in Apple Maps" deep-link as a last resort (already implemented in `RoutingService.openAppleMapsTransit`)
- Never show a blank error for transit failure — always provide an alternative

**Phase:** Transport mode fallback phase.

---

### Pitfall 8: Lane Guidance Data Is Not Available via Google Routes API

**What goes wrong:** PROJECT.md lists "Lane guidance (подсказки полос) где доступно" as a requirement. Development time is allocated. No lane data arrives.

**Why it happens:** Lane guidance (`maneuver.lanes`) is returned by the Google Routes API v2 only for the Directions API with `ComputeRoutes` and requires the `routes.legs.steps.navigationInstruction` field mask. Even then, lane data is sparse and geographically limited (US, some EU). For Russia, Japan, and most travel destinations in this app, lane data will be absent in practice.

**Prevention:**
- Treat lane guidance as a "nice to have" that renders if data is present, not a feature to build UI scaffolding for
- Check `navigationInstruction.maneuverView` fields from the Routes API — if absent, hide the lanes UI entirely
- Do not allocate a dedicated roadmap phase to lane guidance

**Phase:** Do not create a dedicated phase. Embed as optional rendering in step-instruction display.

---

### Pitfall 9: Glassmorphism Blur Performance on Map Overlays

**What goes wrong:** The bottom sheet with `ultraThinMaterial` background renders beautifully in isolation. Over the live map during active navigation, it causes frame drops to 30fps, especially on iPhone 12 or older.

**Why it happens:** `UIBlurEffect` / `.ultraThinMaterial` composites every frame against the layer underneath it. A constantly-moving map with active route polylines means the blur compositor works at full rate, competing with MapKit's own render loop.

**Prevention:**
- Use `.regularMaterial` instead of `.ultraThinMaterial` for the navigation bottom sheet — slightly less transparent but significantly lighter to composite
- Reduce the blur area: keep the blur only on the "pill" header of the sheet, use a solid (semi-transparent) background for the step list below it
- During active navigation, avoid animating sheet `detent` changes — keep the sheet at `.medium` fixed until navigation ends

**Phase:** Navigation UI polish phase.

---

## Minor Pitfalls

---

### Pitfall 10: `MKLocalSearch` Region Bias Gives Wrong Results Abroad

**What goes wrong:** User searches "Starbucks" in Tokyo. The `MKLocalSearch` returns Starbucks locations in the user's home city because `request.region` was set to the device's current location rather than the map's visible region.

**Prevention:**
- Always set `request.region = visibleRegion` (already done in `MapViewModel.performMapSearch`), not the device's current location
- Verify `visibleRegion` is not nil before issuing the search; fall back to the trip's first place coordinate

**Phase:** Search refinement (already partially correct — verify not regressed during navigation mode changes).

---

### Pitfall 11: `AVSpeechUtterance` Queue Builds Up During Rapid Maneuvers

**What goes wrong:** User approaches a complex interchange with three turns in quick succession. All three utterances are queued. The synthesizer speaks "Turn left" 45 seconds after the turn.

**Prevention:**
- Always call `synthesizer.stopSpeaking(at: .immediate)` before queuing a new utterance during active navigation
- Only speak the immediately upcoming maneuver; silence queued ones when a new step is activated

**Phase:** Voice guidance phase.

---

### Pitfall 12: SwiftData Route Cache Not Keyed on Mode

**What goes wrong:** User previews walking route, then switches to driving. The cache returns the walking route for the driving mode (same origin/destination key, wrong mode).

**Prevention:**
- The existing `RoutingService` cache key includes `mode.rawValue` — this is correct
- Verify this key structure is preserved if `RouteResult` persistence is moved to SwiftData for offline use

**Phase:** Offline route caching phase.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|----------------|------------|
| Background location / rerouting | Location silently paused when stationary | `pausesLocationUpdatesAutomatically = false` + plist entry |
| Voice guidance | Music stays ducked after TTS | Async session deactivation in `didFinish` delegate |
| Offline caching | MKMapSnapshotter used for interactive offline | Accept tile limitation; cache routes, not tiles |
| Rerouting frequency | API quota exhaustion | 8s debounce + 20m off-route threshold |
| Navigation session UI | Map jitter from 1 Hz state updates | Separate `NavigationSessionState`, 5m camera update threshold |
| Step matching | Wrong step announced | Polyline segment snapping, not nearest-start matching |
| Transit fallback | Blank error in unsupported regions | Auto-fallback to walking + Apple Maps deep-link |
| Lane guidance | Phase allocated but data absent | Treat as optional render, no dedicated phase |
| Glass bottom sheet | Frame drops during navigation | `.regularMaterial`, reduced blur surface area |

---

## Sources

- [Apple Developer Forums: CLLocationManager background location](https://developer.apple.com/forums/thread/87256) — MEDIUM confidence
- [Apple WWDC24: What's new in location authorization](https://developer.apple.com/videos/play/wwdc2024/10212/) — HIGH confidence
- [Apple Developer Docs: CLLocationManager](https://developer.apple.com/documentation/corelocation/cllocationmanager) — HIGH confidence
- [Apple Developer Forums: AVSpeechSynthesizer session deactivation failure](https://developer.apple.com/forums/thread/45599) — HIGH confidence (confirmed bug)
- [Apple Developer Docs: usesApplicationAudioSession](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/usesapplicationaudiosession) — HIGH confidence
- [Apple Developer Docs: Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions) — HIGH confidence
- [NSHipster: MKTileOverlay, MKMapSnapshotter, MKDirections](https://nshipster.com/mktileoverlay-mkmapsnapshotter-mkdirections/) — MEDIUM confidence (older article, constraints unchanged)
- [Apple Developer Docs: MKMapSnapshotter](https://developer.apple.com/documentation/mapkit/mkmapsnapshotter) — HIGH confidence
- [GitHub issue: iOS background location ~80s gaps (Feb 2026)](https://github.com/transistorsoft/react-native-background-geolocation/issues/2494) — LOW confidence (third-party, but corroborates Apple forum reports)
- Existing project code reviewed: `RoutingService.swift`, `MapViewModel.swift` — direct code analysis
