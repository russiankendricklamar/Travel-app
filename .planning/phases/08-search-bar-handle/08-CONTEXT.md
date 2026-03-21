# Phase 8: Search Bar + Handle - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Drag handle и search bar полностью соответствуют Apple Maps: правильные пропорции, шрифты, отступы, анимации, focus/cancel поведение, sticky header в full mode. Контент sheet (chips, секции) — Phase 10. Floating controls — Phase 9.

</domain>

<decisions>
## Implementation Decisions

### Drag Handle
- **D-01:** Handle top padding = 8pt (как реализовано в Phase 7, а не 10pt из REQUIREMENTS.md)
- **D-02:** Handle bottom padding = 6pt (без изменений)
- **D-03:** Handle размер: 36pt x 5pt, `Color(.systemFill)` (без изменений)
- **D-04:** Handle идентичен во ВСЕХ состояниях (peek, half, full) — никаких изменений стиля
- **D-05:** Handle без press feedback (нет dimming/highlight при тапе)
- **D-06:** Handle a11y: текущие labels (accessibilityLabel + accessibilityHint) — без изменений
- **D-07:** Handle hit area: текущий full-width Rectangle contentShape — без изменений
- **D-08:** Handle цвет: `Color(.systemFill)` — без изменений
- **D-09:** Handle ширина: 36pt fixed — без изменений
- **D-10:** Handle форма: `Capsule()` — без изменений
- **D-11:** Handle позиция: centered (текущая) — без изменений

### Search Bar — Размеры и типографика
- **D-12:** Search bar padding: 4pt vertical в peek / 8pt vertical в expanded (без изменений)
- **D-13:** Search bar высота capsule: 36pt единая во всех состояниях
- **D-14:** Magnifyingglass иконка: 17pt `.regular` weight (CHANGE: было 15pt .medium)
- **D-15:** Search bar шрифт: 17pt (CHANGE: было 16pt)
- **D-16:** Inner padding (leading/trailing): 14pt (CHANGE: было 12pt)
- **D-17:** Spacing между иконкой и текстом: 6pt (CHANGE: было 8pt)
- **D-18:** Outer horizontal padding (search bar от краёв sheet): 16pt (без изменений)

### Search Bar — Фон и стиль
- **D-19:** Peek: нет inner capsule background (pill IS the background)
- **D-20:** Expanded capsule bg: `.quaternary.opacity(0.5)` (без изменений)
- **D-21:** Expanded capsule stroke: 0.5pt `Color.white.opacity(0.1)` (NEW)
- **D-22:** Capsule corner radius: `RoundedRectangle(cornerRadius: 10)` (CHANGE: было Capsule())
- **D-23:** Bottom spacing (под search bar): 10pt (без изменений)

### Search Bar — Текст и placeholder
- **D-24:** Placeholder текст: "Поиск" (CHANGE: было "Поиск мест...")
- **D-25:** Placeholder цвет: `Color.white.opacity(0.5)` (CHANGE: было .secondary)
- **D-26:** Peek текст: показывает query если есть, иначе placeholder
- **D-27:** Peek текст стиль: .primary для query, .secondary для placeholder (без изменений)
- **D-28:** Text cursor цвет: `AppTheme.sakuraPink` (акцентный)
- **D-29:** Автокапитализация: `.never`, автокоррекция: disabled (без изменений)
- **D-30:** Keyboard тип: `.default` (без изменений)
- **D-31:** Submit action: запускает поиск (onSubmit)

### Search Bar — Фокус и взаимодействие
- **D-32:** Тап в peek: раскрывает sheet в half + автофокус TextField
- **D-33:** Haptic при тапе в peek: `.impact(.light)` (NEW)
- **D-34:** Переход peek→half: capsule bg fade in вместе с общим crossfade (0.15s easeInOut)
- **D-35:** Без анимации иконки при фокусе (статичная)

### Search Bar — Микрофон
- **D-36:** Нет микрофона — только AI sparkles toggle (deferred: SRCH-07)

### Search Bar — Clear button
- **D-37:** `xmark.circle.fill` справа, появляется когда query не пустой
- **D-38:** Clear button: 16pt, `Color.secondary`
- **D-39:** Clear button ЗАМЕНЯЕТ AI sparkles (показывается только один из двух)

### Search Bar — Sticky header (full mode)
- **D-40:** В full mode drag handle + search bar sticky при скролле контента
- **D-41:** Тонкий `Divider()` снизу sticky area при скролле
- **D-42:** В half mode — без sticky (контент не скроллится достаточно)

### Search Bar — Офлайн
- **D-43:** Без изменений в офлайн режиме (поиск работает по кэшированным данным)

### Cancel button
- **D-44:** Показывается при фокусе ИЛИ query не пустой (текущее поведение)
- **D-45:** Текст: "Отмена"
- **D-46:** Шрифт: 17pt `.regular`
- **D-47:** Цвет: `AppTheme.sakuraPink`
- **D-48:** Анимация: `.transition(.move(edge: .trailing).combined(with: .opacity))`
- **D-49:** Действие: очистить query + убрать фокус + sheet остаётся в half (не сворачивается в peek)

### AI Sparkles toggle
- **D-50:** Позиция: trailing в search bar (как сейчас)
- **D-51:** Видимость: только когда query пустой (clear button заменяет при наличии текста — D-39)
- **D-52:** Размер иконки: 17pt (в тон magnifyingglass)
- **D-53:** Цвет active: `AppTheme.sakuraPink`
- **D-54:** Цвет inactive: `Color.secondary`
- **D-55:** Анимация: `.symbolEffect(.bounce)` при toggle
- **D-56:** В peek: скрыт (peek слишком компактный)
- **D-57:** Haptic: `.impact(.light)` при toggle

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 7 context (predecessor)
- `.planning/phases/07-sheet-geometry/07-CONTEXT.md` — 40 decisions on sheet geometry, materials, drag gesture

### Requirements
- `.planning/REQUIREMENTS.md` — HNDL-01..03, SRCH-01..05 acceptance criteria

### Current code
- `Travel app/Views/Map/MapBottomSheet.swift` — sheet geometry (Phase 7 output, DO NOT modify geometry/materials)
- `Travel app/Views/Map/MapSearchContent.swift` — search field, chips, results (PRIMARY target)
- `Travel app/Views/Map/TripMapView.swift` — parent view integration

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MapSearchContent.swift`: `searchFieldContent` ViewBuilder already adapts between peek (tappable) and expanded (TextField)
- `@FocusState private var isSearchFocused: Bool` already exists
- `showCancelButton` computed property: `isSearchFocused || !vm.searchQuery.isEmpty`
- AI toggle: `vm.isAISearchEnabled` binding with sparkles icon already implemented
- `MKLocalSearchCompleter` integration for autocomplete already working

### Established Patterns
- `@Bindable var vm: MapViewModel` — search state lives in VM
- `detent: SheetDetent` passed from MapBottomSheet to content
- `.preferredColorScheme(.dark)` on Map view — all UI in dark mode

### Integration Points
- `MapBottomSheet` passes detent to content via parameter
- `MapSearchContent` receives `detent`, `vm`, `isSearchFocused` binding
- Search field tap in peek calls `detent = .half` + sets focus after 150ms delay

</code_context>

<specifics>
## Specific Ideas

- Icon и font size 17pt создают визуальное единство — Apple Maps использует SF Pro 17pt в search bar
- `RoundedRectangle(cornerRadius: 10)` вместо `Capsule()` даёт менее "кнопочный" и более "поле ввода" вид
- Clear button заменяет sparkles — не нужно два trailing элемента одновременно
- Sticky header в full mode предотвращает потерю search bar при длинном скролле
- Haptic `.impact(.light)` при раскрытии peek делает UI тактильно отзывчивым

</specifics>

<deferred>
## Deferred Ideas

- Микрофон в search bar (SRCH-07) — отдельная фаза
- Аватар профиля в search bar (SRCH-06) — отдельная фаза
- `.webSearch` keyboard type — может быть полезен, но текущий .default работает
- Scale bounce анимация иконки при фокусе — overcomplicated
- Dimmed search bar в офлайн — поиск работает по кэшу, не нужно

</deferred>

### Testing Criteria
- Search bar пропорции: 17pt icon + 17pt font + 14pt padding + 6pt spacing визуально соответствуют Apple Maps
- RoundedRectangle(10) vs Capsule() — визуальная разница заметна
- Clear button появляется/скрывается корректно при вводе/очистке текста
- Sticky header в full mode при скролле — Divider появляется
- Haptic feedback ощущается при тапе в peek и toggle sparkles
- Cancel button slide-in анимация плавная

---

*Phase: 08-search-bar-handle*
*Context gathered: 2026-03-21*
