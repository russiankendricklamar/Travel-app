# Phase 9: Floating Controls - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Вертикальный стек floating кнопок справа от карты: native MapCompass, blur-контейнер с transit toggle / 3D elevation / location. Плавное скрытие при расширении sheet, навигации, осадках, офлайн. Интеграция `@Namespace` + `Map(scope:)` для native compass.

</domain>

<decisions>
## Implementation Decisions

### Визуальная группировка
- **D-01:** Компас отдельно сверху (native `MapCompass(scope:)`) + blur-контейнер снизу (3 кнопки: transit, 3D, location)
- **D-02:** 8pt gap между компасом и контейнером
- **D-03:** Контейнер: `RoundedRectangle(cornerRadius: 12, style: .continuous)` + `.ultraThinMaterial` + dark color scheme
- **D-04:** Тонкие разделители между кнопками: 0.5pt `Color.white.opacity(0.15)`
- **D-05:** Контейнер ширина = 44pt (кнопки впритык, без внутренних паддингов)
- **D-06:** Каждая кнопка = 44pt × 44pt hit area
- **D-07:** Тень контейнера = `shadow(color: .black.opacity(0.35), radius: 14, y: 4)` — как у peek pill (Phase 7 D-12)
- **D-08:** Контейнер анимированно сжимается когда компас hidden (north-facing) — 3 кнопки без пустого слота

### Компас
- **D-09:** Native `MapCompass(scope: mapScope)` — auto hide/show, native стиль, tap-to-north
- **D-10:** Требуется `@Namespace var mapScope` + `Map(scope: mapScope)` в TripMapView
- **D-11:** Удалить `MapCompass()` из `.mapControls` — переместить в overlay справа
- **D-12:** `MapScaleView()` остаётся в `.mapControls` (без изменений)

### Кнопка транспорта
- **D-13:** Иконка: `bus.fill`
- **D-14:** Toggle: `showsTraffic` true/false на `.mapStyle`
- **D-15:** Начальное состояние: `showsTraffic: true` (текущее поведение)
- **D-16:** Active цвет: `AppTheme.sakuraPink`. Inactive: `.white`
- **D-17:** Haptic: `.impact(.light)` при toggle

### Кнопка 3D elevation (NEW — расширение scope)
- **D-18:** Переключает `.standard(elevation: .realistic)` ↔ `.standard(elevation: .flat)`
- **D-19:** Иконка: `view.3d` когда flat (показывает что будет при нажатии), `view.2d` когда realistic
- **D-20:** Active (3D) цвет: `AppTheme.sakuraPink`. Inactive (2D): `.white`
- **D-21:** Позиция: между transit и location в контейнере
- **D-22:** Haptic: `.impact(.light)` при toggle

### Кнопка локации
- **D-23:** Иконка: `location` (outline, не fill) — как Apple Maps
- **D-24:** Действие: центрирует карту на текущем GPS, zoom = 0.01° latitude delta
- **D-25:** Простой center (без heading mode / двойного режима)
- **D-26:** Haptic: `.impact(.light)` при нажатии

### Fade поведение
- **D-27:** Кнопки видны только в peek + idle mode. Скрыты в half/full (snap по detent, не по drag offset)
- **D-28:** Fade анимация = та же spring что у sheet: `response: 0.35, dampingFraction: 0.85`
- **D-29:** Скрывать при навигации (`vm.isNavigating`)
- **D-30:** Скрывать при precipitation overlay (`vm.showPrecipitation`)
- **D-31:** Скрывать при offline cache view (`isOfflineWithCache`)

### Иконки и цвета
- **D-32:** Цвет иконок по умолчанию: `.white`
- **D-33:** Размер/weight иконок: Claude's discretion (текущий 16pt semibold как ориентир)

### Accessibility
- **D-34:** `accessibilityLabel` на каждую кнопку ("Моё местоположение", "Транспорт", "3D вид")
- **D-35:** `accessibilityHint` с описанием действия

### Позиционирование
- **D-36:** Правый край, 16pt от trailing edge
- **D-37:** Bottom offset: Claude's discretion (~80-90pt, над peek pill)

### Claude's Discretion
- Размер и weight SF Symbol иконок (ориентир 16pt semibold)
- Точный bottom offset контейнера (80-90pt)
- Анимация смены иконки при toggle (symbolEffect или без)
- Начальное состояние elevation (flat или realistic)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 7 context (predecessor)
- `.planning/phases/07-sheet-geometry/07-CONTEXT.md` — 40 decisions on sheet geometry, materials, drag gesture

### Phase 8 context (sibling)
- `.planning/phases/08-search-bar-handle/08-CONTEXT.md` — 57 decisions on search bar, haptics, styling

### Requirements
- `.planning/REQUIREMENTS.md` — CTRL-01..07 acceptance criteria (3D button extends scope beyond CTRL-07)

### Current code
- `Travel app/Views/Map/TripMapView.swift` — parent view with existing location button (lines 149-181), `.mapControls` (line 416-419)
- `Travel app/Views/Map/MapBottomSheet.swift` — sheet geometry, detent states
- `Travel app/Views/Map/MapViewModel.swift` — showPrecipitation, isNavigating, cameraPosition, sheetDetent

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TripMapView.swift:149-181`: Existing floating location button — refactor into container
- `LocationManager.shared.requestCurrentLocation()` — async GPS fetch already working
- `vm.cameraPosition` — camera binding already in use
- `vm.showPrecipitation` — precipitation toggle state already exists
- `isIdleMode` computed property — peek + idle detection already implemented

### Established Patterns
- `.ultraThinMaterial` + dark scheme — consistent with peek pill (Phase 7)
- `AppTheme.sakuraPink` for active toggle states — consistent with AI sparkles (Phase 8)
- `.impact(.light)` haptic — consistent across search bar and sparkles toggle
- Spring animation `response: 0.35, dampingFraction: 0.85` — project-wide standard

### Integration Points
- Remove existing floating location button (TripMapView:149-181) — replaced by container
- Remove `MapCompass()` from `.mapControls` (TripMapView:418) — moved to overlay
- Add `@Namespace var mapScope` to TripMapView
- Change `Map(position:selection:)` to `Map(position:selection:scope:)`
- Add `vm.showTraffic` and `vm.show3DElevation` toggle states to MapViewModel
- Update `.mapStyle()` to read from VM toggle states

</code_context>

<specifics>
## Specific Ideas

- Контейнер визуально как Apple Maps — единый blur block с тонкими линиями между кнопками
- Компас отдельно от контейнера потому что native MapCompass имеет свой стиль — не конфликтует с кастомными кнопками
- 3D кнопка показывает "что будет" (view.3d когда сейчас flat, view.2d когда сейчас 3D)
- Единый акцентный цвет sakuraPink для всех active toggle states

</specifics>

<deferred>
## Deferred Ideas

- Heading mode для location button (двойной тап → follow user rotation) — будущий milestone
- Satellite view toggle (standard ↔ imagery) — будущий milestone
- 3-way map style cycle (standard → 3D → satellite) — будущий milestone

</deferred>

---

*Phase: 09-floating-controls*
*Context gathered: 2026-03-21*
