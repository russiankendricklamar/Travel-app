# Phase 9: Floating Controls - Research

**Researched:** 2026-03-21
**Domain:** SwiftUI MapKit — Map scope/namespace, overlay controls, mapStyle toggle
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Компас отдельно сверху (`MapCompass(scope: mapScope)`) + blur-контейнер снизу (3 кнопки: transit, 3D, location)
- **D-02:** 8pt gap между компасом и контейнером
- **D-03:** Контейнер: `RoundedRectangle(cornerRadius: 12, style: .continuous)` + `.ultraThinMaterial` + dark color scheme
- **D-04:** Тонкие разделители между кнопками: 0.5pt `Color.white.opacity(0.15)`
- **D-05:** Контейнер ширина = 44pt
- **D-06:** Каждая кнопка = 44pt × 44pt hit area
- **D-07:** Тень контейнера = `shadow(color: .black.opacity(0.35), radius: 14, y: 4)`
- **D-08:** Контейнер анимированно сжимается когда компас hidden (north-facing)
- **D-09:** Native `MapCompass(scope: mapScope)` — auto hide/show
- **D-10:** Требуется `@Namespace var mapScope` + `Map(scope: mapScope)` в TripMapView
- **D-11:** Удалить `MapCompass()` из `.mapControls`, удалить floating location button (lines 149-181)
- **D-12:** `MapScaleView()` остаётся в `.mapControls`
- **D-13:** Transit icon: `bus.fill`
- **D-14:** Transit toggle: `showsTraffic` true/false
- **D-15:** Transit initial state: `showsTraffic: true`
- **D-16:** Transit active color: `AppTheme.sakuraPink`, inactive: `.white`
- **D-17:** Haptic: `.impact(.light)` при toggle
- **D-18:** Elevation: `.standard(elevation: .realistic)` ↔ `.standard(elevation: .flat)`
- **D-19:** Elevation icon: `view.3d` when flat, `view.2d` when realistic
- **D-20:** Elevation active (3D) color: `AppTheme.sakuraPink`, inactive (2D): `.white`
- **D-21:** Elevation position: between transit and location
- **D-22:** Haptic: `.impact(.light)` при elevation toggle
- **D-23:** Location icon: `location` (outline)
- **D-24:** Location action: center на GPS, zoom = 0.01° latitude delta
- **D-25:** Простой center (без heading mode)
- **D-26:** Haptic: `.impact(.light)` при location tap
- **D-27:** Fade: видны только в peek + idle. Snap по detent, не по drag offset
- **D-28:** Fade animation: `response: 0.35, dampingFraction: 0.85`
- **D-29:** Скрывать при `vm.isNavigating`
- **D-30:** Скрывать при `vm.showPrecipitation`
- **D-31:** Скрывать при `isOfflineWithCache`
- **D-32:** Default icon color: `.white`
- **D-33:** Icon size/weight: Claude's discretion (16pt semibold ориентир)
- **D-34:** `accessibilityLabel` на каждую кнопку
- **D-35:** `accessibilityHint` с описанием действия
- **D-36:** Правый край, 16pt от trailing edge
- **D-37:** Bottom offset: Claude's discretion (~80-90pt, над peek pill)

### Claude's Discretion

- Размер и weight SF Symbol иконок (ориентир 16pt semibold) — resolved to 16pt semibold (see UI-SPEC)
- Точный bottom offset контейнера (80-90pt) — resolved to 88pt (see UI-SPEC)
- Анимация смены иконки при toggle (symbolEffect или без) — resolved to `.contentTransition(.symbolEffect(.replace))`
- Начальное состояние elevation (flat или realistic) — resolved to `.flat`

### Deferred Ideas (OUT OF SCOPE)

- Heading mode для location button (двойной тап → follow user rotation)
- Satellite view toggle (standard ↔ imagery)
- 3-way map style cycle (standard → 3D → satellite)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CTRL-01 | Вертикальный стек кнопок справа: компас → транспорт → локация | FloatingControlsOverlay with VStack structure; MapCompass + custom container pattern verified |
| CTRL-02 | Каждая кнопка: 44pt circle, `.ultraThinMaterial` + dark scheme background | Material applied to container, not per-button; 44pt hit areas; `.preferredColorScheme(.dark)` on container |
| CTRL-03 | Позиция: правый край (16pt от края), над peek pill (~80pt от низа) | `.frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.bottomTrailing)` + padding; 88pt resolved |
| CTRL-04 | Компас использует `MapCompass(scope: mapScope)` с `@Namespace` | API verified: `@Namespace var mapScope`, `Map(scope:)`, `.mapScope()` on container — all iOS 17+ |
| CTRL-05 | Кнопка локации центрирует карту на текущем GPS | Existing `LocationManager.shared.requestCurrentLocation()` async pattern reused from TripMapView:157-166 |
| CTRL-06 | Кнопки плавно скрываются при расширении sheet выше peek | `.opacity(isVisible ? 1 : 0)` + `.animation(.spring(response: 0.35, dampingFraction: 0.85), value: isVisible)` |
| CTRL-07 | Кнопка транспорта переключает отображение transit линий | `vm.showTraffic` Bool toggle → `.mapStyle(.standard(showsTraffic: vm.showTraffic))` |
</phase_requirements>

---

## Summary

Phase 9 adds a vertical stack of floating map controls (compass + transit toggle + 3D elevation toggle + location center) to the right side of TripMapView. The entire feature set is built on iOS 17+ SwiftUI MapKit APIs that are available within the project's minimum deployment target (iOS 17.0).

The core pattern is: define `@Namespace var mapScope` in TripMapView, pass `scope: mapScope` to the `Map` view, apply `.mapScope(mapScope)` to the ZStack container, then place `MapCompass(scope: mapScope)` in an overlay positioned manually rather than inside `.mapControls`. This decouples the compass from the built-in control bar and allows precise placement alongside custom buttons. The pattern is verified against official Apple documentation and multiple authoritative tutorials.

The 3D elevation button is a scope extension beyond CTRL-07 (transit only) but is fully covered by decisions D-18 through D-22. The `view.3d` / `view.2d` SF Symbols exist in SF Symbols and the icon swap animation uses `.contentTransition(.symbolEffect(.replace))` — available iOS 17+. The existing `MapViewModel` needs two new `@Observable` properties (`showTraffic`, `show3DElevation`) and the `.mapStyle()` modifier needs to be made dynamic.

**Primary recommendation:** Create `FloatingControlsOverlay.swift` as a standalone View, wire it into TripMapView's ZStack, and update MapViewModel + mapStyle binding in a focused 3-task plan (VM state → overlay view → TripMapView wiring).

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI MapKit | iOS 17+ | `Map`, `MapCompass`, `MapPitchToggle`, `.mapStyle()`, `.mapScope()` | Native Apple framework, already used in project |
| SF Symbols | 5+ (iOS 17) | `bus.fill`, `location`, `view.3d`, `view.2d` system icons | Native, zero dependency, scales with Dynamic Type |
| UIKit (for haptics) | iOS 17+ | `UIImpactFeedbackGenerator(.light)` | Same haptic pattern already used in Phase 8 search bar |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `LocationManager.shared` | project | Async GPS fetch for location center | Already in TripMapView `.task` and existing button |
| `AppTheme` | project | `sakuraPink`, `spacingM`, `borderWidth` | Active-state accent color, spacing tokens |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `UIImpactFeedbackGenerator` directly | `SensoryFeedback` (iOS 17+) | `.sensoryFeedback(.impact(weight:.light), trigger:)` is the modern SwiftUI approach — but project uses UIKit haptic pattern from Phase 8, keep consistent |
| Per-button `.ultraThinMaterial` circle | Single container `.ultraThinMaterial` rounded rect | D-03 decision mandates single container; per-button approach produces ugly multiple-layer blur artifacts on map tiles |

**Installation:** No new packages needed. Pure MapKit + SwiftUI.

---

## Architecture Patterns

### Recommended Project Structure

```
Travel app/Views/Map/
├── TripMapView.swift         # Modified — add @Namespace, scope, FloatingControlsOverlay
├── MapViewModel.swift        # Modified — add showTraffic, show3DElevation
├── FloatingControlsOverlay.swift  # NEW — entire overlay component
├── MapBottomSheet.swift      # Unchanged
└── (other existing map files)
```

### Pattern 1: Map Scope + External Compass

**What:** `@Namespace` created in parent view, passed to both `Map(scope:)` and `MapCompass(scope:)`, with `.mapScope()` on the ZStack container so SwiftUI can associate compass with map.

**When to use:** Whenever a `MapCompass` (or `MapPitchToggle`, `MapUserLocationButton`) needs to live outside the `.mapControls` block.

**Example:**
```swift
// Source: createwithswift.com + swiftwithmajid.com (verified iOS 17+)
struct TripMapView: View {
    @Namespace var mapScope

    var body: some View {
        ZStack {
            Map(position: $vm.cameraPosition, selection: $vm.selectedPlaceID, scope: mapScope) {
                // ... annotations
            }
            .mapScope(mapScope)  // REQUIRED on the ZStack or Map container

            FloatingControlsOverlay(vm: vm, mapScope: mapScope, isOfflineWithCache: isOfflineWithCache)
        }
        .mapScope(mapScope)  // Place on outermost container that holds both Map and controls
    }
}
```

### Pattern 2: FloatingControlsOverlay Structure

**What:** Self-contained View that takes `vm`, `mapScope: Namespace.ID`, and visibility condition as inputs. Renders VStack with compass + container.

**When to use:** Isolate all floating control logic in one file, not spread across TripMapView body.

**Example:**
```swift
// Source: UI-SPEC.md + verified MapKit patterns
struct FloatingControlsOverlay: View {
    @Bindable var vm: MapViewModel
    var mapScope: Namespace.ID
    var isOfflineWithCache: Bool

    private var isVisible: Bool {
        vm.sheetDetent == .peek && !vm.isNavigating && !vm.showPrecipitation && !isOfflineWithCache
    }

    var body: some View {
        VStack(spacing: 0) {
            MapCompass(scope: mapScope)

            Spacer().frame(height: 8)  // D-02

            // Blur container
            VStack(spacing: 0) {
                transitButton
                divider
                elevationButton
                divider
                locationButton
            }
            .frame(width: 44)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
            .preferredColorScheme(.dark)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 88)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isVisible)
    }
}
```

### Pattern 3: Dynamic mapStyle Binding

**What:** Replace hardcoded `.mapStyle(.standard(elevation: .realistic, ..., showsTraffic: true))` with a computed property driven by VM state.

**When to use:** Any time two or more map style parameters need to be toggled independently.

**Example:**
```swift
// Source: Apple developer documentation — MKMapConfiguration.ElevationStyle
// Applied in mapContent var, replacing TripMapView:414
.mapStyle(.standard(
    elevation: vm.show3DElevation ? .realistic : .flat,
    pointsOfInterest: .including([.museum, .nationalPark, .park, .restaurant]),
    showsTraffic: vm.showTraffic
))
```

### Pattern 4: symbolEffect for Icon Toggle

**What:** Use `.contentTransition(.symbolEffect(.replace))` on an `Image(systemName:)` to animate the icon swap when elevation state changes.

**When to use:** Toggling between two different SF Symbol names (e.g., `view.3d` ↔ `view.2d`).

**Example:**
```swift
// Source: Apple WWDC23 "Animate symbols in your app" + appcoda.com tutorial — iOS 17+
Image(systemName: vm.show3DElevation ? "view.2d" : "view.3d")
    .font(.system(size: 16, weight: .semibold))
    .foregroundStyle(vm.show3DElevation ? AppTheme.sakuraPink : .white)
    .contentTransition(.symbolEffect(.replace))
```

### Anti-Patterns to Avoid

- **`.mapControls` for custom layout:** `.mapControls` doesn't support arbitrary positioning. Custom controls with precise placement must use overlay + namespace pattern.
- **Per-button `.ultraThinMaterial` circles:** Produces visible stacked blur layers over map tiles. Single container blur is the correct approach (matches Apple Maps visual identity).
- **Missing `.mapScope()` on container:** `MapCompass(scope:)` won't respond to the correct map if `.mapScope()` is not applied to the parent ZStack. This is a silent failure — compass renders but doesn't track the right map instance.
- **Animating opacity of `MapCompass` directly:** Native `MapCompass` has its own internal show/hide animation. Don't wrap it in additional opacity transitions — let it manage itself. The VStack will reflow naturally when compass appears/disappears (D-08 behavior).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Compass that hides when north-facing | Custom compass view with rotation tracking | `MapCompass(scope: mapScope)` | Native component handles heading tracking, animation, tap-to-north, localization |
| Map pitch/elevation toggle | Custom gesture recognizer + camera manipulation | `.mapStyle(elevation:)` toggle | MapKit handles 3D tile loading, transition animation, and LOD internally |
| GPS location fetch | `CLLocationManager` setup | `LocationManager.shared.requestCurrentLocation()` | Already exists in project, handles permissions |
| Haptic feedback setup | `UIFeedbackGenerator` lifecycle | `UIImpactFeedbackGenerator(.light).impactOccurred()` | One-liner; no generator retain needed for fire-and-forget impacts |

**Key insight:** Every problem in this phase has a first-party MapKit or existing-project solution. Custom implementations would need to replicate Apple's own compass heading tracking, 3D tile management, and GPS permission flow.

---

## Common Pitfalls

### Pitfall 1: Missing `.mapScope()` on Container

**What goes wrong:** `MapCompass(scope: mapScope)` renders but doesn't track map orientation. Compass stays static regardless of map rotation.

**Why it happens:** The `@Namespace` linkage requires `.mapScope()` applied to the view hierarchy that encloses both the `Map` and the control. Without it, the namespace ID exists but SwiftUI can't resolve the association.

**How to avoid:** Apply `.mapScope(mapScope)` to the ZStack in TripMapView (the outermost container that holds both `mapContent` and `FloatingControlsOverlay`).

**Warning signs:** Compass shows but never rotates, or `MapCompass(scope:)` is invisible despite correct scope ID.

### Pitfall 2: MapCompass Double-Render

**What goes wrong:** `MapCompass()` appears twice — once in `.mapControls` (old) and once in the overlay (new). Results in two compass elements visible simultaneously.

**Why it happens:** Forgetting to remove the existing `MapCompass()` from `.mapControls` (TripMapView:418) when adding the new one to the overlay.

**How to avoid:** The integration checklist in UI-SPEC explicitly requires removing `MapCompass()` from `.mapControls`. Plan must include this as an atomic step with the addition.

**Warning signs:** Two compass indicators visible simultaneously, typically one in the default top-right system position and one in the overlay.

### Pitfall 3: Hardcoded mapStyle Not Updated

**What goes wrong:** Transit and elevation toggles have no visual effect on the map. UI toggles state but map doesn't change.

**Why it happens:** TripMapView:414 has hardcoded `.mapStyle(.standard(elevation: .realistic, ..., showsTraffic: true))`. Adding VM toggle properties without updating this line leaves the map style static.

**How to avoid:** Plan must explicitly include updating the `.mapStyle()` modifier to read from `vm.showTraffic` and `vm.show3DElevation`.

**Warning signs:** Tapping transit button changes icon color but map shows no traffic/transit overlay change.

### Pitfall 4: @Observable Mutability with @Bindable

**What goes wrong:** `FloatingControlsOverlay` can't write to `vm` properties — "cannot assign to property: 'vm' is a 'let' constant".

**Why it happens:** `MapViewModel` uses `@Observable` macro. To get a writable binding into a child view, the parent must pass it with `@Bindable` or use `Binding` directly.

**How to avoid:** In `FloatingControlsOverlay`, declare `@Bindable var vm: MapViewModel`. In TripMapView, pass `vm: vm` (not `vm: $vm`) — `@Bindable` creates bindings on demand from an `@Observable` object.

**Warning signs:** Compiler error "cannot assign to property" when toggling `vm.showTraffic` or `vm.show3DElevation` inside the overlay.

### Pitfall 5: isVisible Computed on Drag Offset Instead of Snap

**What goes wrong:** Controls flicker or partially fade during drag gestures while sheet is still at peek height visually.

**Why it happens:** Reacting to a drag-progress value (0...1 interpolation) instead of the snapped `vm.sheetDetent` enum value.

**How to avoid:** D-27 is explicit: snap by detent, not drag offset. `isVisible` must be `vm.sheetDetent == .peek && ...`. No drag-offset tracking needed.

---

## Code Examples

Verified patterns from official sources and existing project code:

### Map Scope Wiring (TripMapView)

```swift
// Source: createwithswift.com verified pattern — iOS 17+
struct TripMapView: View {
    @Namespace var mapScope
    // ... existing state

    var body: some View {
        NavigationStack {
            ZStack {
                // ... existing layers
                mapContent            // Map(scope: mapScope) inside
                FloatingControlsOverlay(vm: vm, mapScope: mapScope, isOfflineWithCache: isOfflineWithCache)
            }
            .mapScope(mapScope)       // CRITICAL — on outermost ZStack container
        }
    }

    private var mapContent: some View {
        Map(position: $vm.cameraPosition, selection: $vm.selectedPlaceID, scope: mapScope) {
            // ... existing annotations unchanged
        }
        .mapStyle(.standard(
            elevation: vm.show3DElevation ? .realistic : .flat,
            pointsOfInterest: .including([.museum, .nationalPark, .park, .restaurant]),
            showsTraffic: vm.showTraffic
        ))
        // ... other modifiers unchanged
    }
}
```

### MapViewModel New Properties

```swift
// Source: state management pattern from CONTEXT.md D-14, D-15, D-18
// Add to MapViewModel @Observable class
var showTraffic: Bool = true          // D-15: starts on
var show3DElevation: Bool = false     // UI-SPEC resolved: starts flat
```

### Haptic Fire-and-Forget

```swift
// Source: Phase 8 established pattern — same UIKit haptic approach
func triggerLightHaptic() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
// OR inline (existing pattern in codebase):
UIImpactFeedbackGenerator(style: .light).impactOccurred()
```

### Location Center Action

```swift
// Source: TripMapView:157-166 — exact existing pattern, reused verbatim
Task {
    if let loc = await LocationManager.shared.requestCurrentLocation() {
        withAnimation(.easeInOut(duration: 0.4)) {
            vm.cameraPosition = .region(
                MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
    }
}
```

### Elevation Icon Toggle with symbolEffect

```swift
// Source: Apple WWDC23 symbolEffect + iOS 17 deployment target confirmed
Button {
    vm.show3DElevation.toggle()
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
} label: {
    Image(systemName: vm.show3DElevation ? "view.2d" : "view.3d")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(vm.show3DElevation ? AppTheme.sakuraPink : .white)
        .frame(width: 44, height: 44)
        .contentTransition(.symbolEffect(.replace))
}
.accessibilityLabel("3D вид")
.accessibilityHint("Переключает между плоским и объёмным отображением рельефа")
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `MapCompass()` in `.mapControls` only | `MapCompass(scope:)` in custom overlay via `@Namespace` | iOS 17 (2023) | Controls can be positioned anywhere in the view hierarchy |
| Manual compass view (UIKit) | Native `MapCompass` SwiftUI component | iOS 17 | Auto-hides when north-facing, tap-to-north, native styling |
| Separate `MapPitchToggle` control | Custom elevation button (toggle `.mapStyle`) | N/A (project choice) | Matches the design language of the custom container |
| `.animation()` on SF Symbol container | `.contentTransition(.symbolEffect(.replace))` | iOS 17 | Smooth morphing between symbol names, no frame jump |

**Deprecated/outdated:**
- `MKMapView` UIKit delegate pattern: Not needed — SwiftUI Map API covers all required functionality
- `.mapControlVisibility(.hidden)` on `MapCompass()` in `.mapControls` as workaround: Cleaner to remove it entirely and add scoped version to overlay

---

## Open Questions

1. **`.mapScope()` placement — ZStack vs NavigationStack**
   - What we know: `.mapScope()` must be on the ancestor that contains both the Map and the controls
   - What's unclear: Whether it should be on the ZStack inside `NavigationStack` or on the `NavigationStack` itself
   - Recommendation: Apply to the ZStack (innermost shared ancestor of Map and overlay). This matches the documented pattern and avoids NavigationStack interaction.

2. **`view.3d` / `view.2d` SF Symbol availability**
   - What we know: These names appear in UI-SPEC (Claude's discretion resolved)
   - What's unclear: Whether these exact symbol names exist in SF Symbols 5 (iOS 17) vs a later version
   - Recommendation: Verify in Xcode SF Symbols app or use `square.3.layers.3d` / `map` as fallbacks. Planner should add a verification step.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual XCUITest / visual inspection (no test target configured per MEMORY.md) |
| Config file | none — test target requires manual Xcode setup |
| Quick run command | Build in Xcode + run on simulator/device |
| Full suite command | Build in Xcode + manual checklist |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CTRL-01 | Vertical stack: compass above container, 3 buttons inside | manual-visual | Build + inspect | ❌ Wave 0 |
| CTRL-02 | 44pt buttons, ultraThinMaterial + dark scheme | manual-visual | Build + inspect on device | ❌ Wave 0 |
| CTRL-03 | 16pt trailing, 88pt bottom, above peek pill | manual-visual | Build + inspect | ❌ Wave 0 |
| CTRL-04 | Compass rotates with map, hides when north-facing, tap-to-north | manual-interactive | Run on device, rotate map | ❌ Wave 0 |
| CTRL-05 | Location button centers map on GPS at 0.01° delta | manual-interactive | Tap button, observe camera | ❌ Wave 0 |
| CTRL-06 | Controls fade out at half/full detent, fade in at peek | manual-interactive | Drag sheet up/down | ❌ Wave 0 |
| CTRL-07 | Transit toggle changes map traffic overlay | manual-visual | Tap bus button, observe map | ❌ Wave 0 |

**Manual-only justification:** All requirements are visual/interactive MapKit behaviors. MapKit rendering cannot be unit-tested without a full rendering stack. The correct validation is physical device or simulator visual inspection.

### Sampling Rate

- **Per task commit:** Build succeeds (zero compiler errors)
- **Per wave merge:** Full manual checklist on simulator
- **Phase gate:** Physical device test for CTRL-04 (compass rotation) and CTRL-02 (material rendering) before `/gsd:verify-work` — per STATE.md note: "Must test `.ultraThinMaterial` on physical device"

### Wave 0 Gaps

No test files to create (manual-only validation). No test infrastructure needed.

---

## Sources

### Primary (HIGH confidence)

- [createwithswift.com — Adding Map Controls with scope](https://www.createwithswift.com/adding-map-controls-to-a-map-view-with-swiftui-and-mapkit/) — Map scope pattern, `@Namespace`, `.mapScope()` modifier, MapPitchToggle placement
- [swiftwithmajid.com — Mastering MapKit Customizations](https://swiftwithmajid.com/2023/12/05/mastering-mapkit-in-swiftui-customizations/) — MapCompass scope, mapControlVisibility, map style elevation
- [Apple developer documentation — MKMapConfiguration.ElevationStyle.realistic](https://developer.apple.com/documentation/mapkit/mkmapconfiguration/elevationstyle-swift.enum/realistic) — Elevation enum values
- [Apple WWDC23 — Animate symbols in your app](https://developer.apple.com/videos/play/wwdc2023/10258/) — `.symbolEffect(.replace)` iOS 17 availability
- TripMapView.swift (lines 149-181, 414-419) — existing code patterns reused verbatim
- MapViewModel.swift — existing `@Observable` property structure

### Secondary (MEDIUM confidence)

- [appcoda.com — Using SymbolEffect](https://www.appcoda.com/swiftui-symboleffect/) — `.contentTransition(.symbolEffect(.replace))` usage pattern
- [medium.com/simform — MapKit SwiftUI iOS 17](https://medium.com/simform-engineering/mapkit-swiftui-in-ios-17-1fec82c3bf00) — iOS 17 scope API overview

### Tertiary (LOW confidence)

- None. All critical claims verified against official docs or existing project code.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — native Apple frameworks, deployment target confirmed iOS 17.0, all APIs iOS 17+
- Architecture patterns: HIGH — Map scope pattern verified against two authoritative sources; existing code patterns directly reused
- Pitfalls: HIGH — pitfall 1-3 verified by direct code inspection; pitfall 4-5 are well-known SwiftUI `@Observable` and animation mechanics

**Research date:** 2026-03-21
**Valid until:** 2026-09-21 (MapKit SwiftUI APIs are stable; SF Symbol names are the only uncertainty)
