# Requirements: Travel App v1.1 — Apple Maps UI Parity

**Defined:** 2026-03-21
**Core Value:** Карта выглядит и работает как Apple Maps — bottom sheet, search pill, floating controls, переходы между состояниями.

## v1.1 Requirements

### Sheet Geometry

- [x] **GEOM-01**: Peek mode height = 56pt (полный search bar + верхний padding для drag handle)
- [x] **GEOM-02**: Peek mode background = `.ultraThinMaterial` с dark color scheme, rounded на все 4 угла (cornerRadius ~22pt)
- [x] **GEOM-03**: Peek mode padding horizontal 16pt — pill "плавает" с отступами от краёв
- [x] **GEOM-04**: Half mode = ~40% экрана, opaque dark background, rounded top corners only (30pt)
- [x] **GEOM-05**: Full mode = весь экран, тот же opaque dark фон, поиск сразу под safeAreaTop

### Drag Handle

- [x] **HNDL-01**: Drag handle capsule 36pt wide x 5pt tall, `Color(.systemFill)`
- [x] **HNDL-02**: Handle виден во ВСЕХ detent states (peek, half, full) — по центру над search bar
- [x] **HNDL-03**: Handle padding top 10pt, bottom 6pt

### Search Bar

- [x] **SRCH-01**: Magnifying glass icon + "Поиск на карте" placeholder + AI sparkles toggle
- [x] **SRCH-02**: В peek mode: нет внутреннего capsule background (pill сама является фоном)
- [x] **SRCH-03**: В half/full mode: capsule background `.quaternary.opacity(0.5)` внутри sheet
- [x] **SRCH-04**: Тап на pill в peek → expand to full + focus text field
- [x] **SRCH-05**: "Отмена" кнопка справа от поиска в half/full mode

### Floating Controls

- [x] **CTRL-01**: Вертикальный стек кнопок справа: компас → транспорт → локация
- [x] **CTRL-02**: Каждая кнопка: 44pt circle, `.ultraThinMaterial` + dark scheme background
- [x] **CTRL-03**: Позиция: правый край (16pt от края), над peek pill (~80pt от низа)
- [x] **CTRL-04**: Компас использует `MapCompass(scope: mapScope)` с `@Namespace`
- [x] **CTRL-05**: Кнопка локации центрирует карту на текущем GPS
- [x] **CTRL-06**: Кнопки плавно скрываются (opacity fade) при расширении sheet выше peek
- [x] **CTRL-07**: Кнопка транспорта переключает отображение transit линий на карте

### Sheet Content

- [ ] **CONT-01**: Category chips (Музеи, Парки, Магазины, Отели) под search bar в half/full
- [ ] **CONT-02**: "Сегодня · [Город]" секция с today's places
- [ ] **CONT-03**: Map controls row (Слои, Осадки, Обзор, Все места) в half mode
- [ ] **CONT-04**: Scrollable content в half/full mode не конфликтует с drag gesture

### Transitions

- [ ] **TRAN-01**: Spring animation (response: 0.35, dampingFraction: 0.85) для detent переходов
- [ ] **TRAN-02**: Background morph: blur pill → opaque sheet плавно при переходе peek → half
- [ ] **TRAN-03**: Corner radius morph: all-corners (peek) → top-only (half/full)
- [ ] **TRAN-04**: Keyboard expand: sheet → full, затем 150ms delay → focus text field

## Future Requirements

- **GEOM-06**: Look Around button (бинокль) в левом нижнем углу карты
- **SRCH-06**: Аватар профиля в правом конце search bar (как в Apple Maps)
- **SRCH-07**: Иконка микрофона в search bar
- **CONT-05**: "Места" секция (Дом/Работа/Добавить) в half mode
- **CONT-06**: "Недавние" секция с историей поиска
- **TRAN-05**: Shape morph анимация (pill → full-width с интерполяцией cornerRadius)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Weather badge (top-left) | Отдельный виджет, не связан с bottom sheet |
| Look Around (бинокль) | Нет доступа к Look Around API в MapKit для сторонних приложений |
| "Ваши путеводители" секция | Нет данных путеводителей в приложении |
| Real-time transit данные | Требует отдельного API интеграции |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GEOM-01 | Phase 7 | Complete |
| GEOM-02 | Phase 7 | Complete |
| GEOM-03 | Phase 7 | Complete |
| GEOM-04 | Phase 7 | Complete |
| GEOM-05 | Phase 7 | Complete |
| HNDL-01 | Phase 8 | Complete |
| HNDL-02 | Phase 8 | Complete |
| HNDL-03 | Phase 8 | Complete |
| SRCH-01 | Phase 8 | Complete |
| SRCH-02 | Phase 8 | Complete |
| SRCH-03 | Phase 8 | Complete |
| SRCH-04 | Phase 8 | Complete |
| SRCH-05 | Phase 8 | Complete |
| CTRL-01 | Phase 9 | Complete |
| CTRL-02 | Phase 9 | Complete |
| CTRL-03 | Phase 9 | Complete |
| CTRL-04 | Phase 9 | Complete |
| CTRL-05 | Phase 9 | Complete |
| CTRL-06 | Phase 9 | Complete |
| CTRL-07 | Phase 9 | Complete |
| CONT-01 | Phase 10 | Pending |
| CONT-02 | Phase 10 | Pending |
| CONT-03 | Phase 10 | Pending |
| CONT-04 | Phase 10 | Pending |
| TRAN-01 | Phase 11 | Pending |
| TRAN-02 | Phase 11 | Pending |
| TRAN-03 | Phase 11 | Pending |
| TRAN-04 | Phase 11 | Pending |

**Coverage:**
- v1.1 requirements: 28 total
- Mapped to phases: 28
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-21*
*Last updated: 2026-03-21 after roadmap creation*
