# Phase 03: Route Selection - Research

**Researched:** 2026-03-20
**Domain:** SwiftUI route alternatives carousel, MapKit/Google Routes API multi-route parsing, MapViewModel state extension
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Отображение альтернатив на карте**
- Только 1 (активный) polyline на карте — яркий, цвет режима транспорта
- Альтернативы НЕ показываются на карте как polyline — только в карточках sheet
- При выборе другой карточки polyline меняется с анимацией

**Карточки альтернатив в sheet**
- Горизонтальная карусель (ScrollView .horizontal) под transport pills
- Каждая карточка: ETA + расстояние + авто-метка
- Авто-метки: «Быстрый» (минимальный ETA), «Короткий» (минимальная дистанция)
- Первый маршрут (fastest) предвыбран по умолчанию
- Glassmorphism стиль карточек, выбранная — sakuraPink обводка
- Для transit: количество пересадок вместо расстояния

**UX выбора маршрута**
- Тап по карточке в карусели = выбор маршрута
- Polyline на карте обновляется, route stats обновляются, step list обновляется
- Без тапа по polyline на карте (1 polyline = нечего тапать)

**Переключение транспорта**
- Альтернативы загружаются для КАЖДОГО режима транспорта
- Transport pill тап → загрузка 2-3 альтернатив для этого режима → карусель обновляется
- Loading state на карусели пока загружаются альтернативы
- ETA previews (Distance Matrix) продолжают работать как сейчас для всех pills

**Сравнение маршрутов**
- Информация на карточке: ETA (крупно) + расстояние + метка
- Для transit: ETA + количество пересадок + метка
- trafficDuration НЕ показывается отдельно (слишком сложно для карточки)
- Детальная информация (traffic, шаги) — при выборе маршрута в основном route stats

### Claude's Discretion
- Размеры карточек в карусели и spacing
- Анимация переключения polyline на карте
- Логика определения «Быстрый»/«Короткий» при равных значениях
- Обработка случаев когда API возвращает только 1 маршрут (скрыть карусель или показать 1 карточку)
- Loading skeleton для карусели

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ROUTE-01 | Построение маршрута через MKDirections с 2-3 альтернативными вариантами | Google Routes API `routes[]` array already returns multiple routes — need to parse all, not just `routes.first`. MKDirections also supports `requestsAlternateRoutes = true`. Existing `calculateRoutesAPIRoute` parses only `routes.first` — one-line change to parse all. |
| ROUTE-02 | Переключение транспортного режима (пешком, авто, транспорт, велосипед) | Already implemented via `TransportMode` enum + transport pills UI. Phase 3 adds per-mode alternative arrays: on pill tap, `alternativeRoutes` is refreshed. The pill tap already calls `recalculateRoute()` in `MapRouteContent`. |
| ROUTE-03 | Отображение ETA и расстояния для каждого транспортного режима одновременно | ETA previews already fetched in parallel via `fetchETAPreviews` (Distance Matrix). Phase 3 adds the carousel below transport pills so all 4 pill ETAs remain visible while selected-mode alternatives are shown in the carousel. |
</phase_requirements>

---

## Summary

Phase 3 is a focused augmentation of the already-working routing pipeline. `RoutingService.calculateRoute` currently parses only `routes.first` from the Google Routes API response, but the API already returns an array. The core work is: (1) widen the return type to `[RouteResult]`, (2) add `alternativeRoutes` + `selectedRouteIndex` to `MapViewModel`, (3) insert a horizontal carousel of `RouteAlternativeCard` views between the transport pills and the route stats row in `MapRouteContent`.

The UI-SPEC (already approved) fully specifies card dimensions (140×88pt), typography, badge logic, loading skeleton, accessibility labels, and the polyline animation contract. The planner should treat the UI-SPEC as the authoritative visual contract and focus task breakdowns on the data flow changes.

Google Directions (transit) returns a single route — the carousel will render 1 card for transit mode. This is correct behavior with no special-casing needed. The `alternativeRoutes` cache must be per-mode (keyed by `TransportMode`) in `MapViewModel` so switching modes back doesn't re-fetch.

**Primary recommendation:** Modify `RoutingService.calculateRoute` to return `[RouteResult]`, extend `MapViewModel` with `alternativeRoutes`/`selectedRouteIndex`, add `RouteAlternativeCard.swift`, and wire the carousel into `MapRouteContent.swift`. All other files (`TripMapView`, `NavigationHUDView`) are unchanged.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ (project target) | Carousel via `ScrollView(.horizontal)` + `HStack` | Already the project UI framework |
| MapKit | iOS 17+ | `MapPolyline` rendering of `activeRoute.polyline` | Already in use; no change to rendering path |
| Google Routes API v2 | via SupabaseProxy `google_routes` | Multi-route response (`routes[]` array) | Already integrated — only parsing change needed |
| Google Directions API | via SupabaseProxy `google_directions` | Transit route (single result) | Already integrated — no change |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `withTaskGroup` | Swift Concurrency | Parallel multi-route fetching (if needed) | Route-per-mode parallelism already established in `fetchETAPreviews` pattern |
| `@Observable` macro | Swift 5.9 | `MapViewModel` state extension | Already the pattern — add new properties directly |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ScrollView(.horizontal) + HStack | UICollectionView | ScrollView is sufficient for 2-3 cards; UICollectionView adds UIKit bridging complexity |
| Fixed card width (140pt) | GeometryReader adaptive | Fixed width is simpler, hints overflow without geometry math |

**Installation:**
No new packages required. All APIs are accessed via the existing `SupabaseProxy`.

---

## Architecture Patterns

### Recommended Project Structure

No new directories. Changes are confined to:
```
Travel app/Services/RoutingService.swift         # return type: [RouteResult] instead of RouteResult?
Travel app/Views/Map/MapViewModel.swift          # add alternativeRoutes, selectedRouteIndex
Travel app/Views/Map/MapRouteContent.swift       # insert carousel section
Travel app/Views/Map/RouteAlternativeCard.swift  # NEW: standalone card view
```

### Pattern 1: Multi-Route Return from RoutingService

**What:** `calculateRoute` returns `[RouteResult]` (empty array on failure, 1+ on success).
**When to use:** Drives both `MapViewModel.alternativeRoutes` and the legacy `activeRoute` (set to `[0]` for backward compat).

```swift
// In RoutingService.calculateRoutesAPIRoute — parse all routes, not just first
guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let routes = json["routes"] as? [[String: Any]],
      !routes.isEmpty else {
    lastError = "Маршрут не найден"
    return []
}
let results = routes.map { parseRoutesAPIResponse($0, mode: mode) }
// Cache only the first (fastest) by cacheKey; alternatives don't need individual caching
cache[cacheKey] = results[0]
return results
```

Transit route stays single-result (Google Directions returns 1). Return `[result]` instead of `result`.

### Pattern 2: MapViewModel State Extension

**What:** New properties on `MapViewModel` to track alternatives without breaking existing `activeRoute` consumers.
**When to use:** Anytime route alternatives are loaded or mode is switched.

```swift
// Add to MapViewModel @Observable
var alternativeRoutes: [RouteResult] = []
var selectedRouteIndex: Int = 0

var selectedRoute: RouteResult? {
    guard selectedRouteIndex < alternativeRoutes.count else { return nil }
    return alternativeRoutes[selectedRouteIndex]
}

// After calculateRoute returns [RouteResult]:
alternativeRoutes = results
selectedRouteIndex = 0
activeRoute = results.first   // keeps all downstream consumers (navigation, stats) unchanged
```

### Pattern 3: RouteAlternativeCard View

**What:** Fixed-size glassmorphism card with ETA hero + distance/transfers + optional badge.
**When to use:** Instantiated in the carousel `ForEach` loop.

Card state drives visual via `isSelected` parameter — no internal state needed (card is dumb).

```swift
// RouteAlternativeCard.swift
struct RouteAlternativeCard: View {
    let route: RouteResult
    let isSelected: Bool
    let badge: RouteBadge?   // enum: .fastest, .shortest, nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                // Row 1: icon + badge
                // Row 2: ETA (22pt bold rounded, mode.color)
                // Row 3: distance or transfer count (13pt medium, secondary)
            }
            .padding(AppTheme.spacingM)
            .frame(width: 140, height: 88)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(
                        isSelected ? AppTheme.sakuraPink : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .shadow(
                color: isSelected ? AppTheme.sakuraPink.opacity(0.12) : .black.opacity(0.06),
                radius: isSelected ? 12 : 8
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isSelected)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
```

### Pattern 4: Carousel in MapRouteContent

**What:** `ScrollView(.horizontal)` + `HStack` inserted between `transportModePills` and `routeStatsRow`.

```swift
// In MapRouteContent.body VStack:
transportModePills(route: route)
    .padding(.top, 12)

// NEW: Route alternatives carousel
routeAlternativesCarousel
    .padding(.top, AppTheme.spacingS)   // 8pt above

// Existing:
routeStatsRow(route: route)
    .padding(.top, AppTheme.spacingM)   // 16pt before stats
```

Carousel implementation:
```swift
private var routeAlternativesCarousel: some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: AppTheme.spacingS) {
            if vm.isCalculatingRoute {
                // 2 skeleton cards
                ForEach(0..<2, id: \.self) { _ in
                    RouteAlternativeCardSkeleton()
                }
            } else if !vm.alternativeRoutes.isEmpty {
                ForEach(Array(vm.alternativeRoutes.enumerated()), id: \.offset) { index, route in
                    RouteAlternativeCard(
                        route: route,
                        isSelected: index == vm.selectedRouteIndex,
                        badge: badgeFor(index: index),
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                vm.selectedRouteIndex = index
                                vm.activeRoute = route
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
```

### Pattern 5: Badge Logic

```swift
private func badgeFor(index: Int) -> RouteBadge? {
    let routes = vm.alternativeRoutes
    guard routes.count > 1 else { return nil }
    let fastestIdx = routes.indices.min(by: { routes[$0].expectedTravelTime < routes[$1].expectedTravelTime })
    let shortestIdx = routes.indices.min(by: { routes[$0].distance < routes[$1].distance })
    if index == fastestIdx { return .fastest }
    if index == shortestIdx { return .shortest }
    return nil
}
```

If `fastestIdx == shortestIdx` the same card gets `.fastest` (per UI-SPEC: "if same route wins both, show «Быстрый»").

### Pattern 6: Loading Skeleton

```swift
struct RouteAlternativeCardSkeleton: View {
    @State private var opacity: Double = 0.4

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 40, height: 20)   // ETA slot
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 60, height: 13)   // distance slot
        }
        .padding(AppTheme.spacingM)
        .frame(width: 140, height: 88)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                opacity = 1.0
            }
        }
    }
}
```

### Anti-Patterns to Avoid

- **Storing alternative routes in RoutingService cache by index:** The existing `cache[cacheKey]` stores the first route. Don't add per-alternative cache entries — they would bloat the cache and complicate invalidation. Only the first route (fastest) is cached.
- **Mutating `activeRoute` from inside `RouteAlternativeCard`:** Card is dumb; `onTap` closure owns the mutation. Keeps card reusable.
- **Rebuilding the entire MapRouteContent on `alternativeRoutes` change:** `@Observable` on `MapViewModel` already triggers minimal re-renders. No explicit `.id()` invalidation needed on the carousel.
- **Parallel multi-route fetches across all modes on pill tap:** Only fetch the tapped mode's alternatives. The ETA previews (Distance Matrix) already cover all modes simultaneously. Fetching 3 alternatives for all 4 modes simultaneously on every pill tap = 12 API calls. Wrong.
- **Forgetting to reset `selectedRouteIndex = 0` on mode switch:** If user switches from auto (index 1 selected) to walking, index 1 may not exist. Always reset to 0 when `alternativeRoutes` is replaced.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Horizontal scroll with paging/snapping | Custom `DragGesture` scroll | `ScrollView(.horizontal)` | SwiftUI handles momentum, accessibility, and RTL |
| Encoded polyline decode | Custom parser | `RoutingService.decodeGooglePolyline` (already exists) | Edge cases in Google's polyline encoding are already handled |
| Russian noun declension for transfer count | Custom switch statement | Simple inline switch on `count % 10` + `count % 100` | Standard Russian pluralization — don't over-engineer, just write the 3-case switch |
| Shimmer animation | 3rd-party shimmer lib | Keyframe `opacity` animation on `@State` | Simple opacity oscillation is sufficient; no new dependencies |

**Key insight:** The routing infrastructure (API proxy, polyline decoder, duration/distance formatters) is complete. Phase 3 is UI + data model wiring, not new API integration.

---

## Common Pitfalls

### Pitfall 1: `calculateRoute` callers receive `RouteResult?`, not `[RouteResult]`

**What goes wrong:** After changing the return type to `[RouteResult]`, all call sites in `MapViewModel` (`calculateDirectionRoute`, `calculateRouteToSearchedItem`, `rerouteNavigation`) break at compile time.
**Why it happens:** The signature change is breaking — Swift won't silently coerce.
**How to avoid:** Update all call sites in the same commit. `rerouteNavigation` only needs `newRoute` (single) — it can take `results.first` from the array. The navigation reroute does NOT show the carousel, so `alternativeRoutes` is not updated during active navigation.
**Warning signs:** Compiler errors on `if let result = await calculateRoute(...)`.

### Pitfall 2: `selectedRouteIndex` out of bounds after mode switch

**What goes wrong:** User selects route index 2 on automobile mode. Switches to walking — walking returns only 1 route. `alternativeRoutes[2]` crashes.
**Why it happens:** `selectedRouteIndex` is not reset when `alternativeRoutes` changes.
**How to avoid:** Always set `selectedRouteIndex = 0` immediately when assigning `alternativeRoutes`.
**Warning signs:** Index out of range crash in `selectedRoute` computed property.

### Pitfall 3: Transit alternatives — Google Directions API returns 1 route only

**What goes wrong:** Expecting 2-3 transit alternatives and getting 1 confuses the carousel.
**Why it happens:** Google Directions API (used for transit) does not support `alternatives=true` in the same way Routes API does. The `calculateGoogleTransitRoute` path always returns a single result.
**How to avoid:** When transit path returns a single `RouteResult`, wrap it in `[result]`. The carousel renders 1 card — that's correct per UI-SPEC.
**Warning signs:** Empty carousel on transit mode selection despite a valid route.

### Pitfall 4: `inFlightKeys` in RoutingService blocks second call for same coordinates

**What goes wrong:** User taps transport pill while a previous mode's route is still calculating for the same origin/destination. The `inFlightKeys` check returns `nil` immediately and the carousel stays empty.
**Why it happens:** `inFlightKeys` is keyed by `cacheKey` which encodes coordinates AND mode. Different modes have different keys — this is safe. However, if the same mode is re-requested (e.g., user taps same pill twice), the in-flight guard blocks the second call and returns `nil` / empty array.
**How to avoid:** The existing in-flight guard is per-mode. No change needed. But: after changing return type to `[RouteResult]`, the guard must return `[]` (empty array) instead of `nil`.
**Warning signs:** Carousel shows skeletons forever when same pill tapped twice rapidly.

### Pitfall 5: `activeRoute` vs `selectedRoute` inconsistency during navigation reroute

**What goes wrong:** During active navigation, `rerouteNavigation` sets `activeRoute` directly. If `alternativeRoutes` is also populated, they become out of sync.
**Why it happens:** `rerouteNavigation` bypasses the carousel entirely (navigation mode has no carousel visible).
**How to avoid:** During `rerouteNavigation`, clear `alternativeRoutes = []` and set `selectedRouteIndex = 0` when the new single reroute result arrives. This prevents a stale carousel from appearing if user stops navigation.
**Warning signs:** Carousel shows old alternatives after stopping navigation and returning to route info sheet.

### Pitfall 6: Routes API `routes[]` order is not guaranteed fastest-first

**What goes wrong:** Code assumes `routes[0]` is always fastest. User sees "Быстрый" badge on wrong card.
**Why it happens:** Google Routes API sorts by `routePreference`. With `TRAFFIC_AWARE` (used for DRIVE), `routes[0]` is the recommended route but not guaranteed minimum duration.
**How to avoid:** Apply badge logic by computing `min(expectedTravelTime)` over the returned array regardless of position. Do not assume index 0 = fastest.
**Warning signs:** Badge and actual minimum ETA disagree.

---

## Code Examples

### Changing calculateRoute return type (RoutingService)

```swift
// Source: existing RoutingService.swift — modification pattern
func calculateRoute(
    from origin: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D,
    mode: TransportMode
) async -> [RouteResult] {   // was: RouteResult?
    // ...existing cache check returns [cached] if found
    // ...transit path returns [result] wrapping single result
    // ...routes API path returns array from parseRoutesAPIResponse
}

private func calculateRoutesAPIRoute(...) async -> [RouteResult] {
    // ...
    let results = routes.prefix(3).map { parseRoutesAPIResponse($0, mode: mode) }
    cache[cacheKey] = results[0]   // cache fastest
    return Array(results)
}
```

`prefix(3)` caps the array at 3 alternatives matching the "2-3 варианта" requirement.

### MapViewModel call site update

```swift
// In calculateDirectionRoute(to:) — existing pattern, updated for array
let results = await RoutingService.shared.calculateRoute(
    from: origin, to: destination, mode: selectedTransportMode
)

if !results.isEmpty {
    withAnimation(.spring(response: 0.3)) {
        alternativeRoutes = results
        selectedRouteIndex = 0
        activeRoute = results[0]
        sheetContent = .routeInfo
        sheetDetent = .half
    }
    zoomToRoute(results[0])
    // ... navigation steps, ETA previews unchanged
} else {
    routeError = RoutingService.shared.lastError ?? "Маршрут не найден"
}
```

### Russian declension for transfer count (inline)

```swift
// In RouteAlternativeCard — for transit mode
private func transfersLabel(_ count: Int) -> String {
    let rem10 = count % 10
    let rem100 = count % 100
    if rem100 >= 11 && rem100 <= 14 { return "\(count) пересадок" }
    switch rem10 {
    case 1:  return "\(count) пересадка"
    case 2, 3, 4: return "\(count) пересадки"
    default: return "\(count) пересадок"
    }
}

// Transfer count = number of TRANSIT steps (not walking segments)
private var transferCount: Int {
    route.transitSteps.filter { $0.travelMode == "TRANSIT" }.count
}
```

### RouteBadge enum (new, in RouteAlternativeCard.swift)

```swift
enum RouteBadge {
    case fastest   // «Быстрый»
    case shortest  // «Короткий»

    var label: String {
        switch self {
        case .fastest:  return "Быстрый"
        case .shortest: return "Короткий"
        }
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `calculateRoute` returns `RouteResult?` | Returns `[RouteResult]` | Phase 3 | All callers updated; reroute during navigation uses `.first` |
| `activeRoute: RouteResult?` only in MapViewModel | `alternativeRoutes: [RouteResult]` + `selectedRouteIndex` + `activeRoute` | Phase 3 | Carousel reads from `alternativeRoutes`, navigation reads from `activeRoute` (kept in sync) |
| No carousel in sheet | Horizontal carousel between pills and stats | Phase 3 | ROUTE-01, ROUTE-02, ROUTE-03 satisfied |

**No deprecations in this phase.** Existing `ModeETAPreview` and `fetchETAPreviews` are unchanged.

---

## Open Questions

1. **Routes API `computeAlternativeRoutes` field**
   - What we know: The `google_routes` Supabase Edge Function must send `"computeAlternativeRoutes": true` in the request body for Routes API v2 to return multiple routes. Without this flag, the API returns exactly 1 route.
   - What's unclear: Whether the existing Edge Function already sets this field.
   - Recommendation: Planner must include a task to verify and update the `api-proxy` Edge Function (`google_routes` handler) to add `"computeAlternativeRoutes": true`. This is a server-side change, not Swift-side.

2. **Cache invalidation when alternatives are fetched**
   - What we know: The existing cache uses `cacheKey` (coordinates + mode) and stores only the first result. With multi-route, the first result is still cached — no structural problem.
   - What's unclear: Whether subsequent taps on the same pill (same mode, same route) should return cached alternatives or re-fetch.
   - Recommendation: Re-use single-route cache for the first result. Accept that re-tapping a pill fetches alternatives again (not cached). This keeps the cache simple and avoids stale alternatives after network changes. The performance cost is negligible since the carousel is not shown until selection.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (manual setup in Xcode target required per STATE.md) |
| Config file | None — test target must be added manually in Xcode |
| Quick run command | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -only-testing:TravelAppTests/RouteSelectionTests` |
| Full suite command | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ROUTE-01 | `calculateRoute` returns 2-3 alternatives for drive/walk/cycle modes | unit | `xcodebuild test ... -only-testing:.../RouteSelectionTests/testCalculateRouteReturnsMultipleResults` | ❌ Wave 0 |
| ROUTE-01 | Badge logic: fastest and shortest correctly identified | unit | `xcodebuild test ... -only-testing:.../RouteSelectionTests/testBadgeAssignment` | ❌ Wave 0 |
| ROUTE-02 | Switching transport mode resets `selectedRouteIndex` to 0 | unit | `xcodebuild test ... -only-testing:.../RouteSelectionTests/testModeSwitch_ResetsIndex` | ❌ Wave 0 |
| ROUTE-02 | `selectedRouteIndex` out-of-bounds guard (index reset when alternatives shrink) | unit | `xcodebuild test ... -only-testing:.../RouteSelectionTests/testIndexOutOfBoundsOnModeSwitch` | ❌ Wave 0 |
| ROUTE-03 | Transit mode returns single-element array (not empty) | unit | `xcodebuild test ... -only-testing:.../RouteSelectionTests/testTransitReturnsSingleElement` | ❌ Wave 0 |
| ROUTE-03 | Russian declension for transfer count (1/2/5/11) | unit | `xcodebuild test ... -only-testing:.../RouteSelectionTests/testTransferCountDeclension` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"` (compile check)
- **Per wave merge:** Full unit test suite for RouteSelectionTests
- **Phase gate:** All 6 unit tests green + visual carousel inspection on simulator before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `TravelAppTests/RouteSelectionTests.swift` — covers ROUTE-01, ROUTE-02, ROUTE-03
- [ ] Test target must be added manually in Xcode (per STATE.md known blocker)

---

## Sources

### Primary (HIGH confidence)
- Direct source code inspection: `RoutingService.swift`, `MapViewModel.swift`, `MapRouteContent.swift`, `TripMapView.swift`, `AppTheme.swift`, `GlassComponents.swift` — all patterns verified from actual project code
- `03-CONTEXT.md` — user decisions, locked constraints, canonical file list
- `03-UI-SPEC.md` (approved) — card dimensions, typography, color tokens, interaction contracts, accessibility
- `REQUIREMENTS.md` — ROUTE-01/02/03 definitions

### Secondary (MEDIUM confidence)
- Google Routes API documentation (verified from existing `calculateRoutesAPIRoute` implementation): `computeAlternativeRoutes` boolean field controls multi-route response; `routes[]` array is already present in response
- Russian pluralization rules — standard linguistic rule (10/100 modulo pattern)

### Tertiary (LOW confidence)
- Google Routes API response guarantee that `routes[0]` = recommended route: inferred from existing code behavior + common API knowledge; not independently verified against current API docs

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in use, no new dependencies
- Architecture: HIGH — patterns derived from existing code, not speculative
- Pitfalls: HIGH — derived from code analysis of existing call sites and data flow
- Open questions: MEDIUM — `computeAlternativeRoutes` flag needs server-side verification

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (Google Routes API is stable; project architecture is established)
