# Phase 3: Route Selection - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Сравнение альтернативных маршрутов (2-3 варианта) и переключение транспортных режимов перед запуском навигации. RoutingService уже возвращает routes[] из Routes API, но используется только первый. Transport pills с ETA previews уже работают.

</domain>

<decisions>
## Implementation Decisions

### Отображение альтернатив на карте
- Только 1 (активный) polyline на карте — яркий, цвет режима транспорта
- Альтернативы НЕ показываются на карте как polyline — только в карточках sheet
- При выборе другой карточки polyline меняется с анимацией

### Карточки альтернатив в sheet
- Горизонтальная карусель (ScrollView .horizontal) под transport pills
- Каждая карточка: ETA + расстояние + авто-метка
- Авто-метки: «Быстрый» (минимальный ETA), «Короткий» (минимальная дистанция)
- Первый маршрут (fastest) предвыбран по умолчанию
- Glassmorphism стиль карточек, выбранная — sakuraPink обводка
- Для transit: количество пересадок вместо расстояния

### UX выбора маршрута
- Тап по карточке в карусели = выбор маршрута
- Polyline на карте обновляется, route stats обновляются, step list обновляется
- Без тапа по polyline на карте (1 polyline = нечего тапать)

### Переключение транспорта
- Альтернативы загружаются для КАЖДОГО режима транспорта
- Transport pill тап → загрузка 2-3 альтернатив для этого режима → карусель обновляется
- Loading state на карусели пока загружаются альтернативы
- ETA previews (Distance Matrix) продолжают работать как сейчас для всех pills

### Сравнение маршрутов
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Routing (existing code)
- `Travel app/Services/RoutingService.swift` — calculateRoute (returns single RouteResult, needs multi-route), Routes API v2 integration, fetchETAPreviews (Distance Matrix), TransportMode enum, RouteResult/TransitStep models
- `Travel app/Views/Map/MapRouteContent.swift` — existing transport pills, route stats, transit steps list, "НАЧАТЬ НАВИГАЦИЮ" button

### Map UI
- `Travel app/Views/Map/MapViewModel.swift` — activeRoute (single, needs alternativeRoutes array), selectedTransportMode, isCalculatingRoute, route polyline rendering
- `Travel app/Views/Map/TripMapView.swift` — Map polyline rendering, sheet content switching

### Theme
- `Travel app/Theme/GlassComponents.swift` — glassmorphism patterns for new route cards
- `Travel app/Theme/AppTheme.swift` — sakuraPink accent, mode colors, spacing constants

### Phase 2 output (navigation integration)
- `Travel app/Views/Map/NavigationHUDView.swift` — starts from selected route
- `Travel app/Views/Map/NavigationSheetContent.swift` — uses NavigationStep from selected route

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- TransportMode enum: icons, labels, colors, routesAPIMode — already complete
- RoutingService.formatDuration/formatDistance — reuse for card display
- ModeETAPreview — already fetched in parallel, shown in transport pills
- GlassComponents patterns — for route alternative cards

### Established Patterns
- RoutingService.calculateRoute returns single RouteResult — modify to return [RouteResult]
- Routes API v2 response has `routes[]` array — already returns multiple, just need to parse all
- Google Directions (transit) returns single route — alternative transit routes not available via this API
- MapViewModel.activeRoute: RouteResult? — add alternativeRoutes: [RouteResult]

### Integration Points
- RoutingService.calculateRoute → return array instead of single
- MapViewModel: new selectedRouteIndex, alternativeRoutes array
- MapRouteContent: insert carousel between transport pills and route stats
- TripMapView: polyline source switches to selectedRoute from alternatives

</code_context>

<specifics>
## Specific Ideas

- Карусель карточек как в Apple Maps при выборе маршрута
- «Быстрый»/«Короткий» метки автоматически — пользователь сразу видит зачем этот вариант
- Для transit показать пересадки вместо км — путешественнику важнее количество пересадок

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-route-selection*
*Context gathered: 2026-03-20*
