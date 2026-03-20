# Phase 4: Offline Routes — Research

**Researched:** 2026-03-20
**Domain:** SwiftData route caching, offline-first architecture, iOS MapKit/MKDirections
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Предзагрузка маршрутов**
- Кэшируются ВСЕ пары мест дня (N² — каждое к каждому), не только последовательные
- 2 транспортных режима: пешком + авто (transit расписания устаревают, вело — редкий)
- Только лучший маршрут per mode (не альтернативы) — меньше данных
- NavigationSteps кэшируются вместе с маршрутом — полный офлайн turn-by-turn
- Только снапшоты карт НЕ включены (уже есть в OfflineCacheManager.preCacheTrip)
- Загрузка параллельная (withTaskGroup), все запросы одновременно
- Скоуп: за день (кнопка на каждом дне), не за всю поездку
- Кнопка расположена на карте дня (TripMapView) — floating или в bottom sheet idle

**Прогресс и уведомление**
- Прогресс-кольцо (circular) с процентом и текстом «Загрузка маршрутов...»
- По завершении: кнопка меняется на «✓ Маршруты готовы» с зелёным акцентом
- Иконка на карте дня показывает что день подготовлен офлайн
- Без push-напоминаний о предзагрузке перед поездкой

**Cache-first поведение**
- Онлайн: ВСЕГДА свежий маршрут из API (сеть приоритет). Кэш — только для офлайн
- Офлайн: SwiftData кэш, прозрачно для пользователя (маршрут выглядит как обычный)
- Ключ кэша: originPlaceUUID + destPlaceUUID + mode (не координаты — избегаем GPS дрифт)
- Маршруты от GPS-позиции (не из Place) НЕ кэшируются — только Place→Place
- TTL: 7 дней (покрывает типичную поездку)
- Двухуровневый кэш: L1 in-memory (быстрый, текущая сессия) + L2 SwiftData (персистентный)

**Фоновое обновление**
- При открытии карты дня + есть Wi-Fi + есть устаревшие кэши → тихо обновить в фоне
- Только ручная предзагрузка, без автоматических обновлений в других контекстах

**Офлайн UX**
- Кэш есть: маршрут показывается как обычный, никакой разницы (OfflineBanner уже информирует)
- Кэша нет: сообщение «Маршрут недоступен офлайн. Подготовьте маршруты заранее при наличии сети» + CTA
- Карусель альтернатив: скрыта офлайн
- Transport pills: все 4 показываются, при тапе на некэшированный — сообщение «недоступно офлайн»
- ETA previews: из кэшированного RouteResult (distance + expectedTravelTime) для доступных режимов, «—» для остальных
- Офлайн-навигация: разрешена по кэшированному маршруту, НО при отклонении — предупреждение вместо reroute

**Хранение и очистка**
- Cascade delete: удалил Trip → кэши маршрутов удаляются
- Ручная кнопка «Очистить кэш маршрутов» в Settings
- Без лимита размера (маршруты легковесные ~1-5KB, TTL 7 дней достаточен)

### Claude's Discretion
- Точная структура CachedRoute @Model (поля, индексы)
- Сериализация RouteResult и NavigationStep в SwiftData
- Механика L1→L2 синхронизации и инвалидации in-memory кэша
- UI расположение кнопки «Подготовить офлайн» на карте (floating vs sheet)
- Анимация прогресс-кольца
- Логика фонового обновления (debounce, приоритизация)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| OFFL-01 | CachedRoute @Model в SwiftData для хранения сериализованных маршрутов | SwiftData @Model patterns from OfflineMapCache; JSON serialization for CLLocationCoordinate2D arrays and NavigationStep arrays |
| OFFL-02 | Cache-first lookup в RoutingService (офлайн маршрут если есть в кэше) | RoutingService.calculateRoute entry point identified; L1 dict + L2 SwiftData query pattern; NWPathMonitor isOnline check from OfflineCacheManager |
| OFFL-03 | Кнопка "Подготовить офлайн" — предзагрузка маршрутов между всеми местами дня | withTaskGroup pattern already in fetchETAPreviews; TripDay.sortedPlaces provides place pairs; progress ring from PackingListView pattern |
| OFFL-04 | Graceful degradation при отсутствии сети — сообщение "маршруты сохранены, тайлы зависят от подключения" | MapRouteContent offline banner placement; NavigationEngine offline reroute suppression; transport pill tap handler modification |
</phase_requirements>

---

## Summary

Phase 4 adds offline route caching using two existing project patterns as its foundation: `OfflineMapCache` (SwiftData `@Model` with `@Attribute(.externalStorage)`) and `OfflineCacheManager` (`NWPathMonitor`, `preCacheTrip` with `withTaskGroup`). The implementation is purely additive — it does not break existing online behavior, only inserts a cache lookup before API calls when offline.

The hardest design problem is **serializing `RouteResult`** (which contains `[CLLocationCoordinate2D]`, `[NavigationStep]`, and `[TransitStep]`) into SwiftData. SwiftData cannot store these types directly — they require JSON encoding as `Data` fields. The `@Attribute(.externalStorage)` pattern used by `OfflineMapCache` is appropriate for these blobs.

The integration surface is narrow: modify `RoutingService.calculateRoute` (one file), add a pre-caching method to `OfflineCacheManager` (one file), add a floating button in `TripMapView` bottom sheet idle state (one file), hide the alternatives carousel in `MapRouteContent` when offline (one file), and suppress reroute in `NavigationEngine` when offline (one file).

**Primary recommendation:** Implement `CachedRoute @Model` with JSON-encoded `Data` blobs for polyline + steps, keyed by `originPlaceID + destinationPlaceID + mode`, accessed via `@Observable RoutingCacheService` singleton that wraps the L1 dict and L2 SwiftData query.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ built-in | CachedRoute persistence | Already the project's ORM; OfflineMapCache is the exact pattern |
| Foundation (JSONEncoder/JSONDecoder) | Built-in | Serialize CLLocationCoordinate2D and NavigationStep arrays | No Codable conformance on CLLocationCoordinate2D — must wrap in a DTO struct |
| Network (NWPathMonitor) | Built-in | Detect online/offline state | Already running in OfflineCacheManager.shared |
| MapKit (MKDirections) | Built-in | Step fetching (walk/drive) | Already used in fetchNavigationSteps — offline-capable for MKDirections requests |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Concurrency (withTaskGroup) | Swift 5.9+ | Parallel route pre-fetching | Already used in fetchETAPreviews — same pattern for N² pairs |
| SwiftUI (Circle.trim) | Built-in | Progress ring animation | Pattern exists in PackingListView lines 130-136 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| JSON-encoded Data blobs | Transformable @Attribute | Transformable is deprecated in SwiftData; JSON encoding is explicit and debuggable |
| @Attribute(.externalStorage) for route Data | Inline Data | externalStorage keeps SwiftData store small for frequently-queried small records; but route blobs are only ~1-5KB so inline is also acceptable |
| UUID-keyed cache | Coordinate-keyed cache | UUID key avoids GPS drift; settled in CONTEXT.md |

**Installation:** No new dependencies — all standard Apple frameworks.

---

## Architecture Patterns

### Recommended Project Structure

```
Travel app/
├── Models/
│   └── CachedRoute.swift           # @Model with JSON-encoded blobs (NEW)
├── Services/
│   ├── RoutingService.swift        # Add offline lookup (MODIFY)
│   ├── OfflineCacheManager.swift   # Add preCacheDay method (MODIFY)
│   └── RoutingCacheService.swift   # L1+L2 cache logic, singleton (NEW)
└── Views/
    ├── Map/
    │   ├── TripMapView.swift       # Add "Подготовить офлайн" button (MODIFY)
    │   └── MapRouteContent.swift   # Hide carousel offline, add no-cache message (MODIFY)
    ├── Settings/
    │   └── SettingsView.swift      # Add "Очистить кэш маршрутов" button (MODIFY)
    └── Shared/
        └── OfflinePrecacheButton.swift  # Reusable precache button+progress (NEW)
```

### Pattern 1: CachedRoute @Model — SwiftData Serialization

**What:** Store `RouteResult` in SwiftData by JSON-encoding non-native types.
**When to use:** Any time complex structs with non-Codable types (CLLocationCoordinate2D) need persistence.

```swift
// CachedRoute.swift
@Model
final class CachedRoute {
    @Attribute(.unique) var id: UUID
    var originPlaceID: UUID
    var destinationPlaceID: UUID
    var mode: String          // TransportMode.rawValue
    var createdAt: Date

    // JSON-encoded payloads
    var polylineData: Data    // [CoordDTO] encoded
    var navigationStepsData: Data  // [NavigationStepDTO] encoded
    var distanceMeters: Double
    var expectedTravelTimeSeconds: Double

    // Cascade delete: trip relationship via TripDay→Place IDs
    // No direct Trip reference needed — UUID keys handle cascade via
    // fetchDescriptor with tripDay place IDs + manual cleanup on trip delete

    init(
        id: UUID = UUID(),
        originPlaceID: UUID,
        destinationPlaceID: UUID,
        mode: String,
        createdAt: Date = Date(),
        polylineData: Data,
        navigationStepsData: Data,
        distanceMeters: Double,
        expectedTravelTimeSeconds: Double
    ) { /* assign */ }
}

// DTOs for Codable serialization of non-Codable types
struct CoordDTO: Codable {
    let lat: Double
    let lng: Double
}

struct NavigationStepDTO: Codable {
    let instruction: String
    let distance: Double
    let polyline: [CoordDTO]
    let isTransit: Bool
}
```

### Pattern 2: RoutingCacheService — L1+L2 Cache

**What:** `@Observable` singleton wrapping in-memory dict (L1) and SwiftData (L2).
**When to use:** Any cache needing fast session access plus persistence.

```swift
// Source: established pattern from RoutingService.shared / OfflineCacheManager.shared
@MainActor @Observable
final class RoutingCacheService {
    static let shared = RoutingCacheService()
    private init() {}

    // L1: in-memory, current session
    private var l1: [String: RouteResult] = [:]

    // Cache key: deterministic string from two place UUIDs + mode
    func cacheKey(origin: UUID, destination: UUID, mode: TransportMode) -> String {
        "\(origin.uuidString)_\(destination.uuidString)_\(mode.rawValue)"
    }

    // L2 read: fetch from SwiftData via ModelContext
    func lookup(origin: UUID, dest: UUID, mode: TransportMode, context: ModelContext) -> RouteResult? {
        let key = cacheKey(origin: origin, destination: dest, mode: mode)
        if let hit = l1[key] { return hit }  // L1 fast path

        let descriptor = FetchDescriptor<CachedRoute>(
            predicate: #Predicate { $0.originPlaceID == origin && $0.destinationPlaceID == dest && $0.mode == mode.rawValue },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let cached = try? context.fetch(descriptor).first,
              cached.createdAt.timeIntervalSinceNow > -(7 * 24 * 3600) else { return nil }

        let result = cached.toRouteResult()
        l1[key] = result  // Populate L1
        return result
    }

    // L2 write
    func store(_ result: RouteResult, origin: UUID, dest: UUID, context: ModelContext) {
        let key = cacheKey(origin: origin, destination: dest, mode: result.mode)
        l1[key] = result
        // Insert/upsert into SwiftData
        let model = CachedRoute(from: result, originPlaceID: origin, destinationPlaceID: dest)
        context.insert(model)
        try? context.save()
    }

    // Invalidate L1 on app background/memory pressure
    func clearL1() { l1.removeAll() }

    // Full clear (Settings "Очистить кэш маршрутов")
    func clearAll(context: ModelContext) throws {
        l1.removeAll()
        try context.delete(model: CachedRoute.self)
        try context.save()
    }
}
```

### Pattern 3: OfflineCacheManager.preCacheDay — Parallel Pre-fetching

**What:** Add `preCacheDay` method alongside existing `preCacheTrip`, using same `withTaskGroup` pattern already in `fetchETAPreviews`.
**When to use:** Triggered by "Подготовить офлайн" button; scoped to a single day.

```swift
// Source: OfflineCacheManager.preCacheTrip + RoutingService.fetchETAPreviews patterns
extension OfflineCacheManager {
    /// Pre-cache all N² Place pairs for a day in 2 modes (walking + automobile).
    func preCacheDay(
        _ day: TripDay,
        context: ModelContext,
        progress: @escaping @MainActor (Double) -> Void
    ) async {
        let places = day.sortedPlaces
        guard places.count >= 2 else { return }

        // Build all unique ordered pairs (A→B and B→A are both needed)
        var pairs: [(Place, Place)] = []
        for i in 0..<places.count {
            for j in 0..<places.count where i != j {
                pairs.append((places[i], places[j]))
            }
        }

        let modes: [TransportMode] = [.walking, .automobile]
        let totalRequests = pairs.count * modes.count
        var completed = 0

        await withTaskGroup(of: Void.self) { group in
            for (origin, dest) in pairs {
                for mode in modes {
                    group.addTask {
                        let results = await RoutingService.shared.calculateRoute(
                            from: origin.coordinate, to: dest.coordinate, mode: mode
                        )
                        if let route = results.first {
                            await RoutingCacheService.shared.store(
                                route, origin: origin.id, dest: dest.id, context: context
                            )
                        }
                        await MainActor.run {
                            completed += 1
                            progress(Double(completed) / Double(totalRequests))
                        }
                    }
                }
            }
        }
    }
}
```

### Pattern 4: RoutingService Offline Intercept

**What:** Add cache-first lookup at the top of `calculateRoute`, ONLY when offline.
**When to use:** Called for every route request; context needs `ModelContext`.

Key insight: `RoutingService.calculateRoute` currently only takes coordinates, not Place UUIDs. The offline cache is keyed by Place UUID. The intercept needs a separate `calculatePlaceRoute` entry point that accepts Place UUIDs, or the MapViewModel must pass UUIDs alongside coordinates.

**Recommended approach:** Add a new `calculateRoute(fromPlace:toPlace:mode:context:)` overload. The existing `calculateRoute(from:to:mode:)` remains unchanged for GPS-origin routes (which are never cached).

```swift
// New overload in RoutingService
func calculateRoute(
    fromPlace origin: Place,
    toPlace destination: Place,
    mode: TransportMode,
    context: ModelContext
) async -> [RouteResult] {
    // Online: bypass cache (per CONTEXT.md decision)
    if OfflineCacheManager.shared.isOnline {
        return await calculateRoute(from: origin.coordinate, to: destination.coordinate, mode: mode)
    }

    // Offline: L1+L2 lookup
    if let cached = RoutingCacheService.shared.lookup(
        origin: origin.id, dest: destination.id, mode: mode, context: context
    ) {
        return [cached]  // Transparent — same [RouteResult] shape as online
    }

    // Offline + no cache: return empty (caller shows "unavailable offline" message)
    lastError = "Маршрут недоступен офлайн. Подготовьте маршруты заранее при наличии сети."
    return []
}
```

### Pattern 5: NavigationEngine Offline Reroute Suppression

**What:** Skip `triggerRerouteIfReady` when offline; show warning instead.
**When to use:** User goes off-route while offline.

```swift
// In NavigationEngine.processLocation — minimal change
if perpendicularDist > offRouteThreshold {
    if OfflineCacheManager.shared.isOnline {
        triggerRerouteIfReady(from: coord)
    } else {
        // Signal offline reroute warning to UI (no reroute call)
        onOfflineRerouteWarning?()
    }
}

// New callback property
var onOfflineRerouteWarning: (() -> Void)?
```

### Pattern 6: Progress Ring (from PackingListView)

**What:** Circular progress ring with percentage text, state transition to "ready" badge.
**Source:** PackingListView.swift lines 130-136.

```swift
// Exact pattern from PackingListView, adapted for precache
ZStack {
    Circle()
        .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 6)
    Circle()
        .trim(from: 0, to: progress)
        .stroke(AppTheme.sakuraPink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut(duration: 0.3), value: progress)

    Text("\(Int(progress * 100))%")
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(AppTheme.sakuraPink)
}
.frame(width: 44, height: 44)
```

**State machine for the button:**
```
idle     → "Подготовить офлайн" (arrow.down.circle.fill icon, sakuraPink)
loading  → progress ring + "Загрузка маршрутов..." text
done     → "✓ Маршруты готовы" (checkmark.circle.fill icon, bambooGreen)
```

### Anti-Patterns to Avoid

- **Coordinate-keyed cache:** GPS drift causes cache misses. Use Place UUID keys as decided.
- **Storing `Trip?` relationship on `CachedRoute`:** SwiftData inverse relationship on UUID-keyed models causes migration complexity. Use Place UUIDs + manual delete on trip removal instead.
- **Calling `context.save()` inside `withTaskGroup` child tasks:** SwiftData `ModelContext` is not thread-safe. Collect results and call `save()` on `@MainActor` after the group completes.
- **Auto-caching GPS-origin routes:** Per CONTEXT.md, only Place→Place routes are cached. GPS coordinates are ephemeral and should not pollute the cache.
- **Making `RoutingCacheService` a `@Model`:** It is a service, not a model. Only `CachedRoute` is a `@Model`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Offline detection | Custom reachability | `OfflineCacheManager.shared.isOnline` (NWPathMonitor) | Already running; `isOnline` is `@Observable` so UI reacts automatically |
| Parallel async requests | Sequential for-loop | `withTaskGroup` | Already used in `fetchETAPreviews` — same pattern, zero new concepts |
| Coordinate serialization | Custom binary format | `JSONEncoder` + `CoordDTO: Codable` | Standard, debuggable, ~40 bytes/coord |
| Progress tracking | Timer polling | `@State var progress: Double` passed as `@escaping (Double) -> Void` closure | Pattern from `preCacheTrip` |
| Background WiFi detection | NWPathMonitor from scratch | `OfflineCacheManager.shared` + `NWPathMonitor` path.isExpensive | NWPathMonitor provides `.isExpensive` (cellular) vs WiFi distinction |

**Key insight:** The entire offline caching problem is ~80% solved by composing existing project patterns — no new frameworks needed.

---

## Common Pitfalls

### Pitfall 1: SwiftData ModelContext Thread Safety
**What goes wrong:** Calling `context.insert()` or `context.save()` from a background task child inside `withTaskGroup` crashes with "context accessed from non-main thread."
**Why it happens:** `ModelContext` is main-actor-bound in this project (`@MainActor OfflineCacheManager`).
**How to avoid:** In `preCacheDay`, collect `RouteResult` values from child tasks, then insert all at once on `@MainActor` after `withTaskGroup` completes. OR pass inserts through `await MainActor.run { }` blocks.
**Warning signs:** `EXC_BAD_ACCESS` or `Fatal error: context accessed from wrong thread` during precaching.

### Pitfall 2: Place Pairs Across Days
**What goes wrong:** Pre-caching routes between places from DIFFERENT days within a single `preCacheDay` call — wasted requests, routes nobody will use.
**Why it happens:** Developer loops over `trip.allPlaces` instead of `day.sortedPlaces`.
**How to avoid:** Scope pairs strictly to `day.sortedPlaces`. The button is per-day by design.

### Pitfall 3: L1 Cache Stale After Background
**What goes wrong:** App goes to background; SwiftData store is refreshed by another context; L1 dict contains stale entries that conflict with updated L2 data.
**Why it happens:** The in-memory L1 dict doesn't know about changes made by other contexts.
**How to avoid:** Call `RoutingCacheService.shared.clearL1()` in `applicationWillEnterForeground` / `sceneWillEnterForeground`. This is safe — L1 is just a performance layer, L2 is the truth.

### Pitfall 4: "Маршруты готовы" Badge on Stale Cache
**What goes wrong:** Button shows "✓ Маршруты готовы" but the cache is actually expired (>7 days old) or was cleared.
**Why it happens:** Badge state is derived from a flag set at cache time, not from re-checking TTL.
**How to avoid:** Derive `isDayCached` by fetching `CachedRoute` count for the day's place IDs from SwiftData and checking `createdAt > now - 7days`. Do NOT store a separate flag. Recompute on view appear.

### Pitfall 5: Transit Mode in Pre-cache
**What goes wrong:** Pre-caching `.transit` routes with Google Directions API — schedules are time-dependent and stale within hours.
**Why it happens:** Treating transit like walking/driving.
**How to avoid:** Per CONTEXT.md, only cache `.walking` and `.automobile`. Skip transit entirely in `preCacheDay`.

### Pitfall 6: Empty CTA When Offline + No Cache
**What goes wrong:** User taps transport pill offline, sees error message with no actionable path forward (can't pre-cache while offline).
**Why it happens:** CTA button "Подготовить офлайн" is shown but disabled/missing when actually offline.
**How to avoid:** Show the "unavailable offline" message AND disable the precache button with subtitle "Недоступно без сети" when `isOnline == false`. Never show a broken CTA.

---

## Code Examples

### Serialize/Deserialize RouteResult

```swift
// Source: established JSONEncoder pattern for custom types
extension CachedRoute {
    static func encode(polyline: [CLLocationCoordinate2D]) -> Data {
        let dtos = polyline.map { CoordDTO(lat: $0.latitude, lng: $0.longitude) }
        return (try? JSONEncoder().encode(dtos)) ?? Data()
    }

    static func decode(polylineData: Data) -> [CLLocationCoordinate2D] {
        guard let dtos = try? JSONDecoder().decode([CoordDTO].self, from: polylineData) else { return [] }
        return dtos.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    // Convert back to RouteResult for use in RoutingService
    func toRouteResult() -> RouteResult {
        let polyline = CachedRoute.decode(polylineData: polylineData)
        let steps = (try? JSONDecoder().decode([NavigationStepDTO].self, from: navigationStepsData))
            .map { dtos in dtos.map { NavigationStep(instruction: $0.instruction, distance: $0.distance, polyline: CachedRoute.decode(polylineData: (try? JSONEncoder().encode($0.polyline)) ?? Data()), isTransit: $0.isTransit) } } ?? []
        return RouteResult(
            polyline: polyline,
            distance: distanceMeters,
            expectedTravelTime: expectedTravelTimeSeconds,
            mode: TransportMode(rawValue: mode) ?? .walking,
            navigationSteps: steps
        )
    }
}
```

### Checking if a Day is Pre-Cached (for button badge)

```swift
// In TripMapView or a helper
func isDayCached(_ day: TripDay, context: ModelContext) -> Bool {
    let placeIDs = day.sortedPlaces.map(\.id)
    guard placeIDs.count >= 2 else { return false }
    let ttl = Date().addingTimeInterval(-(7 * 24 * 3600))
    let descriptor = FetchDescriptor<CachedRoute>(
        predicate: #Predicate { $0.createdAt > ttl }
    )
    let cached = (try? context.fetch(descriptor)) ?? []
    let cachedOrigins = Set(cached.map(\.originPlaceID))
    // At minimum, all places have at least one cached route from them
    return placeIDs.allSatisfy { cachedOrigins.contains($0) }
}
```

### MapRouteContent Offline Carousel Hide

```swift
// In MapRouteContent.routeAlternativesCarousel
// Add guard at top of the VStack
if OfflineCacheManager.shared.isOnline {
    routeAlternativesCarousel
        .padding(.top, AppTheme.spacingS)
}
// When offline: no carousel, no МАРШРУТЫ section header
```

### NavigationEngine Offline Warning Callback

```swift
// New property + modified processLocation in NavigationEngine
var onOfflineRerouteWarning: (() -> Void)?

// In processLocation, replace triggerRerouteIfReady call:
if perpendicularDist > offRouteThreshold {
    if OfflineCacheManager.shared.isOnline {
        triggerRerouteIfReady(from: coord)
    } else {
        onOfflineRerouteWarning?()
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UserDefaults for small data | SwiftData @Model | Session 16+ | Type safety, relationships, predicates |
| Direct API calls always | SupabaseProxy for all APIs | Session 25 | All route requests go through proxy — offline means proxy unreachable |
| Single-level RoutingService cache | L1 dict only, session-scoped | Phase 3 complete | Phase 4 adds persistent L2 |

**Deprecated/outdated:**
- Coordinate-keyed cache keys: superseded by UUID-keyed approach (GPS drift avoidance)
- In-memory-only cache: insufficient — loses all state on app restart

---

## Integration Points Summary

All modifications are confined to existing files. No new dependencies.

| File | Change | Scope |
|------|--------|-------|
| `Models/CachedRoute.swift` | NEW | @Model with JSON blobs |
| `Services/RoutingCacheService.swift` | NEW | L1+L2 singleton |
| `Services/RoutingService.swift` | MODIFY | Add `calculateRoute(fromPlace:toPlace:mode:context:)` overload |
| `Services/OfflineCacheManager.swift` | MODIFY | Add `preCacheDay(_:context:progress:)` |
| `Views/Map/TripMapView.swift` | MODIFY | Add floating "Подготовить офлайн" button in idle sheet |
| `Views/Map/MapRouteContent.swift` | MODIFY | Hide carousel offline; add no-cache message; offline ETA display |
| `Views/Map/MapViewModel.swift` | MODIFY | Wire `onOfflineRerouteWarning`; use UUID-based route overload for Place destinations |
| `Services/NavigationEngine.swift` | MODIFY | Add `onOfflineRerouteWarning` callback; skip reroute when offline |
| `Views/Settings/SettingsView.swift` | MODIFY | Add "Очистить кэш маршрутов" button |

---

## Open Questions

1. **ModelContext in RoutingService**
   - What we know: `RoutingService` is a non-view singleton with no `ModelContext` access today.
   - What's unclear: How to pass `ModelContext` into `RoutingService.calculateRoute` without threading issues.
   - Recommendation: Pass `ModelContext` as a parameter in the new Place-UUID overload, or make `RoutingCacheService` accept a context at call site. The caller (MapViewModel) has access to `modelContext` via `@Environment(\.modelContext)`.

2. **Background refresh debounce**
   - What we know: CONTEXT.md says "open map day + WiFi + stale caches → silently refresh".
   - What's unclear: NWPathMonitor's `.isExpensive` differentiates cellular vs WiFi. `path.isExpensive == false` means WiFi.
   - Recommendation: In `TripMapView.onAppear`, check `!isOnline || path.isExpensive` to decide whether to trigger background refresh. Add a `Task { await backgroundRefreshIfNeeded(day:context:) }` call.

3. **Cascade delete on Trip deletion**
   - What we know: No direct SwiftData relationship between `CachedRoute` and `Trip`.
   - What's unclear: Without a relationship, cascade delete won't fire automatically.
   - Recommendation: In `Trip.delete` (or wherever trips are deleted), query `CachedRoute` by all `day.sortedPlaces.map(\.id)` and delete them. OR add a `tripID: UUID` field to `CachedRoute` (simpler predicate delete) — acceptable since Trip UUID doesn't change.

---

## Validation Architecture

nyquist_validation is enabled in `.planning/config.json`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None detected — iOS SwiftUI project, no test target configured |
| Config file | None (manual Xcode setup required per MEMORY.md) |
| Quick run command | Build in Xcode on simulator |
| Full suite command | N/A — no automated test runner |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OFFL-01 | CachedRoute stores and retrieves RouteResult faithfully | unit | N/A — no test target | ❌ Wave 0 |
| OFFL-02 | Online: API called, no cache read. Offline + cache: returns cached route, no API call | unit | N/A | ❌ Wave 0 |
| OFFL-03 | Precache button triggers N² requests, progress updates, button state transitions | integration (manual) | Manual: tap button, observe ring, check badge | manual-only |
| OFFL-04 | Offline + no cache shows correct message, carousel hidden, transport pill tap shows message | manual UI | Manual: airplane mode + no cache | manual-only |

### Wave 0 Gaps
- No test target exists — all testing is manual on physical device per MEMORY.md
- MEMORY.md notes: "Test target needs manual Xcode setup"

*(Automated test infrastructure would require Xcode test target configuration — out of scope for this phase.)*

---

## Sources

### Primary (HIGH confidence)
- Direct code read: `RoutingService.swift` — full calculateRoute, fetchNavigationSteps, L1 cache implementation
- Direct code read: `OfflineCacheManager.swift` — preCacheTrip, NWPathMonitor, withTaskGroup pattern
- Direct code read: `OfflineMapCache.swift` — @Model pattern with @Attribute(.externalStorage)
- Direct code read: `NavigationEngine.swift` — triggerRerouteIfReady, offRouteThreshold, callback pattern
- Direct code read: `MapViewModel.swift` — calculateDirectionRoute, startNavigation, rerouteNavigation
- Direct code read: `MapRouteContent.swift` — routeAlternativesCarousel, transport mode pills
- Direct code read: `PackingListView.swift` — Circle.trim progress ring pattern (lines 130-136)
- Direct code read: `CONTEXT.md` — all locked decisions verified

### Secondary (MEDIUM confidence)
- SwiftData `@Model` + `@Attribute(.externalStorage)` pattern: verified from OfflineMapCache.swift
- `withTaskGroup` for parallel async: verified from fetchETAPreviews in RoutingService.swift
- NWPathMonitor `.isExpensive` property for WiFi detection: standard Apple framework, HIGH confidence

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all from existing project code, no external dependencies
- Architecture: HIGH — directly derived from 5 existing files with identical patterns
- Pitfalls: HIGH — most derived from existing code reading (SwiftData threading, GPS drift, cascade delete)

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable SwiftData/MapKit APIs; 30-day window)
