# Requirements: Travel App v1.1 — Apple Maps UI Parity

**Defined:** 2026-03-21
**Core Value:** Карта выглядит и работает как Apple Maps — bottom sheet, search pill, floating controls, переходы между состояниями.

## v1.1 Requirements

### Sheet Geometry

- [ ] **GEOM-01**: Peek mode height = 56pt (полный search bar + верхний padding для drag handle)
- [ ] **GEOM-02**: Peek mode background = `.ultraThinMaterial` с dark color scheme, rounded на все 4 угла (cornerRadius ~22pt)
- [ ] **GEOM-03**: Peek mode padding horizontal 16pt — pill "плавает" с отступами от краёв
- [ ] **GEOM-04**: Half mode = ~40% экрана, opaque dark background, rounded top corners only (30pt)
- [ ] **GEOM-05**: Full mode = весь экран, тот же opaque dark фон, поиск сразу под safeAreaTop

### Drag Handle

- [ ] **HNDL-01**: Drag handle capsule 36pt wide x 5pt tall, `Color(.systemFill)`
- [ ] **HNDL-02**: Handle виден во ВСЕХ detent states (peek, half, full) — по центру над search bar
- [ ] **HNDL-03**: Handle padding top 10pt, bottom 6pt

### Search Bar

- [ ] **SRCH-01**: Magnifying glass icon + "Поиск на карте" placeholder + AI sparkles toggle
- [ ] **SRCH-02**: В peek mode: нет внутреннего capsule background (pill сама является фоном)
- [ ] **SRCH-03**: В half/full mode: capsule background `.quaternary.opacity(0.5)` внутри sheet
- [ ] **SRCH-04**: Тап на pill в peek → expand to full + focus text field
- [ ] **SRCH-05**: "Отмена" кнопка справа от поиска в half/full mode

### Floating Controls

- [ ] **CTRL-01**: Вертикальный стек кнопок справа: компас → транспорт → локация
- [ ] **CTRL-02**: Каждая кнопка: 44pt circle, `.ultraThinMaterial` + dark scheme background
- [ ] **CTRL-03**: Позиция: правый край (16pt от края), над peek pill (~80pt от низа)
- [ ] **CTRL-04**: Компас использует `MapCompass(scope: mapScope)` с `@Namespace`
- [ ] **CTRL-05**: Кнопка локации центрирует карту на текущем GPS
- [ ] **CTRL-06**: Кнопки плавно скрываются (opacity fade) при расширении sheet выше peek
- [ ] **CTRL-07**: Кнопка транспорта переключает отображение transit линий на карте

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
| GEOM-01 | TBD | Pending |
| GEOM-02 | TBD | Pending |
| GEOM-03 | TBD | Pending |
| GEOM-04 | TBD | Pending |
| GEOM-05 | TBD | Pending |
| HNDL-01 | TBD | Pending |
| HNDL-02 | TBD | Pending |
| HNDL-03 | TBD | Pending |
| SRCH-01 | TBD | Pending |
| SRCH-02 | TBD | Pending |
| SRCH-03 | TBD | Pending |
| SRCH-04 | TBD | Pending |
| SRCH-05 | TBD | Pending |
| CTRL-01 | TBD | Pending |
| CTRL-02 | TBD | Pending |
| CTRL-03 | TBD | Pending |
| CTRL-04 | TBD | Pending |
| CTRL-05 | TBD | Pending |
| CTRL-06 | TBD | Pending |
| CTRL-07 | TBD | Pending |
| CONT-01 | TBD | Pending |
| CONT-02 | TBD | Pending |
| CONT-03 | TBD | Pending |
| CONT-04 | TBD | Pending |
| TRAN-01 | TBD | Pending |
| TRAN-02 | TBD | Pending |
| TRAN-03 | TBD | Pending |
| TRAN-04 | TBD | Pending |

**Coverage:**
- v1.1 requirements: 24 total
- Mapped to phases: 0
- Unmapped: 24 ⚠️

---
*Requirements defined: 2026-03-21*
*Last updated: 2026-03-21 after initial definition*
