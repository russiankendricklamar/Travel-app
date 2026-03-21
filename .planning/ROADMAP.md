# Roadmap: Travel App

## Milestones

- ✅ **v1.0 Map Navigation Overhaul** — Phases 1-6 (shipped 2026-03-21)
- 🚧 **v1.1 Apple Maps UI Parity** — Phases 7-11 (in progress)

## Phases

<details>
<summary>✅ v1.0 Map Navigation Overhaul (Phases 1-6) — SHIPPED 2026-03-21</summary>

- [x] Phase 1: Navigation Engine (3/3 plans) — completed 2026-03-20
- [x] Phase 2: Navigation UI (2/2 plans) — completed 2026-03-20
- [x] Phase 3: Route Selection (2/2 plans) — completed 2026-03-20
- [x] Phase 4: Offline Routes (3/3 plans) — completed 2026-03-20
- [x] Phase 5: Offline Route Fixes (1/1 plan) — completed 2026-03-20
- [x] Phase 6: Offline Cache Wiring (1/1 plan) — completed 2026-03-20

See: `.planning/milestones/v1.0-ROADMAP.md` for full details.

</details>

### v1.1 Apple Maps UI Parity (In Progress)

**Milestone Goal:** Карта выглядит и работает как Apple Maps — bottom sheet с правильными detent states, search pill с blur и пропорциями Apple Maps, floating controls, и плавные переходы между состояниями.

- [x] **Phase 7: Sheet Geometry** — Правильная геометрия peek/half/full и фоновые материалы (completed 2026-03-21)
- [x] **Phase 8: Search Bar + Handle** — Drag handle и search bar полностью соответствуют Apple Maps (completed 2026-03-21)
- [x] **Phase 9: Floating Controls** — Вертикальный стек кнопок справа с native MapKit интеграцией (completed 2026-03-21)
- [x] **Phase 10: Sheet Content** — Category chips, секции контента и скролл без конфликтов (completed 2026-03-21)
- [ ] **Phase 11: Transitions + Polish** — Spring анимации, морф фона и финальная полировка

## Phase Details

### Phase 7: Sheet Geometry
**Goal**: Sheet корректно отображается во всех трёх состояниях с правильными фоновыми материалами
**Depends on**: Phase 6 (v1.0 complete)
**Requirements**: GEOM-01, GEOM-02, GEOM-03, GEOM-04, GEOM-05
**Success Criteria** (what must be TRUE):
  1. Peek pill плавает над картой с 16pt отступами от краёв и видимым зазором от safe area
  2. Peek pill имеет blur эффект `.ultraThinMaterial` — карта просвечивает сквозь фон на любых тайлах (парки, пляжи)
  3. Half mode открывается на ~40% высоты экрана с непрозрачным тёмным фоном и скруглением только сверху
  4. Full mode занимает весь экран, поиск виден сразу под status bar
  5. Все три состояния используют единую `UnevenRoundedRectangle` форму без snap при переходе
**Plans:** 1/1 plans complete
Plans:
- [x] 07-01-PLAN.md — Refactor MapBottomSheet geometry, materials, and unified shape

### Phase 8: Search Bar + Handle
**Goal**: Drag handle и search bar имеют правильные пропорции и поведение
**Depends on**: Phase 7
**Requirements**: HNDL-01, HNDL-02, HNDL-03, SRCH-01, SRCH-02, SRCH-03, SRCH-04, SRCH-05
**Success Criteria** (what must be TRUE):
  1. Drag handle виден во всех трёх состояниях как 36pt x 5pt capsule по центру сверху
  2. В peek mode search bar не имеет внутреннего фона — сама pill является фоном
  3. В half/full mode search bar показывает capsule background `.quaternary.opacity(0.5)` внутри sheet
  4. Тап на pill в peek mode раскрывает sheet до full и фокусирует текстовое поле
  5. Кнопка "Отмена" появляется справа от поиска в half/full mode
**Plans:** 1/1 plans complete
Plans:
- [x] 08-01-PLAN.md — Restyle search bar, cancel button, clear/sparkles, haptics, sticky header

### Phase 9: Floating Controls
**Goal**: Вертикальный стек кнопок справа от карты работает с native MapKit интеграцией
**Depends on**: Phase 7
**Requirements**: CTRL-01, CTRL-02, CTRL-03, CTRL-04, CTRL-05, CTRL-06, CTRL-07
**Success Criteria** (what must be TRUE):
  1. Три кнопки (компас, транспорт, локация) выровнены вертикально справа, 16pt от края, ~80pt от низа
  2. Каждая кнопка — 44pt круг с `.ultraThinMaterial` фоном в dark color scheme
  3. Кнопка локации центрирует карту на текущем GPS при нажатии
  4. Компас использует нативный `MapCompass(scope: mapScope)` и скрывается когда north facing
  5. Кнопки плавно исчезают (opacity fade) когда sheet поднимается выше peek — без резких появлений/исчезновений
**Plans:** 1/1 plans complete
Plans:
- [x] 09-01-PLAN.md — Floating controls overlay with compass, transit/3D/location buttons, and TripMapView wiring

### Phase 10: Sheet Content
**Goal**: Контент sheet заполняет half/full mode без пустых областей и конфликтов жестов
**Depends on**: Phase 8
**Requirements**: CONT-01, CONT-02, CONT-03, CONT-04
**Success Criteria** (what must be TRUE):
  1. Category chips (Музеи, Парки, Магазины, Отели) видны под search bar в half/full mode
  2. Секция "Сегодня · [Город]" показывает today's places в half/full mode
  3. Map controls row (Слои, Осадки, Обзор, Все места) доступен в half mode
  4. Скролл контента в half/full не перехватывает drag gesture sheet при движении вниз
**Plans:** 1/1 plans complete
Plans:
- [x] 10-01-PLAN.md — Fix idle content visibility, fade animation, today's places truncation

### Phase 11: Transitions + Polish
**Goal**: Все переходы между состояниями плавные, без визуальных артефактов, верифицированы на физическом устройстве
**Depends on**: Phase 9, Phase 10
**Requirements**: TRAN-01, TRAN-02, TRAN-03, TRAN-04
**Success Criteria** (what must be TRUE):
  1. Переход между detent states анимируется через spring (response: 0.35, dampingFraction: 0.85) без ощущения резкости
  2. При переходе peek → half фон плавно меняется от blur pill к непрозрачному sheet
  3. Corner radius плавно морфирует от all-corners (peek) к top-only (half/full) в процессе drag
  4. Тап на поиск: sheet раскрывается до full, затем через 150ms появляется клавиатура — без сдвига контента
**Plans:** 1 plan
Plans:
- [ ] 11-01-PLAN.md — Drag-progress morph, spring unification, haptics

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Navigation Engine | v1.0 | 3/3 | Complete | 2026-03-20 |
| 2. Navigation UI | v1.0 | 2/2 | Complete | 2026-03-20 |
| 3. Route Selection | v1.0 | 2/2 | Complete | 2026-03-20 |
| 4. Offline Routes | v1.0 | 3/3 | Complete | 2026-03-20 |
| 5. Offline Route Fixes | v1.0 | 1/1 | Complete | 2026-03-20 |
| 6. Offline Cache Wiring | v1.0 | 1/1 | Complete | 2026-03-20 |
| 7. Sheet Geometry | v1.1 | 1/1 | Complete   | 2026-03-21 |
| 8. Search Bar + Handle | v1.1 | 1/1 | Complete   | 2026-03-21 |
| 9. Floating Controls | v1.1 | 1/1 | Complete   | 2026-03-21 |
| 10. Sheet Content | v1.1 | 1/1 | Complete    | 2026-03-21 |
| 11. Transitions + Polish | v1.1 | 0/1 | Not started | - |
