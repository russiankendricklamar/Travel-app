# Phase 4: Offline Routes - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Кэширование маршрутов для офлайн-использования: SwiftData persistence, предзагрузка маршрутов дня, cache-first lookup в RoutingService, graceful degradation без сети. Офлайн-навигация по кэшированным маршрутам с голосовыми подсказками (без reroute).

</domain>

<decisions>
## Implementation Decisions

### Предзагрузка маршрутов
- Кэшируются ВСЕ пары мест дня (N² — каждое к каждому), не только последовательные
- 2 транспортных режима: пешком + авто (transit расписания устаревают, вело — редкий)
- Только лучший маршрут per mode (не альтернативы) — меньше данных
- NavigationSteps кэшируются вместе с маршрутом — полный офлайн turn-by-turn
- Только снапшоты карт НЕ включены (уже есть в OfflineCacheManager.preCacheTrip)
- Загрузка параллельная (withTaskGroup), все запросы одновременно
- Скоуп: за день (кнопка на каждом дне), не за всю поездку
- Кнопка расположена на карте дня (TripMapView) — floating или в bottom sheet idle

### Прогресс и уведомление
- Прогресс-кольцо (circular) с процентом и текстом «Загрузка маршрутов...» (паттерн PackingListView)
- По завершении: кнопка меняется на «✓ Маршруты готовы» с зелёным акцентом
- Иконка на карте дня показывает что день подготовлен офлайн
- Без push-напоминаний о предзагрузке перед поездкой

### Cache-first поведение
- Онлайн: ВСЕГДА свежий маршрут из API (сеть приоритет). Кэш — только для офлайн
- Офлайн: SwiftData кэш, прозрачно для пользователя (маршрут выглядит как обычный)
- Ключ кэша: originPlaceUUID + destPlaceUUID + mode (не координаты — избегаем GPS дрифт)
- Маршруты от GPS-позиции (не из Place) НЕ кэшируются — только Place→Place
- TTL: 7 дней (покрывает типичную поездку)
- Двухуровневый кэш: L1 in-memory (быстрый, текущая сессия) + L2 SwiftData (персистентный)

### Фоновое обновление
- При открытии карты дня + есть Wi-Fi + есть устаревшие кэши → тихо обновить в фоне
- Только ручная предзагрузка, без автоматических обновлений в других контекстах

### Офлайн UX
- Кэш есть: маршрут показывается как обычный, никакой разницы (OfflineBanner сверху уже информирует)
- Кэша нет: сообщение «Маршрут недоступен офлайн. Подготовьте маршруты заранее при наличии сети» + CTA
- Карусель альтернатив: скрыта офлайн (1 маршрут per mode — нечего выбирать)
- Transport pills: все 4 показываются, при тапе на некэшированный — сообщение «недоступно офлайн»
- ETA previews: из кэшированного RouteResult (distance + expectedTravelTime) для доступных режимов, «—» для остальных
- Офлайн-навигация: разрешена по кэшированному маршруту, НО при отклонении — предупреждение вместо reroute

### Хранение и очистка
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Routing (existing code)
- `Travel app/Services/RoutingService.swift` — calculateRoute (returns [RouteResult]), in-memory cache, fetchETAPreviews, fetchNavigationSteps, TransportMode/RouteResult/TransitStep models
- `Travel app/Views/Map/MapViewModel.swift` — activeRoute, alternativeRoutes, selectedRouteIndex, route calculation flow

### Offline infrastructure (existing)
- `Travel app/Services/OfflineCacheManager.swift` — NWPathMonitor (isOnline), preCacheTrip (map snapshots), weather cache
- `Travel app/Models/OfflineMapCache.swift` — @Model pattern for SwiftData caching (externalStorage, tripDayID key)

### Map UI
- `Travel app/Views/Map/TripMapView.swift` — Map rendering, floating overlays, sheet content
- `Travel app/Views/Map/MapRouteContent.swift` — Transport pills, route stats, route alternatives carousel
- `Travel app/Views/Map/RouteAlternativeCard.swift` — Glassmorphism route cards (hide offline)

### Navigation
- `Travel app/Services/NavigationEngine.swift` — State machine, reroute detection (needs offline-aware mode)
- `Travel app/Models/NavigationModels.swift` — NavigationStep model (instructions, distance, polyline, isTransit)

### Theme
- `Travel app/Theme/AppTheme.swift` — sakuraPink accent, bambooGreen (for success), spacing constants
- `Travel app/Theme/GlassComponents.swift` — Glassmorphism patterns

### Data model
- `Travel app/Models/TripModels.swift` — TripDay.sortedPlaces, Place (latitude, longitude, id)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- OfflineCacheManager: NWPathMonitor + isOnline — reuse for offline detection in RoutingService
- OfflineMapCache @Model: pattern for SwiftData caching with externalStorage
- RoutingService.formatDuration/formatDistance: reuse for cached route display
- PackingListView progress ring: reuse pattern for pre-cache progress

### Established Patterns
- @Observable singleton services (RoutingService.shared, OfflineCacheManager.shared)
- SwiftData @Model with @Attribute(.unique) id: UUID
- In-memory cache with string key in RoutingService (extend to L1/L2)
- withTaskGroup for parallel API requests (used in fetchETAPreviews)

### Integration Points
- RoutingService.calculateRoute: add SwiftData L2 lookup before API call when offline
- OfflineCacheManager: add route pre-caching alongside existing map snapshot pre-caching
- TripMapView: add floating «Подготовить офлайн» button
- MapRouteContent: conditionally hide carousel when offline + single cached route
- NavigationEngine: skip reroute when offline, show warning instead
- SettingsView: add «Очистить кэш маршрутов» button

</code_context>

<specifics>
## Specific Ideas

- Прозрачность для пользователя: офлайн маршрут выглядит точно как онлайн (без лишних меток)
- Кнопка меняет состояние: «Подготовить офлайн» → прогресс-кольцо → «✓ Маршруты готовы»
- Двухуровневый кэш (L1 in-memory + L2 SwiftData) — быстрый доступ + персистентность

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-offline-routes*
*Context gathered: 2026-03-20*
