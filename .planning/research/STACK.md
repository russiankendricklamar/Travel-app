# Technology Stack

**Project:** Travel App — Map Navigation Overhaul
**Researched:** 2026-03-20 (core navigation) | Updated: 2026-03-21 (Apple Maps UI Parity milestone)
**Confidence:** HIGH

---

## v1.1 Apple Maps UI Parity — Stack Addendum

This section covers ONLY the SwiftUI/MapKit APIs needed for the Apple Maps UI Parity milestone.
The core navigation stack (v1.0) is unchanged below.

### Bottom Sheet Architecture Decision

**Keep the existing custom GeometryReader sheet. Do NOT migrate to `.presentationDetents`.**

Rationale: Native `.presentationDetents` in iOS 16–18 has a fundamental limitation — it always renders as a system modal that dims the background and anchors to screen edges. The Apple Maps peek state is a **floating pill that does not cover the map**. No amount of `.presentationBackgroundInteraction` or `.presentationBackground` configuration can reproduce a pill that floats with horizontal margins over the map. This requires a custom overlay sheet.

Additional note: `.presentationDetents` has confirmed content-height measurement bugs on iOS 16–18 that are only fixed in iOS 26. The custom `MapBottomSheet.swift` is architecturally correct; only visual polish is needed.

### Peek Pill Background — Replace Solid Color with Blur Material

| API | iOS Min | Purpose | Change Required |
|-----|---------|---------|-----------------|
| `.ultraThinMaterial` | iOS 15 | Frosted glass blur for peek pill | Replace `Color.black.opacity(0.75)` in `MapBottomSheet.swift` |
| `.environment(\.colorScheme, .dark)` | iOS 13 | Force dark rendering of material | Apply to pill container so blur renders dark regardless of system scheme |
| `RoundedRectangle(cornerRadius: 22, style: .continuous)` | iOS 13 | Squircle-shaped pill | Current `cornerRadius: 22` is correct; add `style: .continuous` for Apple-quality corners |
| `.shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 4)` | iOS 13 | Drop shadow under pill | Increase from `radius: 12` to `radius: 14` for more realistic lift |

Exact replacement for peek pill background in `MapBottomSheet.swift`:

```swift
// REPLACE current peek background:
// .fill(Color.black.opacity(0.75))

// WITH:
.background(
    .ultraThinMaterial,
    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
)
.environment(\.colorScheme, .dark)
.shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 4)
.padding(.horizontal, 16)
.padding(.bottom, 4)
```

### Drag Handle Spec

Apple Maps drag handle exact dimensions (verified by pixel analysis):

| Property | Current Code | Apple Maps Spec | Change |
|----------|-------------|-----------------|--------|
| Width | 60pt | 36pt | Reduce |
| Height | 5pt | 5pt | No change |
| Color | `Color.secondary.opacity(0.5)` | `Color(.systemFill)` | Use semantic color — adapts to dark/light |
| Top padding | 10pt | 8pt | Reduce by 2pt |
| Bottom padding | 8pt | 6pt | Reduce by 2pt |

```swift
// Replace in MapBottomSheet.swift:
Capsule()
    .fill(Color(.systemFill))
    .frame(width: 36, height: 5)
    .padding(.top, 8)
    .padding(.bottom, 6)
```

### Expanded Sheet Background — Correct Dark Color

Current expanded background `Color(red: 0.11, green: 0.11, blue: 0.12)` is a hardcoded dark color. Apple Maps uses the system background so it adapts to future OS changes:

```swift
// Replace hardcoded dark in MapBottomSheet.swift:
// Color(red: 0.11, green: 0.11, blue: 0.12)

// WITH:
Color(uiColor: .systemBackground)
// This is dark on dark scheme (which .preferredColorScheme(.dark) forces on the map)
```

### Background Transition — Peek to Expanded

The background changes discretely between detent states, animated by the existing spring. Add `.transition(.opacity)` to each branch for a short 0.15s crossfade during the snap:

```swift
.background {
    if isPeek {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .transition(.opacity)
    } else {
        UnevenRoundedRectangle(
            topLeadingRadius: 22,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 22,
            style: .continuous
        )
        .fill(Color(uiColor: .systemBackground))
        .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
        .ignoresSafeArea(edges: .bottom)
        .transition(.opacity)
    }
}
.animation(.easeInOut(duration: 0.15), value: isPeek)
```

### Search Pill — Material Correction

The existing `MapFloatingSearchPill.swift` uses `.ultraThinMaterial`. Apple Maps uses `.regularMaterial` (thicker) which gives better contrast for the search text:

```swift
// In MapFloatingSearchPill.swift, replace:
// .fill(.ultraThinMaterial)

// WITH:
.fill(.regularMaterial)
```

The rest of the pill (cornerRadius 12, shadow radius 8, padding) is already correct.

### Search Pill to Expanded Bar Animation — matchedGeometryEffect

When the sheet transitions from peek to half/full and the search field expands, `matchedGeometryEffect` creates a smooth morphing animation:

| API | iOS Min | Purpose |
|-----|---------|---------|
| `@Namespace` | iOS 14 | Creates animation namespace shared between pill and expanded bar |
| `matchedGeometryEffect(id:in:)` | iOS 14 | Synchronizes geometry between pill shape and expanded search background |

Implementation pattern:

```swift
// In TripMapView (owns both layers):
@Namespace private var searchNamespace

// Pass namespace to MapFloatingSearchPill and MapSearchContent
// Apply .matchedGeometryEffect(id: "searchBackground", in: searchNamespace)
// on the background RoundedRectangle in each component
```

Note: `matchedGeometryEffect` only works reliably when source and destination views are in the same SwiftUI view hierarchy. If z-index issues appear across the ZStack layers, fall back to `.transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottom)))` — less fluid but always correct.

### Floating Map Controls — Right Vertical Stack

Replace the existing hand-rolled location button and `.mapControls {}` block with scoped standalone controls placed in the right floating stack.

**Why `MapUserLocationButton` over hand-rolled:**
The native button automatically manages three location tracking states (none → following → followingWithHeading) with animated SF Symbol transitions and correct VoiceOver labels — no custom state machine needed.

**Why standalone over `.mapControls {}`:**
`.mapControls {}` places controls at the system-defined position (typically top-trailing corner). Apple Maps right-side vertical stack above the search pill requires custom positioning as standalone SwiftUI views.

| API | iOS Min | Purpose |
|-----|---------|---------|
| `@Namespace` | iOS 14 | Namespace for map scope binding |
| `Map(position:selection:scope:)` | iOS 17 | Attach scope to map instance |
| `.mapScope(namespace)` | iOS 17 | Declare scope on parent view |
| `MapUserLocationButton(scope:)` | iOS 17 | Native location tracking button |
| `MapCompass(scope:)` | iOS 17 | Compass that appears on map rotation |
| `MapPitchToggle(scope:)` | iOS 17 | 2D/3D perspective toggle |
| `.mapControlVisibility(.visible)` | iOS 17 | Show compass permanently, not just on rotation |

Implementation in `TripMapView.swift`:

```swift
@Namespace private var mapScope

// On Map view, add scope parameter:
Map(position: $vm.cameraPosition, selection: $vm.selectedPlaceID, scope: mapScope) {
    // existing content unchanged
}
.mapScope(mapScope)

// Remove existing .mapControls block
// Remove hand-rolled location button VStack

// Add floating controls ZStack layer:
VStack {
    Spacer()
    VStack(spacing: 8) {
        MapUserLocationButton(scope: mapScope)
        MapPitchToggle(scope: mapScope)
        MapCompass(scope: mapScope)
            .mapControlVisibility(.visible)
    }
    .padding(.trailing, 16)
    .padding(.bottom, 96)  // sit above peek pill height (56pt) + tab bar (34pt) + 6pt gap
}
```

### Peek Sheet Height Correction

Current peek height is 50pt. Apple Maps peek pill is ~58pt to accommodate 44pt search content + 7pt top + 7pt bottom padding:

```swift
// In MapBottomSheet.swift SheetDetent.peek:
case .peek: return 58  // was 50
```

### Sheet Content Scroll Behavior

When the sheet is at `.half` with scroll content (search results list), the default SwiftUI behavior expands the sheet to the next detent on upward scroll. Use `.presentationContentInteraction(.scrolls)` — but this only applies to system sheets.

For the custom sheet, the existing drag gesture correctly distinguishes intent (drag on handle = resize, drag on content = scroll) because content is in a `ScrollView` with `DragGesture(minimumDistance: 5)` on the handle area only.

No API change needed here. The existing approach is correct.

### Summary of Changes Required

| File | Change | API Used |
|------|--------|----------|
| `MapBottomSheet.swift` | Peek pill: `ultraThinMaterial` + dark env instead of solid black | `.ultraThinMaterial`, `.environment(\.colorScheme, .dark)` |
| `MapBottomSheet.swift` | Drag handle: 36pt wide, `Color(.systemFill)` | `Capsule` |
| `MapBottomSheet.swift` | Expanded bg: `Color(uiColor: .systemBackground)` | `UIColor.systemBackground` |
| `MapBottomSheet.swift` | `UnevenRoundedRectangle` add `style: .continuous` | `UnevenRoundedRectangle` |
| `MapBottomSheet.swift` | Peek height: 58pt instead of 50pt | `SheetDetent.peek` |
| `MapFloatingSearchPill.swift` | Background: `.regularMaterial` instead of `.ultraThinMaterial` | `.regularMaterial` |
| `TripMapView.swift` | Add `@Namespace mapScope`, `Map(scope:)`, `.mapScope()` | `@Namespace`, `Map(scope:)` |
| `TripMapView.swift` | Replace hand-rolled location button with `MapUserLocationButton(scope:)` | `MapUserLocationButton` |
| `TripMapView.swift` | Add `MapPitchToggle(scope:)` to floating right stack | `MapPitchToggle` |
| `TripMapView.swift` | Remove `.mapControls {}` block (controls now standalone) | — |

---

## v1.0 Core Navigation Stack

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

**Critical limitation:** Transit routing via `MKDirections` returns `MKRoute` steps but does not expose individual transit legs. Step text is human-readable but structured transit data is not available. Acceptable for this project.

---

### Turn-by-Turn Navigation Engine

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `CLLocationManager` | iOS 2+ | Real-time user position during navigation | `startUpdatingLocation()` with `desiredAccuracy = kCLLocationAccuracyBestForNavigation`. App already has `LocationManager.swift` — extend it |
| `CLLocation.distance(from:)` | iOS 2+ | Off-route deviation detection | Compare current position to nearest `MKRoute.Step` polyline point. If distance > threshold (e.g. 50m), trigger recalculation |
| Custom `NavigationEngine` (@Observable) | — | Navigation state machine | Tracks: currentStepIndex, distanceToNextStep, isNavigating, hasDeviated. Updates on each CLLocation callback |

**Confidence: HIGH** — standard pattern, confirmed by multiple developer resources.

---

### Voice Guidance

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `AVSpeechSynthesizer` | iOS 7+ | Text-to-speech voice prompts | Free, offline, supports all iOS languages including Russian. No API key, no network required |
| `AVSpeechUtterance` | iOS 7+ | Individual voice prompt | Set `.voice` to `AVSpeechSynthesisVoice(language: "ru-RU")` for Russian |
| `AVAudioSession` | iOS 2+ | Audio session management | Set category `.playback` with `.duckOthers` to lower music during prompts — same pattern as Apple Maps |

**Confidence: HIGH** — well-documented, widely used.

---

### Offline Maps

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `MKMapSnapshotter` | iOS 7+ | Tile snapshots per region | Already in app (`OfflineCacheManager`). Captures raster snapshots at zoom levels |
| `SwiftData` (existing) | iOS 17+ | Persist cached routes offline | Store serialized `MKRoute` data as `CachedRoute` @Model |

**Confidence: MEDIUM** — Apple's ToS prohibits caching Apple Maps tiles for offline use. `MKMapSnapshotter` snapshots are a gray area used widely in apps. The project already made this architectural decision correctly.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Custom GeometryReader sheet | Native `.presentationDetents` | NEVER for floating pill peek. Use `.presentationDetents` only if peek can be full-width attached-to-edge (not Apple Maps style) |
| `MapUserLocationButton(scope:)` | Hand-rolled `location.fill` button | Hand-rolled only if iOS 16 support is required (project targets iOS 17+) |
| `matchedGeometryEffect` for pill animation | `.transition(.opacity.combined(.scale))` | Use scale+opacity if matchedGeometryEffect causes z-index conflicts across ZStack layers |
| `.ultraThinMaterial` + dark env | `Color.black.opacity(0.75)` | Solid color is acceptable fallback if blur causes performance issues on older devices |
| `@Namespace` + `mapScope` for controls | `.mapControls {}` | Use `.mapControls {}` only if custom positioning is not required |
| MapKit (native) | Mapbox SDK, MapLibre | Only if offline vector tiles are mandatory (they are out of scope for this project) |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `.presentationDetents` for the always-present map sheet | Adds system dim overlay, cannot float as pill, known height-measurement bugs on iOS 16–18 | Custom GeometryReader overlay sheet (already in codebase) |
| `UIViewRepresentable` wrapping `UISheetPresentationController` | Breaks SwiftUI state management, UIKit coupling | Custom SwiftUI overlay |
| Third-party sheet libraries (BottomSheet, Introspect) | Fragile across iOS updates, adds SPM dependency | Pure SwiftUI custom sheet |
| `MapZoomStepper` | macOS-only, not available on iOS | Pinch gesture directly on `Map` |
| `List` inside the custom sheet | `List` creates its own scroll context that conflicts with the sheet drag gesture | `ScrollView` + `LazyVStack` (already used in search content) |
| `.presentationBackground` modifier | Only applies to system modal sheets (`.sheet`, `.fullScreenCover`), not custom overlay views | Apply material fill directly to the overlay shape |

---

## iOS Version Requirements

| API | Minimum iOS | Notes |
|-----|-------------|-------|
| `Map` SwiftUI view (new APIs) | iOS 17 | `MapCameraPosition`, `MapPolyline` in Map scope |
| `Map(scope:)` parameter | iOS 17 | Required for standalone MapKit controls |
| `MapUserLocationButton(scope:)` | iOS 17 | Replaces hand-rolled location button |
| `MapCompass(scope:)` standalone | iOS 17 | Use with mapScope namespace |
| `MapPitchToggle(scope:)` standalone | iOS 17 | New addition to floating stack |
| `.mapScope(_:)` modifier | iOS 17 | Associates controls with specific Map instance |
| `UnevenRoundedRectangle` | iOS 17 | Top-only corner radius on expanded sheet |
| `.ultraThinMaterial` | iOS 15 | Peek pill blur |
| `.regularMaterial` | iOS 15 | Search pill blur |
| `matchedGeometryEffect` | iOS 14 | Pill → expanded bar animation |
| `@Namespace` | iOS 14 | Namespace for matched geometry |
| `presentationDetents` | iOS 16 | Not used for main sheet; noted for reference |
| `presentationBackgroundInteraction` | iOS 16.4 | Not used for main sheet; noted for reference |

Project targets iOS 17+ (confirmed: build target iPhone 17 Pro Max, iOS 26.2). All APIs above are available without conditional checks.

---

## Sources

- [Meet MapKit for SwiftUI — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10043/) — MapScope, MapUserLocationButton, standalone controls. HIGH confidence, official.
- [Adding Map Controls — CreateWithSwift](https://www.createwithswift.com/adding-map-controls-to-a-map-view-with-swiftui-and-mapkit/) — Exact API patterns for standalone controls. HIGH confidence.
- [Mastering MapKit Customizations — SwiftWithMajid](https://swiftwithmajid.com/2023/12/05/mastering-mapkit-in-swiftui-customizations/) — mapScope namespace pattern with code examples. HIGH confidence.
- [Exploring Interactive Bottom Sheets — CreateWithSwift](https://www.createwithswift.com/exploring-interactive-bottom-sheets-in-swiftui/) — presentationDetents modifiers and limitations. HIGH confidence.
- [Customizing Sheet Background — AppCoda](https://www.appcoda.com/swiftui-bottom-sheet-background/) — presentationBackground, material options, background interaction. HIGH confidence.
- [UnevenRoundedRectangle iOS 17 — DevTechie/Medium](https://medium.com/devtechie/round-specific-corners-in-ios-17-swiftui-5-using-unevenroundedrectangle-ffdc88d163c9) — iOS 17 native API. HIGH confidence.
- [presentationDetents iOS 16–18 bugs — Hacking with Swift Forums](https://www.hackingwithswift.com/forums/swiftui/swiftui-presentationdetents-behaves-incorrectly-on-ios-16-18-but-works-correctly-on-ios-26/30435) — Known content height bug justifying custom sheet approach. MEDIUM confidence.
- [How to Build a Floating Bottom Sheet — DEV Community](https://dev.to/sebastienlato/how-to-build-a-floating-bottom-sheet-in-swiftui-drag-snap-blur-lfp) — Spring animation parameters, blur material approach. MEDIUM confidence.
- [MKDirections — Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/mkdirections) — HIGH confidence, official.
- [AVSpeechSynthesizer — Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) — HIGH confidence, official.
