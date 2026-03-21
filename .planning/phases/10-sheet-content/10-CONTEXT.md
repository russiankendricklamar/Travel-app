# Phase 10: Sheet Content - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Контент bottom sheet (category chips, секции "Сегодня", map controls) заполняет half/full mode без пустых областей и без конфликтов жестов drag/scroll. Search bar и handle — Phase 8 (завершена). Floating controls — Phase 9 (завершена). Переходы и анимации — Phase 11.

</domain>

<decisions>
## Implementation Decisions

### Видимость контента
- **D-01:** Apple Maps стиль — chips, "Сегодня", map controls видны СРАЗУ в half mode без фокуса на search bar. Убрать условие `isSearchFocused` из строки 90 MapSearchContent.swift
- **D-02:** При вводе текста в search — плавная замена (fade out chips/секции → fade in completer results). При очистке query — chips возвращаются
- **D-03:** Full mode расширяет контент дополнительными секциями, которых нет в half

### Порядок секций
- **D-04:** Claude's discretion на порядок секций в half mode (chips, map controls, "Сегодня" — выбрать оптимальную иерархию для ~260pt доступного пространства)

### Scroll vs Drag
- **D-05:** Claude's discretion на стратегию scroll/drag в half mode (без scroll, scroll-then-drag, или альтернативный подход)

### Пустые состояния
- **D-06:** Claude's discretion на обработку пустых состояний (нет активной поездки, нет мест на сегодня, офлайн)

### Claude's Discretion
- Порядок секций в half mode (D-04)
- Scroll/drag стратегия в half mode (D-05)
- Пустые состояния (D-06)
- Дополнительные секции в full mode (например, "Недавние", "Избранное" — выбрать по уместности)
- Анимация fade transition timing
- Точные отступы между секциями

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Predecessor phases
- `.planning/phases/07-sheet-geometry/07-CONTEXT.md` — 40 decisions on sheet geometry, materials, drag gesture (peek 56pt, half 40%, full)
- `.planning/phases/08-search-bar-handle/08-CONTEXT.md` — 57 decisions on search bar, sticky header, cancel button
- `.planning/phases/09-floating-controls/09-CONTEXT.md` — 37 decisions on floating controls overlay

### Requirements
- `.planning/REQUIREMENTS.md` — CONT-01..04 acceptance criteria

### Current code
- `Travel app/Views/Map/MapSearchContent.swift` — PRIMARY target: chips, "Сегодня", map controls, search results (635 строк)
- `Travel app/Views/Map/MapBottomSheet.swift` — sheet geometry, detent states (Phase 7 output, DO NOT modify geometry)
- `Travel app/Views/Map/MapViewModel.swift` — search state, category search, sheet content enum

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `categoryChips` view (lines 120-154): fully implemented horizontal ScrollView with loading states — needs visibility fix only
- `todayPlacesSection` view (lines 423-489): complete "Сегодня · Город" with visited indicators — needs visibility fix only
- `mapControlsSection` view (lines 493-584): Слои menu + Осадки + Обзор + Все места — needs visibility fix only
- `scrollableContent` ViewBuilder (lines 82-116): content routing logic — needs condition update
- `MapViewModel.quickCategories`: static array of category chips already defined

### Established Patterns
- `vm.sheetDetent == .full` gates ScrollView wrapping (lines 52-71)
- `isScrolled` state + `ScrollOffsetKey` PreferenceKey for scroll-aware divider
- `.transition(.opacity)` on content sections for fade animation
- `@FocusState.Binding var isSearchFocused` drives search field activation

### Integration Points
- Line 90: `if isSearchFocused && vm.completerResults.isEmpty && vm.searchQuery.isEmpty` — PRIMARY change point for D-01
- `scrollableContent` ViewBuilder — add full-mode-only sections here
- `vm.sheetContent` enum — may need idle content state awareness

</code_context>

<specifics>
## Specific Ideas

- Контент должен быть виден сразу как в Apple Maps — пользователь открывает half и видит chips + places без лишних тапов
- Плавная замена контента при поиске — не мгновенное переключение, а fade transition
- Full mode как расширенная версия half — тот же контент + доп. секции

</specifics>

<deferred>
## Deferred Ideas

- CONT-05: "Места" секция (Дом/Работа/Добавить) — не входит в Phase 10 requirements
- CONT-06: "Недавние" секция с историей поиска — может быть реализована как full-mode-only, на усмотрение Claude
- Анимации переходов между detent states — Phase 11

</deferred>

---

*Phase: 10-sheet-content*
*Context gathered: 2026-03-21*
