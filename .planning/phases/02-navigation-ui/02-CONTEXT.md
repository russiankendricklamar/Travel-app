# Phase 2: Navigation UI - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

UI-слой поверх NavigationEngine (Phase 1): floating HUD карточка манёвра, кнопка старта/стопа навигации, camera heading lock, навигационный detent в bottom sheet с контекстом поездки. Все данные (steps, distance, index) уже доступны через MapViewModel.

</domain>

<decisions>
## Implementation Decisions

### HUD карточка манёвра
- Позиция: верх экрана (под Dynamic Island/notch), как в Apple Maps
- Содержимое: SF Symbol иконка направления (arrow.turn.up.left и т.д.) + текстовая инструкция + дистанция до манёвра
- Стиль: glassmorphism (.ultraThinMaterial + AppTheme.sakuraPink акцент) — переиспользует паттерн из GlassComponents
- Анимация смены шага: плавный crossfade (.animation(.easeInOut) на contentTransition)
- Всегда видима при навигации, не сворачивается
- Ургентность: иконка/фон меняет цвет на AppTheme.sakuraPink когда дистанция < 50м
- Иконки направлений: парсинг MKRouteStep.instructions для определения направления → соответствующий SF Symbol
- Контекст поездки ("День 2 из 7 — Токио") НЕ на HUD — в bottom sheet

### Start/Stop навигации
- Запуск: кнопка "НАЧАТЬ НАВИГАЦИЮ" в конце MapRouteContent (внутри route info sheet)
- Стиль кнопки: залитая AppTheme.sakuraPink с белым текстом (не glass)
- Остановка: два способа — кнопка "Завершить" в navigation sheet + кнопка X на HUD карточке
- Без подтверждения при остановке — одно нажатие останавливает
- После остановки: возврат к routeInfo (маршрут остаётся на карте, MapRouteContent в sheet)

### Camera + heading lock
- При навигации: .userLocation(followsHeading: true) — камера следит с ротацией по heading
- Auto-zoom автоматически подстраивается
- Пользователь может панорамировать вручную — при смещении появляется кнопка "Вернуться" для ре-центрирования
- При остановке навигации: камера возвращается к обычному режиму (.automatic)

### Navigation sheet detent
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Navigation Engine (Phase 1 output)
- `Travel app/Models/NavigationModels.swift` — NavigationStep model (instructions, distance, transportType, isTransit)
- `Travel app/Services/NavigationEngine.swift` — State machine, processLocation, advanceStep, onRerouteNeeded
- `Travel app/Services/NavigationVoiceService.swift` — Voice trigger distances (500/200/15m), audio session lifecycle

### Map UI (existing)
- `Travel app/Views/Map/MapViewModel.swift` — @Observable, isNavigating, navigationSteps, currentStepIndex, distanceToNextStep, cameraPosition
- `Travel app/Views/Map/TripMapView.swift` — ZStack layout, Map + search pill + bottom sheet
- `Travel app/Views/Map/MapBottomSheet.swift` — Custom sheet with SheetDetent enum (peek/half/full), drag gesture
- `Travel app/Views/Map/MapRouteContent.swift` — Route info view in sheet (header, transport pills, stats)

### Theme
- `Travel app/Theme/GlassComponents.swift` — GlassTextFieldStyle, GlassFormField, GlassSectionHeader
- `Travel app/Theme/AppTheme.swift` — sakuraPink, radii, spacings, glass ViewModifiers

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- GlassComponents: .ultraThinMaterial + 0.5pt stroke pattern — use for HUD and navigation sheet
- MapBottomSheet: custom drag gesture sheet with 3 detents — extend with navigation state awareness
- MapSheetContent enum: add .navigation case for navigation-specific sheet content
- AppTheme.sakuraPink: accent color for buttons and urgency highlighting

### Established Patterns
- @Observable MapViewModel: all state in single observable, views bind directly
- SheetDetent enum with nearest() for snap behavior — navigation detent integrates here
- MapRouteContent receives @Bindable vm — new navigation content follows same pattern

### Integration Points
- MapViewModel.startNavigation() / stopNavigation() — already exist, UI calls these
- MapViewModel.isNavigating — drives conditional rendering (HUD visible, sheet content switch)
- MapViewModel.cameraPosition — set to .userLocation(followsHeading:) during navigation
- TripMapView ZStack — HUD overlays here, between map and sheet
- MapRouteContent — add "НАЧАТЬ НАВИГАЦИЮ" button at bottom

</code_context>

<specifics>
## Specific Ideas

- HUD карточка вверху как в Apple Maps — классическая позиция навигационного HUD
- Кнопка "Вернуться" при ручном панорамировании — как в Apple Maps (floating location.fill button)
- SF Symbol иконки направлений — нативные, поддерживают dynamic type
- Залитая sakuraPink кнопка старта — выделяется на фоне glass UI, привлекает внимание к action

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-navigation-ui*
*Context gathered: 2026-03-20*
