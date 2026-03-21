# Phase 11: Transitions + Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-21
**Phase:** 11-transitions-polish
**Areas discussed:** Spring consistency, Background morph, Keyboard expand flow, Corner radius morph, Floating controls fade, Content fade timing, Horizontal padding morph, Tab bar transition, Haptics, Device testing

---

## Spring consistency

| Option | Description | Selected |
|--------|-------------|----------|
| Всё на 0.35/0.85 | Все detent-анимации получают единый spring. Консистентно, как в Apple Maps | |
| Только drag snap | Обновить только drag gesture snap (MapBottomSheet), остальные оставить как есть | |
| Ты решай | Claude выберет оптимальную стратегию | ✓ |

**User's choice:** Claude's discretion
**Notes:** MapViewModel имеет ~20 мест с .spring(response: 0.3), спецификация требует 0.35/0.85

---

## Background morph

| Option | Description | Selected |
|--------|-------------|----------|
| Drag interpolation | Фон меняется плавно в реальном времени при drag — blur material fades out, opaque fades in по позиции пальца | |
| Snap crossfade | Оставить opacity crossfade при snap (0.15s easeInOut) — уже работает, но улучшить timing | |
| Ты решай | Claude выберет наиболее плавный подход без jank | ✓ |

**User's choice:** Claude's discretion
**Notes:** Текущий crossfade работает при snap, TRAN-02 требует плавный переход

---

## Keyboard expand flow

| Option | Description | Selected |
|--------|-------------|----------|
| Остаётся в full | Keyboard dismiss — sheet остаётся full, только Cancel возвращает на half | |
| Как Apple Maps | Keyboard dismiss → sheet сворачивается в half (если query пустой) или остаётся full (если есть результаты) | ✓ |
| Ты решай | Claude выберет наилучшее UX поведение | |

**User's choice:** Как Apple Maps
**Notes:** Keyboard dismiss зависит от наличия query/results

### Follow-up: Content shift при keyboard

| Option | Description | Selected |
|--------|-------------|----------|
| Нет сдвига | Keyboard перекрывает нижнюю часть контента, search bar и results остаются на месте | ✓ |
| С сдвигом | Контент сжимается, чтобы autocomplete результаты были видны над keyboard | |

**User's choice:** Нет сдвига
**Notes:** .ignoresSafeArea(.keyboard) уже на месте

---

## Corner radius morph

| Option | Description | Selected |
|--------|-------------|----------|
| Drag interpolation | bottomRadius = lerp(22, 0, progress) при drag — углы плавно скругляются/выпрямляются в реальном времени | |
| Animated snap | Оставить переключение при snap, но с spring анимацией (UnevenRoundedRectangle animatable) | |
| Ты решай | Claude выберет подход без jank | ✓ |

**User's choice:** Claude's discretion

---

## Floating controls fade

| Option | Description | Selected |
|--------|-------------|----------|
| Drag-linked fade | Opacity кнопок связана с позицией drag — плавно исчезают по мере подъёма sheet | |
| Snap fade | Быстрый spring fade при snap, не связан с drag (текущее поведение) | |
| Ты решай | Claude выберет наиболее плавный подход | ✓ |

**User's choice:** Claude's discretion

---

## Content fade timing

| Option | Description | Selected |
|--------|-------------|----------|
| Синхронно | Все секции появляются одновременно с background morph (Apple Maps поведение) | |
| Каскадный fade-in | Chips первыми, затем Сегодня, затем map controls (staggered, 50ms между секциями) | |
| Ты решай | Claude выберет подход | ✓ |

**User's choice:** Claude's discretion

---

## Horizontal padding morph

| Option | Description | Selected |
|--------|-------------|----------|
| Drag interpolation | Padding = lerp(16, 0, progress) в реальном времени при drag — pill плавно расширяется | |
| Animated snap | Переключение при snap с spring анимацией (как сейчас, но с правильным spring) | |
| Ты решай | Claude выберет подход без jank | ✓ |

**User's choice:** Claude's discretion

---

## Tab bar transition

| Option | Description | Selected |
|--------|-------------|----------|
| Как есть | Стандартная анимация UIKit (.toolbar) — достаточно плавная | |
| Синхронизировать | Синхронизировать с sheet spring анимацией | |
| Ты решай | Claude выберет лучший подход | ✓ |

**User's choice:** Claude's discretion

---

## Haptics

| Option | Description | Selected |
|--------|-------------|----------|
| Да, light impact | UIImpactFeedbackGenerator(.light) при каждом snap на detent | ✓ |
| Да, selection | UISelectionFeedbackGenerator — более мягкий отклик | |
| Нет | Без тактильного отклика | |

**User's choice:** Да, light impact

---

## Device testing

| Option | Description | Selected |
|--------|-------------|----------|
| Blur над картой | .ultraThinMaterial над парками/пляжами — Simulator не показывает реальный blur | ✓ |
| Haptics feel | Тактильный отклик на реальном железе — насколько интенсивность правильная | ✓ |
| Animation smoothness | 60fps во время drag/snap на реальном устройстве | ✓ |
| Всё выше | Верифицировать blur + haptics + animation smoothness | ✓ |

**User's choice:** Всё выше

---

## Claude's Discretion

- Spring unification strategy (all detent animations)
- Background morph approach (drag interpolation vs snap crossfade)
- Corner radius morph approach (drag interpolation vs animated snap)
- Floating controls fade strategy (drag-linked vs snap)
- Content fade timing (sync vs cascade)
- Horizontal padding morph (drag interpolation vs animated snap)
- Tab bar transition synchronization

## Deferred Ideas

- TRAN-05: Shape morph анимация (pill → full-width) — Future Requirements
- Full VoiceOver flow — после MVP
- Scroll-to-top-then-drag — слишком сложно для текущего scope
