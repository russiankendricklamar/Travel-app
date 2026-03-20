# Phase 7: Sheet Geometry - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Корректная геометрия bottom sheet во всех трёх состояниях (peek/half/full): высоты detents, фоновые материалы, форма (shape), drag handle, safe area, keyboard. Контент sheet и search bar стилизация — Phase 8+.

</domain>

<decisions>
## Implementation Decisions

### Высоты и пропорции
- **D-01:** Peek height = 56pt (handle 8+5+6 = 19pt + search content area)
- **D-02:** Half height = 40% экрана (было 47%)
- **D-03:** Full height = весь экран, фон заходит под status bar
- **D-04:** Bottom gap в peek = 8pt над safe area (pill парит над tab bar)
- **D-05:** Full mode top = handle сразу под status bar safe area (без доп. отступа)
- **D-06:** Единые detent-высоты для всех режимов (включая навигацию)
- **D-07:** Tab bar остаётся видимым в peek/idle, pill располагается над ним
- **D-08:** Portrait only — landscape не поддерживается
- **D-09:** Pill ширина = полная ширина экрана минус 32pt (16pt слева + 16pt справа)

### Фоновые материалы
- **D-10:** Peek pill фон = `.ultraThinMaterial` + `Color.black.opacity(0.35)` overlay + `.environment(\.colorScheme, .dark)`
- **D-11:** Expanded фон (half/full) = `Color(uiColor: .systemBackground)` — полностью непрозрачный
- **D-12:** Peek pill тень = `shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 4)`
- **D-13:** Expanded sheet тень сверху = `shadow(color: .black.opacity(0.15), radius: 10, y: -5)`
- **D-14:** Переход фона peek → half = opacity crossfade (`.transition(.opacity)`, 0.15s easeInOut)
- **D-15:** Sheet всегда dark — наследует dark scheme от карты

### Единая форма (shape)
- **D-16:** Единый `UnevenRoundedRectangle` для всех состояний (не два разных типа)
- **D-17:** Top radius = 22pt всегда (peek и expanded одинаковый)
- **D-18:** Bottom radius = 22pt в peek, 0pt в half/full (анимируемый параметр)
- **D-19:** `style: .continuous` (squircle-углы Apple-качества)
- **D-20:** Радиусы и горизонтальные паддинги меняются при snap detent (не при drag) — spring анимация
- **D-21:** Горизонтальные паддинги: 16pt в peek → 0pt в half/full (snap)

### Drag handle
- **D-22:** Handle виден во ВСЕХ состояниях (peek, half, full) — реализуется в Phase 7
- **D-23:** Handle внутри pill (не поверх)
- **D-24:** Handle размеры: 36pt × 5pt, `Color(.systemFill)`
- **D-25:** Handle паддинги: top 8pt, bottom 6pt — одинаковые во всех состояниях

### Производительность
- **D-26:** Использовать `.onGeometryChange` (iOS 17+) вместо GeometryReader для замера высоты — не участвует в layout pass

### Safe area и keyboard
- **D-27:** Expanded фон `.ignoresSafeArea(.bottom)` — до края экрана
- **D-28:** Full mode фон `.ignoresSafeArea(.top)` — под status bar
- **D-29:** Sheet использует `.ignoresSafeArea(.keyboard)` — сам управляет позицией

### Drag gesture
- **D-30:** Velocity threshold 0.3 + 20% проброс — оставить как есть
- **D-31:** Spring params: `response: 0.35, dampingFraction: 0.85` — зафиксированы
- **D-32:** В peek: drag gesture на всей pill (handle + search + фон)
- **D-33:** В half/full: drag только через handle capsule
- **D-34:** minimumDistance = 5pt

### Интеграция
- **D-35:** Tab bar скрытие: текущее поведение `.toolbar(isIdleMode ? .visible : .hidden, for: .tabBar)`
- **D-36:** Pill видна только в peek/idle — в expanded это часть sheet
- **D-37:** Навигационный режим: та же геометрия sheet
- **D-38:** Офлайн: sheet скрыт при isOfflineWithCache (текущее поведение)

### Dead code
- **D-39:** Удалить `MapFloatingSearchPill.swift` — не используется, мёртвый код

### Accessibility
- **D-40:** Базовый a11y: accessibilityLabel на drag handle, accessibilityHint на pill

### Claude's Discretion
- Анимация spring API: `.spring(response:dampingFraction:)` (текущий)
- Crossfade длительность можно тюнить при реализации (ориентир 0.15s)
- Exact shadow opacity values можно подобрать визуально

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Sheet implementation
- `.planning/research/STACK.md` — API specs для material, shape, mapScope, drag handle dimensions
- `.planning/research/PITFALLS.md` — 10 критических/moderate pitfalls с prevention strategies

### Requirements
- `.planning/REQUIREMENTS.md` — GEOM-01 through GEOM-05 acceptance criteria

### Current code
- `Travel app/Views/Map/MapBottomSheet.swift` — текущая реализация sheet (перерабатывается)
- `Travel app/Views/Map/TripMapView.swift` — parent view с ZStack layout
- `Travel app/Views/Map/MapSearchContent.swift` — содержимое sheet

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MapBottomSheet.swift`: кастомный sheet с GeometryReader, drag gesture, detent snap — основа для переработки
- `SheetDetent` enum: peek/half/full с height calculation — нужно обновить значения
- `MapSearchContent.swift`: содержимое sheet с search field, chips, results — не меняется в Phase 7
- Spring animation `withAnimation(.spring(response: 0.35, dampingFraction: 0.85))` уже используется в drag gesture

### Established Patterns
- `@Bindable var vm: MapViewModel` — sheet получает VM через binding
- `isIdleMode` computed property в TripMapView управляет tab bar visibility
- `.preferredColorScheme(.dark)` на Map view — все UI элементы на карте в dark mode

### Integration Points
- `MapBottomSheet(detent: $vm.sheetDetent)` — binding в TripMapView
- `sheetBody` @ViewBuilder в TripMapView определяет контент по `vm.sheetContent`
- `.toolbar(isIdleMode ? .visible : .hidden, for: .tabBar)` — tab bar логика
- `.safeAreaPadding(.bottom, isIdleMode ? 66 : 0)` — карта подстраивается под sheet

</code_context>

<specifics>
## Specific Ideas

- Pill должна выглядеть как в Apple Maps — тёмная полупрозрачная таблетка с blur, карта просвечивает
- Переход peek → half: pill плавно превращается в docked sheet через opacity crossfade фонов
- Handle внутри pill для компактности — не торчит сверху

</specifics>

<deferred>
## Deferred Ideas

- `@Namespace mapScope` + `Map(scope:)` — Phase 9 (Floating Controls)
- Scroll-to-top-then-drag поведение — слишком сложно для текущего scope, может быть добавлено в Phase 11
- Полный VoiceOver flow с объявлением состояний sheet — после MVP
- `.regularMaterial` fallback для навигационного режима (performance) — Phase 11 polish

</deferred>

### Testing Criteria (Physical Device)
- Blur над светлыми тайлами (парки, пляжи, вода) — pill должна оставаться тёмной
- Side-by-side сравнение с Apple Maps на том же устройстве
- Slow motion анимации (Simulator → Debug → Slow Animations) — shape morph без snap
- Instruments: <10% CPU при drag над активной картой

---

*Phase: 07-sheet-geometry*
*Context gathered: 2026-03-21*
