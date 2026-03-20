# Phase 2: Navigation UI - Research

**Researched:** 2026-03-20
**Domain:** SwiftUI overlay composition, MapKit camera control, bottom sheet state machines, glassmorphism HUD
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**HUD карточка манёвра**
- Позиция: верх экрана (под Dynamic Island/notch), как в Apple Maps
- Содержимое: SF Symbol иконка направления (arrow.turn.up.left и т.д.) + текстовая инструкция + дистанция до манёвра
- Стиль: glassmorphism (.ultraThinMaterial + AppTheme.sakuraPink акцент) — переиспользует паттерн из GlassComponents
- Анимация смены шага: плавный crossfade (.animation(.easeInOut) на contentTransition)
- Всегда видима при навигации, не сворачивается
- Ургентность: иконка/фон меняет цвет на AppTheme.sakuraPink когда дистанция < 50м
- Иконки направлений: парсинг MKRouteStep.instructions для определения направления → соответствующий SF Symbol
- Контекст поездки ("День 2 из 7 — Токио") НЕ на HUD — в bottom sheet

**Start/Stop навигации**
- Запуск: кнопка "НАЧАТЬ НАВИГАЦИЮ" в конце MapRouteContent (внутри route info sheet)
- Стиль кнопки: залитая AppTheme.sakuraPink с белым текстом (не glass)
- Остановка: два способа — кнопка "Завершить" в navigation sheet + кнопка X на HUD карточке
- Без подтверждения при остановке — одно нажатие останавливает
- После остановки: возврат к routeInfo (маршрут остаётся на карте, MapRouteContent в sheet)

**Camera + heading lock**
- При навигации: .userLocation(followsHeading: true) — камера следит с ротацией по heading
- Auto-zoom автоматически подстраивается
- Пользователь может панорамировать вручную — при смещении появляется кнопка "Вернуться" для ре-центрирования
- При остановке навигации: камера возвращается к обычному режиму (.automatic)

**Navigation sheet detent**
- При навигации: новый sheetContent case .navigation
- Peek состояние: текущий шаг + ETA до пункта назначения + контекст поездки ("День 2 из 7 — Токио")
- Раскрытие (half/full): полный список NavigationStep с выделением текущего + кнопка "Завершить навигацию"
- Glassmorphism стиль как у остального sheet

### Claude's Discretion
- Точные размеры и отступы HUD карточки
- Логика парсинга instructions → SF Symbol иконки (маппинг текстовых паттернов)
- Анимация перехода камеры при старте/стопе навигации
- Дизайн кнопки "Вернуться" при ручном панорамировании
- Визуальное выделение текущего шага в списке шагов

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UI-01 | NavigationHUD — floating карточка следующего манёвра с расстоянием и иконкой направления | HUD overlay pattern in ZStack; contentTransition for step changes; CardStyle modifier |
| UI-02 | Навигационный detent (.small) в bottom sheet при активной навигации | Add .navigation case to MapSheetContent; SheetDetent.nearest() already handles snap; peek shows current step + ETA |
| UI-03 | Контекст поездки в навигации — "День 2 из 7 — Токио" | Computed from trip.sortedDays; visible in navigation sheet peek |
| UI-04 | Glassmorphism стиль для всех новых навигационных компонентов | .ultraThinMaterial + CardStyle/AccentCardStyle already in AppTheme.swift |
| NAV-06 | Кнопка "Начать навигацию" в UI маршрута | Added at bottom of MapRouteContent; calls vm.startNavigation() async; Task wrapper required |
</phase_requirements>

---

## Summary

Phase 2 is a pure UI overlay layer. All logic (NavigationEngine, step tracking, GPS, voice) is complete from Phase 1 and surfaced via `MapViewModel` (@Observable). The implementation is three distinct UI components wired to existing ViewModel state: a floating HUD card, an extended bottom sheet content case, and a start/stop button.

The critical architectural constraint is that `MapViewModel.cameraPosition` must be set to `.userLocation(followsHeading: true)` on navigation start and restored to `.automatic` on stop. Manual pan detection requires comparing the live camera position against the user location — when they diverge beyond a threshold, the "Вернуться" button appears. This is the only non-trivial engineering challenge in this phase; everything else is direct ViewModel binding.

The glassmorphism design system is already established: `.ultraThinMaterial` + `CardStyle` modifier + `AppTheme.sakuraPink` accent. All new views must follow this exact pattern.

**Primary recommendation:** Build three new files — `NavigationHUDView.swift`, `NavigationSheetContent.swift`, `MapRecenterButton.swift` — and wire them into `TripMapView.swift` ZStack and `sheetBody` switch. Add "НАЧАТЬ НАВИГАЦИЮ" button at the bottom of `MapRouteContent.swift`. Modify `MapSheetContent` enum to add `.navigation` case.

---

## Standard Stack

### Core (already in project — no new dependencies)

| Component | Location | Purpose | Notes |
|-----------|----------|---------|-------|
| `MapViewModel` | `Views/Map/MapViewModel.swift` | All navigation state | `isNavigating`, `currentStepIndex`, `distanceToNextStep`, `navigationSteps` already exist |
| `NavigationEngine` | `Services/NavigationEngine.swift` | Step advancement | `onStepAdvanced` callback updates MapViewModel |
| `MapBottomSheet` | `Views/Map/MapBottomSheet.swift` | Custom drag sheet with 3 detents | No changes needed to the shell; only add new content case |
| `AppTheme` / `CardStyle` | `Theme/AppTheme.swift` | Glass card styling | `.ultraThinMaterial` + `CardStyle()` modifier |
| `MapSheetContent` enum | `Views/Map/TripMapView.swift` | Sheet content routing | Add `.navigation` case |

### No New Dependencies

This phase requires zero new SPM packages or frameworks. All required APIs — MapKit camera control, SwiftUI overlay composition, ContentTransition, SF Symbols — are available in the iOS 17+ baseline.

**Installation:** None required.

---

## Architecture Patterns

### Recommended File Structure (new files only)

```
Travel app/Views/Map/
├── NavigationHUDView.swift       # Floating top card — maneuver icon + instruction + distance
├── NavigationSheetContent.swift  # .navigation case body — peek + full step list
└── MapRecenterButton.swift       # Floating "Вернуться" button (appears on manual pan)
```

**Modified files:**
- `TripMapView.swift` — insert HUD and recenter button into ZStack; add `.navigation` case to `sheetBody`; pan detection logic
- `MapRouteContent.swift` — add "НАЧАТЬ НАВИГАЦИЮ" button at bottom
- `TripMapView.swift` (top of file) — add `.navigation` to `MapSheetContent` enum

### Pattern 1: HUD Overlay in ZStack

The ZStack in `TripMapView` already has layers: map → search pill → bottom sheet. The HUD sits between the map and the sheet, pinned to the top with `.safeAreaInset(edge: .top)` or a VStack with `Spacer()`.

```swift
// In TripMapView body ZStack, after mapContent and before MapBottomSheet:
if vm.isNavigating {
    VStack {
        NavigationHUDView(vm: vm)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        Spacer()
    }
    .transition(.move(edge: .top).combined(with: .opacity))
}
```

The HUD must use `.animation(.easeInOut, value: vm.currentStepIndex)` with `.contentTransition(.opacity)` on the text/icon content to produce the crossfade effect on step change.

### Pattern 2: ContentTransition for Step Changes

```swift
// Inside NavigationHUDView — step icon and text crossfade on index change
VStack {
    Image(systemName: maneuverIcon)
        .contentTransition(.symbolEffect(.replace))
    Text(currentStep.instruction)
        .contentTransition(.opacity)
}
.animation(.easeInOut(duration: 0.3), value: vm.currentStepIndex)
```

`contentTransition(.symbolEffect(.replace))` is iOS 17+ and provides the SF Symbol morph animation between direction icons. `contentTransition(.opacity)` crossfades the text.

### Pattern 3: Camera Heading Lock

```swift
// In MapViewModel.startNavigation() — add after isNavigating = true:
withAnimation(.easeInOut(duration: 0.8)) {
    cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
}

// In MapViewModel.stopNavigation() — add before/after existing cleanup:
withAnimation(.easeInOut(duration: 0.5)) {
    cameraPosition = .automatic
}
```

`MapCameraPosition.userLocation(followsHeading:fallback:)` is the MapKit SwiftUI API for heading-locked tracking. The `fallback` parameter handles the case where location is unavailable.

### Pattern 4: Manual Pan Detection → Recenter Button

```swift
// In TripMapView mapContent — the existing .onMapCameraChange is already there:
.onMapCameraChange { context in
    vm.visibleRegion = context.region
    // NEW: detect if user panned away from location during navigation
    if vm.isNavigating, let userLoc = LocationManager.shared.currentLocation {
        let center = context.region.center
        let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
            .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
        vm.isOffNavCenter = distance > 50
    }
}
```

Add `var isOffNavCenter: Bool = false` to `MapViewModel`. The `MapRecenterButton` appears when `vm.isNavigating && vm.isOffNavCenter`.

Recenter action:
```swift
func recenterNavigation() {
    withAnimation(.easeInOut(duration: 0.5)) {
        cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
        isOffNavCenter = false
    }
}
```

### Pattern 5: Navigation Sheet Content

Add `.navigation` to `MapSheetContent` enum and handle in `sheetBody` switch:

```swift
case .navigation:
    NavigationSheetContent(vm: vm)
```

`NavigationSheetContent` shows two states based on `vm.sheetDetent`:
- `.peek` detent: compact row with icon + current step instruction + ETA + trip context label
- `.half`/`.full` detent: scrollable list of all `vm.navigationSteps` with current highlighted + "Завершить" button

### Pattern 6: Trip Context Label

```swift
// Computed in NavigationSheetContent or passed from TripMapView
var tripContextLabel: String {
    let days = vm.trip.sortedDays
    guard !days.isEmpty else { return "" }
    let todayIndex = days.firstIndex(where: { Calendar.current.isDateInToday($0.date) })
    let idx = todayIndex.map { $0 + 1 } ?? 1
    let city = days.first(where: { Calendar.current.isDateInToday($0.date) })?.cityName
               ?? days.first?.cityName ?? vm.trip.country
    return "День \(idx) из \(days.count) — \(city)"
}
```

### Pattern 7: SF Symbol Direction Icon Mapping

Parse `MKRouteStep.instructions` string for direction keywords. This is the discretion area — recommended mapping:

```swift
func maneuverIcon(for instruction: String) -> String {
    let lower = instruction.lowercased()
    if lower.contains("налево") || lower.contains("left")  { return "arrow.turn.up.left" }
    if lower.contains("направо") || lower.contains("right") { return "arrow.turn.up.right" }
    if lower.contains("разворот") || lower.contains("u-turn") { return "arrow.uturn.left" }
    if lower.contains("прямо") || lower.contains("straight") || lower.contains("continue") { return "arrow.up" }
    if lower.contains("слег") && lower.contains("лев") { return "arrow.up.left" }
    if lower.contains("слег") && lower.contains("прав") { return "arrow.up.right" }
    if lower.contains("пункт") || lower.contains("прибыт") || lower.contains("destination") { return "mappin.circle.fill" }
    return "arrow.up"   // default: straight
}
```

MKDirections instructions in Russian and English both contain these patterns. The `NavigationStep.instruction` field holds the raw `MKRouteStep.instructions` string — no additional parsing needed.

### Pattern 8: ETA Computation

ETA is not stored in `NavigationStep` — it must be derived from the active route's `expectedTravelTime`. Display as time-of-arrival:

```swift
var etaString: String {
    guard let route = vm.activeRoute else { return "" }
    let arrival = Date().addingTimeInterval(route.expectedTravelTime)
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.locale = Locale(identifier: "ru_RU")
    return formatter.string(from: arrival)
}
```

### Pattern 9: "НАЧАТЬ НАВИГАЦИЮ" Button

Add at the bottom of `MapRouteContent` body, inside the existing `VStack`, after all existing content:

```swift
// In MapRouteContent — after transitStepsList / error blocks:
Button {
    Task { await vm.startNavigation() }
} label: {
    HStack(spacing: 8) {
        Image(systemName: "location.fill")
            .font(.system(size: 14, weight: .bold))
        Text("НАЧАТЬ НАВИГАЦИЮ")
            .font(.system(size: 15, weight: .bold))
            .tracking(1)
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(
        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
            .fill(AppTheme.sakuraPink)
    )
}
.padding(.horizontal, 16)
.padding(.top, 16)
.disabled(vm.navigationSteps.isEmpty && vm.isCalculatingRoute)
```

Note: `vm.startNavigation()` is `async` (Phase 1 decision) — must be called inside `Task { }`.

### Anti-Patterns to Avoid

- **Calling `vm.startNavigation()` without Task wrapper:** The method is async. Direct call from Button action requires `Task { await ... }`.
- **Setting `cameraPosition` without animation:** Abrupt camera jumps feel jarring. Always wrap in `withAnimation`.
- **Hardcoding detent heights in NavigationSheetContent:** Use `vm.sheetDetent` to switch between peek and expanded layouts — the sheet shell already handles height.
- **Duplicating step list logic:** `vm.navigationSteps` and `vm.currentStepIndex` are the single source of truth. Do not copy arrays into navigation content views.
- **Forgetting `isNavigating` guard on HUD:** The HUD must only render when `vm.isNavigating == true`. Conditional in ZStack body handles this.
- **Swipe-down on navigation sheet resetting state:** The existing `onChange(of: vm.sheetDetent)` in TripMapView calls `dismissDetail()` when detent drops to `.peek`. This must be guarded: skip dismiss if `vm.sheetContent == .navigation`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sheet height animation | Custom height calculator | Existing `MapBottomSheet` + `SheetDetent.nearest()` | Already handles velocity-based snap, drag gesture, screen height |
| Glass card background | Custom material + shadow | `CardStyle()` modifier from AppTheme | Already handles dark/light mode, radius, stroke |
| Symbol animation on step change | Keyframe animation | `.contentTransition(.symbolEffect(.replace))` | iOS 17 native, smooth morph between SF Symbols |
| Text crossfade | Opacity animation on view | `.contentTransition(.opacity)` with `.animation` | Avoids layout shift artifacts |
| Distance formatting | Custom formatter | `RoutingService.formatDistance()` — already exists | Consistent locale-aware formatting |
| Duration formatting | Custom formatter | `RoutingService.formatDuration()` — already exists | Consistent formatting |

**Key insight:** This phase is entirely about assembling existing primitives. The design system, state management, formatting utilities, and sheet infrastructure are all in place.

---

## Common Pitfalls

### Pitfall 1: Navigation Start Before Steps Are Fetched

**What goes wrong:** User taps "НАЧАТЬ НАВИГАЦИЮ" before the background `fetchNavigationSteps` Task completes. `vm.navigationSteps` is empty.

**Why it happens:** Route calculation and step fetch are parallel Tasks started in `calculateDirectionRoute`. Step fetch can take 1-2 seconds.

**How to avoid:** `vm.startNavigation()` already handles this — it awaits step fetch inline if steps are empty (Phase 1 implementation). The button should show `ProgressView` or be disabled while `vm.isCalculatingRoute || vm.navigationSteps.isEmpty`.

**Warning signs:** Navigation starts but no HUD appears (empty steps array, guard returns early).

### Pitfall 2: Camera Heading Lock Breaks Manual Pan Detection

**What goes wrong:** When navigation is active and `cameraPosition = .userLocation(followsHeading: true)`, the `onMapCameraChange` callback fires on every GPS tick as the map auto-pans. This triggers `isOffNavCenter = true` even when the user hasn't touched the map.

**Why it happens:** `.userLocation(followsHeading:)` internally updates camera position, which fires `onMapCameraChange`.

**How to avoid:** Only set `isOffNavCenter = true` when the camera center diverges from the actual user location by a meaningful threshold (e.g., > 50m). The GPS tick-based auto-pan will keep the center within a few meters of the user location — only manual pan creates >50m divergence.

**Warning signs:** "Вернуться" button appears immediately after navigation start.

### Pitfall 3: Sheet Dismiss Interrupts Navigation

**What goes wrong:** User swipe-downs the navigation sheet to `.peek`. The existing `onChange(of: vm.sheetDetent)` handler calls `vm.dismissDetail()` which clears the route and stops navigation.

**Why it happens:** `dismissDetail()` was designed for search/place flow. Navigation reuses the same sheet infrastructure.

**How to avoid:** Guard the `dismissDetail()` call in TripMapView:
```swift
.onChange(of: vm.sheetDetent) { oldDetent, newDetent in
    if newDetent == .peek && oldDetent != .peek && !vm.isNavigating {
        vm.dismissDetail()
    }
}
```
When navigating, peek detent just collapses the sheet to the compact navigation strip — it should not dismiss the navigation.

**Warning signs:** Navigation stops when user collapses the bottom sheet.

### Pitfall 4: Urgency Color Flicker

**What goes wrong:** Distance oscillates around 50m due to GPS noise, causing the HUD urgency color to flicker between normal and pink.

**Why it happens:** Raw GPS distance to step endpoint has ±5-15m noise.

**How to avoid:** Use hysteresis — activate urgency below 50m, deactivate above 65m:
```swift
// In MapViewModel, track urgency as separate state
var isUrgent: Bool = false

// In NavigationEngine.onStepAdvanced callback:
if distance < 50 { vm.isUrgent = true }
else if distance > 65 { vm.isUrgent = false }
```

**Warning signs:** HUD background flickers rapidly when approaching a maneuver.

### Pitfall 5: Stop Navigation Returns to Wrong Sheet State

**What goes wrong:** After `stopNavigation()`, `sheetContent` is still `.navigation`. The map shows the route but the sheet shows nothing useful.

**Why it happens:** `stopNavigation()` in Phase 1 clears navigation state but does not set `sheetContent`.

**How to avoid:** After `stopNavigation()`, set `sheetContent = .routeInfo` and `sheetDetent = .half` — this returns user to the route info view with the active route still displayed.

```swift
func stopNavigation() {
    // ... existing cleanup ...
    isNavigating = false
    // Return to route info sheet
    withAnimation(.spring(response: 0.3)) {
        sheetContent = .routeInfo
        sheetDetent = .half
    }
}
```

**Warning signs:** After tapping "Завершить", sheet goes blank or collapses to peek.

---

## Code Examples

### NavigationHUDView skeleton

```swift
// Views/Map/NavigationHUDView.swift
import SwiftUI

struct NavigationHUDView: View {
    @Bindable var vm: MapViewModel
    @Environment(\.colorScheme) private var scheme

    private var currentStep: NavigationStep? {
        guard vm.currentStepIndex < vm.navigationSteps.count else { return nil }
        return vm.navigationSteps[vm.currentStepIndex]
    }

    var body: some View {
        HStack(spacing: 14) {
            // Direction icon with urgency color
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(vm.isUrgent ? AppTheme.sakuraPink : AppTheme.sakuraPink.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: maneuverIcon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(vm.isUrgent ? .white : AppTheme.sakuraPink)
                    .contentTransition(.symbolEffect(.replace))
            }
            .animation(.easeInOut(duration: 0.3), value: vm.currentStepIndex)

            // Instruction + distance
            VStack(alignment: .leading, spacing: 3) {
                Text(currentStep?.instruction ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: vm.currentStepIndex)

                Text(RoutingService.formatDistance(vm.distanceToNextStep))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(vm.isUrgent ? AppTheme.sakuraPink : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Dismiss (X) button
            Button { vm.stopNavigation() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous)
                .stroke(Color.white.opacity(scheme == .dark ? 0.12 : 0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private var maneuverIcon: String {
        guard let instruction = currentStep?.instruction else { return "arrow.up" }
        return Self.iconForInstruction(instruction)
    }

    static func iconForInstruction(_ instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("налево") || lower.contains("left") { return "arrow.turn.up.left" }
        if lower.contains("направо") || lower.contains("right") { return "arrow.turn.up.right" }
        if lower.contains("разворот") || lower.contains("u-turn") { return "arrow.uturn.left" }
        if lower.contains("слег") { return lower.contains("лев") ? "arrow.up.left" : "arrow.up.right" }
        if lower.contains("пункт") || lower.contains("прибыт") || lower.contains("destination") {
            return "mappin.circle.fill"
        }
        return "arrow.up"
    }
}
```

### MapRecenterButton skeleton

```swift
// Views/Map/MapRecenterButton.swift
import SwiftUI

struct MapRecenterButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("Вернуться")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppTheme.sakuraPink)
            )
            .shadow(color: AppTheme.sakuraPink.opacity(0.4), radius: 8, y: 4)
        }
        .transition(.scale.combined(with: .opacity))
    }
}
```

### NavigationSheetContent skeleton (peek state)

```swift
// Peek row — compact navigation strip
private var peekContent: some View {
    VStack(spacing: 0) {
        HStack(spacing: 12) {
            Image(systemName: NavigationHUDView.iconForInstruction(currentStep?.instruction ?? ""))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(currentStep?.instruction ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(tripContextLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(etaString)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("прибытие")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `MKMapView` delegate for camera | SwiftUI `MapCameraPosition` binding | Direct state binding, no delegate boilerplate |
| Manual SF Symbol swap + opacity | `.contentTransition(.symbolEffect(.replace))` | Native morph animation, iOS 17+ |
| Custom sheet drag implementation | `MapBottomSheet` (already built in Phase 1 UI setup) | Exists — just add new content case |
| `cameraPosition = .region(...)` to follow user | `.userLocation(followsHeading: true, fallback:)` | Built-in heading-aware tracking |

**Deprecated/outdated:**
- `MKMapView.userTrackingMode = .followWithHeading`: The UIKit approach. In SwiftUI MapKit, use `MapCameraPosition.userLocation(followsHeading: true)` instead.
- `MapUserTrackingButton`: Provides similar recenter UX but adds unwanted chrome. Custom `MapRecenterButton` integrates better with glassmorphism design.

---

## Open Questions

1. **`vm.isUrgent` property location**
   - What we know: Urgency needs hysteresis; `onStepAdvanced` callback runs on every GPS tick
   - What's unclear: Should `isUrgent` live in `MapViewModel` (simpler binding) or `NavigationEngine` (closer to data)?
   - Recommendation: Place in `MapViewModel` — it's UI state, not engine logic. Set in the `onStepAdvanced` closure inside `startNavigation()`.

2. **`MapSheetContent` enum location**
   - What we know: The enum is defined at top of `TripMapView.swift` (not a separate file)
   - What's unclear: Whether to move it to its own file for cleanliness
   - Recommendation: Add `.navigation` case in-place in `TripMapView.swift` — moving the enum is out of scope.

3. **Navigation sheet on `.peek` detent interaction**
   - What we know: Collapsing to peek currently triggers `dismissDetail()` via `onChange`
   - What's unclear: Whether the peek state during navigation should show a minimal strip or nothing
   - Recommendation: Guard `dismissDetail()` with `!vm.isNavigating` (see Pitfall 3); peek shows compact `NavigationSheetContent` peek row.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing, in `Travel appTests/`) |
| Config file | None separate — Xcode target configuration |
| Quick run command | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -only-testing:"Travel appTests/NavigationUITests"` |
| Full suite command | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NAV-06 | `startNavigation()` called when button tapped; `isNavigating` becomes true | unit | `xcodebuild test ... -only-testing:"Travel appTests/NavigationUITests/testStartNavigationButtonSetsIsNavigating"` | ❌ Wave 0 |
| UI-01 | HUD visible when `isNavigating == true`; hidden when false | unit | `xcodebuild test ... -only-testing:"Travel appTests/NavigationUITests/testHUDVisibility"` | ❌ Wave 0 |
| UI-01 | `maneuverIcon(for:)` maps instruction strings to correct SF Symbols | unit | `xcodebuild test ... -only-testing:"Travel appTests/NavigationUITests/testManeuverIconMapping"` | ❌ Wave 0 |
| UI-02 | `sheetContent` becomes `.navigation` after `startNavigation()` | unit | `xcodebuild test ... -only-testing:"Travel appTests/NavigationUITests/testSheetContentBecomesNavigation"` | ❌ Wave 0 |
| UI-03 | `tripContextLabel` returns correct "День N из M — City" string | unit | `xcodebuild test ... -only-testing:"Travel appTests/NavigationUITests/testTripContextLabel"` | ❌ Wave 0 |
| UI-04 | Stop does not accidentally call `dismissDetail()` | unit | `xcodebuild test ... -only-testing:"Travel appTests/NavigationUITests/testStopNavigationReturnsToRouteInfo"` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Run `testManeuverIconMapping` and `testTripContextLabel` (pure logic, no simulator needed)
- **Per wave merge:** Full `NavigationUITests` suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `Travel appTests/NavigationUITests.swift` — covers all 6 test cases above
  - `testManeuverIconMapping`: pure function, no async, highest value
  - `testTripContextLabel`: pure computed property, no async
  - `testStartNavigationButtonSetsIsNavigating`: requires mock NavigationEngine or testable MapViewModel
  - `testSheetContentBecomesNavigation`: requires MapViewModel with mocked route
  - `testStopNavigationReturnsToRouteInfo`: verifies sheetContent = .routeInfo after stop
  - `testHUDVisibility`: SwiftUI view test or ViewModel state check

Note: Tests that require real GPS/heading are manual-only (physical device). Unit tests cover all pure-logic behaviors.

---

## Sources

### Primary (HIGH confidence)

- Direct code inspection of `MapViewModel.swift`, `MapBottomSheet.swift`, `MapRouteContent.swift`, `NavigationEngine.swift`, `TripMapView.swift`, `AppTheme.swift`, `GlassComponents.swift`, `NavigationModels.swift` — all existing implementation patterns verified
- Apple MapKit SwiftUI documentation for `MapCameraPosition.userLocation(followsHeading:fallback:)` — standard iOS 17+ API

### Secondary (MEDIUM confidence)

- `contentTransition(.symbolEffect(.replace))` — iOS 17+ API, consistent with project target (iOS 26.2 simulator / recent iPhone)
- SF Symbol direction names (`arrow.turn.up.left`, `arrow.turn.up.right`, etc.) — verified against SF Symbols naming conventions

### Tertiary (LOW confidence)

- Instruction string keyword patterns for Russian MKDirections output — based on known Apple Maps localization; actual strings may vary by region. The `maneuverIcon(for:)` function has a safe fallback (`"arrow.up"`) for unmatched patterns.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components directly read from existing codebase
- Architecture: HIGH — patterns derived from existing code in the same project
- Pitfalls: HIGH — derived from reading actual Phase 1 implementation and identifying integration gaps
- Instruction string parsing: MEDIUM — keyword patterns are reasonable assumptions; real strings need validation on device

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable APIs; MapKit SwiftUI changes slowly)
