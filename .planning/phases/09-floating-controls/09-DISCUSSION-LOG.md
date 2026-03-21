# Phase 9: Floating Controls - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-21
**Phase:** 09-floating-controls
**Areas discussed:** Визуальная группировка, Кнопка транспорта, Fade поведение, Компас, Иконка локации, Позиционирование, A11y, Офлайн, Размер/цвет иконок, 3D кнопка, Поведение location, 3D toggle UX

---

## Визуальная группировка

| Option | Description | Selected |
|--------|-------------|----------|
| Единый контейнер | Один скруглённый blur-контейнер с разделителями — как Apple Maps | ✓ |
| Отдельные круги | Три отдельных 44pt круга с gap между ними | |

**User's choice:** Единый контейнер
**Notes:** Тонкие линии 0.5pt white.opacity(0.15), RoundedRect 12pt, тень как у peek pill, 44pt впритык без паддингов, контейнер сжимается когда компас hidden

---

## Кнопка транспорта

| Option | Description | Selected |
|--------|-------------|----------|
| bus.fill | SF Symbol bus.fill — понятно всем | ✓ |
| tram.fill | Более универсальный public transport | |
| car.fill | Скорее про дороги, не transit | |

**User's choice:** bus.fill

| Option | Description | Selected |
|--------|-------------|----------|
| showsTraffic toggle | Переключает showsTraffic: true/false | ✓ |
| mapStyle переключение | Между .standard и .hybrid | |
| Ты решай | Claude выбирает | |

**User's choice:** showsTraffic toggle, начальное состояние true, акцентный цвет при active, haptic .impact(.light)

---

## Fade поведение

| Option | Description | Selected |
|--------|-------------|----------|
| Snap по detent | Показаны в peek, скрыты в half/full. Spring анимация | ✓ |
| Плавный по drag | Opacity связана с drag offset | |

**User's choice:** Snap по detent

**Additional decisions:**
- Скрывать при навигации (vm.isNavigating)
- Скрывать при precipitation overlay
- Fade анимация = sheet spring (response: 0.35, dampingFraction: 0.85)

---

## Компас

| Option | Description | Selected |
|--------|-------------|----------|
| Native MapCompass | MapCompass(scope:) — auto hide/show, native стиль | ✓ |
| Custom компас | Своя кнопка с кастомной иконкой | |

**User's choice:** Native MapCompass, отдельно сверху над контейнером (8pt gap), MapScaleView остаётся в .mapControls

---

## Иконка локации

| Option | Description | Selected |
|--------|-------------|----------|
| location (outline) | Как Apple Maps | ✓ |
| location.fill | Текущая иконка (filled) | |
| location.north.fill | Со стрелкой на север | |

**User's choice:** location (outline)

---

## Позиционирование

| Option | Description | Selected |
|--------|-------------|----------|
| 80pt (по CTRL-03) | Над peek pill с небольшим gap | |
| 90pt (текущее) | Как сейчас у location button | |
| Ты решай | Claude подберёт | ✓ |

**User's choice:** Claude's discretion

---

## Accessibility

| Option | Description | Selected |
|--------|-------------|----------|
| Базовые labels | accessibilityLabel + hint на каждую кнопку | ✓ |
| Ты решай | Claude добавит | |

**User's choice:** Базовые labels

---

## Офлайн

| Option | Description | Selected |
|--------|-------------|----------|
| Скрыть | При isOfflineWithCache кнопки не нужны | ✓ |
| Оставить | Кнопки видны поверх offline gallery | |

**User's choice:** Скрыть

---

## 3D кнопка (scope extension)

| Option | Description | Selected |
|--------|-------------|----------|
| Только 3 кнопки | Компас/транспорт/локация по CTRL-01 | |
| Добавить 3D/Globe | 4-я кнопка в контейнере | ✓ |

**User's choice:** Добавить в Phase 9 (расширение scope)

| Option | Description | Selected |
|--------|-------------|----------|
| 2D ↔ 3D realistic | elevation: .realistic ↔ .flat | ✓ |
| Standard ↔ Satellite | .standard ↔ .imagery | |
| 3-way cycle | Standard → 3D → Satellite | |

**User's choice:** 2D ↔ 3D realistic, иконка view.3d/view.2d, sakuraPink при active, между transit и location

---

## Поведение location

| Option | Description | Selected |
|--------|-------------|----------|
| Простой center | Один тап — центрирует на GPS | ✓ |
| Двойной режим | 1-й тап center, 2-й heading mode | |

**User's choice:** Простой center

---

## Claude's Discretion

- Размер и weight SF Symbol иконок
- Точный bottom offset контейнера
- Анимация смены иконки при toggle
- Начальное состояние elevation

## Deferred Ideas

- Heading mode для location (двойной тап → follow rotation)
- Satellite view toggle
- 3-way map style cycle
