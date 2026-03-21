# Phase 11: Transitions + Polish - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Плавные переходы между detent states (peek/half/full): spring анимации, морф фона и corner radius, keyboard expand flow, haptics при snap, синхронизация floating controls и контента с переходами. Финальная полировка v1.1 milestone.

</domain>

<decisions>
## Implementation Decisions

### Spring consistency
- **D-01:** Claude's discretion — унифицировать spring параметры в MapViewModel (~20 мест используют `.spring(response: 0.3)` без dampingFraction) vs спецификация `response: 0.35, dampingFraction: 0.85`
- **D-02:** Drag gesture snap spring уже правильный: `response: 0.35, dampingFraction: 0.85` (MapBottomSheet line 150)

### Background morph
- **D-03:** Claude's discretion — выбрать между drag interpolation (opacity фона связана с позицией drag) и улучшенным snap crossfade для перехода blur pill → opaque sheet
- **D-04:** Текущий crossfade `.easeInOut(duration: 0.15)` при snap — базовая реализация из Phase 7 (D-14)

### Corner radius morph
- **D-05:** Claude's discretion — выбрать между drag interpolation (bottomRadius = lerp(22, 0, progress)) и animated snap (UnevenRoundedRectangle с spring анимацией) для перехода all-corners → top-only
- **D-06:** Top radius = 22pt всегда (не меняется), bottom radius = 22pt (peek) → 0pt (half/full) — из Phase 7 D-17/D-18

### Keyboard expand flow
- **D-07:** Тап на search в peek → sheet раскрывается до full → 150ms delay → keyboard appears (зафиксировано в STATE.md)
- **D-08:** Keyboard dismiss поведение как Apple Maps: если query пустой → sheet сворачивается в half; если есть результаты → остаётся full
- **D-09:** При появлении keyboard контент НЕ сдвигается — keyboard перекрывает нижнюю часть, search bar и results остаются на месте (`.ignoresSafeArea(.keyboard)` уже на месте)

### Floating controls fade
- **D-10:** Claude's discretion — выбрать между drag-linked fade (opacity связана с позицией drag) и snap fade (текущее поведение через `.animation(.spring(...), value: isVisible)`)

### Content fade timing
- **D-11:** Claude's discretion — выбрать между синхронным появлением всех секций с background morph и каскадным staggered fade-in (chips → Сегодня → map controls)

### Horizontal padding morph
- **D-12:** Claude's discretion — выбрать между drag interpolation (padding = lerp(16, 0, progress)) и animated snap с spring для перехода 16pt → 0pt

### Haptics
- **D-13:** UIImpactFeedbackGenerator(.light) при каждом snap на detent (peek/half/full)
- **D-14:** Haptic срабатывает в `onEnded` drag gesture при определении nearest detent

### Tab bar transition
- **D-15:** Claude's discretion — оставить стандартную `.toolbar` анимацию или синхронизировать с sheet spring

### Physical device verification
- **D-16:** Blur над картой — .ultraThinMaterial над парками/пляжами/водой (Simulator не показывает реальный blur)
- **D-17:** Haptics feel — интенсивность .light impact на реальном устройстве
- **D-18:** Animation smoothness — 60fps во время drag/snap на реальном устройстве

### Claude's Discretion
- Spring unification strategy (D-01)
- Background morph approach: drag interpolation vs snap crossfade (D-03)
- Corner radius morph approach: drag interpolation vs animated snap (D-05)
- Floating controls fade strategy (D-10)
- Content fade timing: синхронно vs каскад (D-11)
- Horizontal padding morph: drag interpolation vs animated snap (D-12)
- Tab bar transition synchronization (D-15)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Predecessor phase contexts
- `.planning/phases/07-sheet-geometry/07-CONTEXT.md` — 40 decisions on geometry, materials, drag gesture, shape (peek 56pt, half 40%, full, UnevenRoundedRectangle, spring params)
- `.planning/phases/10-sheet-content/10-CONTEXT.md` — content visibility, section ordering, scroll/drag strategy

### Requirements
- `.planning/REQUIREMENTS.md` — TRAN-01..04 acceptance criteria

### Current code (must read before modifying)
- `Travel app/Views/Map/MapBottomSheet.swift` — PRIMARY target: sheet geometry, background, drag gesture, shape (157 lines)
- `Travel app/Views/Map/MapViewModel.swift` — ~20 spring animations to audit, detent state management
- `Travel app/Views/Map/MapSearchContent.swift` — keyboard focus flow, content transitions
- `Travel app/Views/Map/FloatingControlsOverlay.swift` — controls fade animation
- `Travel app/Views/Map/TripMapView.swift` — tab bar toolbar, isIdleMode, sheet integration

### State decisions
- `.planning/STATE.md` — accumulated decisions: spring params locked, focus delay 150ms locked, opacity crossfade approach from Phase 7

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MapBottomSheet.dragGesture()`: drag gesture with velocity threshold and spring snap — needs haptic addition
- `.spring(response: 0.35, dampingFraction: 0.85)`: already used in drag snap (line 150) and FloatingControlsOverlay (line 38)
- `UnevenRoundedRectangle`: already used for both peek and expanded backgrounds with different bottom radii
- `.transition(.opacity)` + `.animation(.easeInOut(duration: 0.15), value: isPeek)`: existing crossfade mechanism

### Established Patterns
- `isPeek = detent == .peek`: boolean flag drives background/shape selection (if/else in background modifier)
- `@Binding var detent: SheetDetent`: parent controls detent, sheet animates to it
- `withAnimation(.spring(response: 0.3))`: used in MapViewModel for programmatic detent changes (~20 call sites)
- `.animation(.spring(...), value: isVisible)`: used in FloatingControlsOverlay for fade

### Integration Points
- `MapBottomSheet.dragGesture().onEnded`: haptic trigger point — after determining nearest detent
- `MapBottomSheet.background {}`: background morph logic — currently two separate branches for peek/expanded
- `.padding(.horizontal, isPeek ? 16 : 0)`: padding morph point
- `TripMapView line 161`: `.animation(.spring(response: 0.35, dampingFraction: 0.85), value: isIdleMode)` — tab bar animation
- `MapSearchContent line 74-78`: `.onChange(of: vm.sheetDetent)` — keyboard dismiss handling point

</code_context>

<specifics>
## Specific Ideas

- Переходы должны ощущаться как в Apple Maps — плавные, без рывков, с тактильным откликом
- Phase 7 deferred: "Scroll-to-top-then-drag поведение" и ".regularMaterial fallback для навигации" — можно рассмотреть в рамках polish
- Все animation timing должны быть консистентны — единый spring для sheet transitions
- Physical device verification обязательна перед закрытием milestone v1.1

</specifics>

<deferred>
## Deferred Ideas

- TRAN-05: Shape morph анимация (pill → full-width с интерполяцией cornerRadius) — Future Requirements
- Full VoiceOver flow с объявлением состояний sheet — после MVP
- Scroll-to-top-then-drag поведение — слишком сложно для текущего scope

</deferred>

---

*Phase: 11-transitions-polish*
*Context gathered: 2026-03-21*
