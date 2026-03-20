# Requirements: Map Navigation Overhaul

**Defined:** 2026-03-20
**Core Value:** Путешественник может построить маршрут между любыми точками, получить пошаговую навигацию с голосом на любом транспорте, и всё это работает офлайн в чужой стране без интернета.

## v1 Requirements

### Маршрутизация

- [ ] **ROUTE-01**: Построение маршрута через MKDirections с 2-3 альтернативными вариантами
- [ ] **ROUTE-02**: Переключение транспортного режима (пешком, авто, транспорт, велосипед)
- [ ] **ROUTE-03**: Отображение ETA и расстояния для каждого транспортного режима одновременно
- [ ] **ROUTE-04**: Список пошаговых инструкций (turn-by-turn step list) в bottom sheet

### Навигация

- [ ] **NAV-01**: Активный режим навигации с auto-pan карты и heading lock
- [x] **NAV-02**: Голосовые подсказки через AVSpeechSynthesizer (язык устройства, включая русский)
- [ ] **NAV-03**: Детекция отклонения от маршрута (>30м) с автоматическим перестроением
- [ ] **NAV-04**: Дебаунс перестроения маршрута (минимум 8с между запросами)
- [ ] **NAV-05**: Корректная работа GPS в фоне (allowsBackgroundLocationUpdates + UIBackgroundModes plist)
- [ ] **NAV-06**: Кнопка "Начать навигацию" в UI маршрута

### UI карты

- [ ] **UI-01**: NavigationHUD — floating карточка следующего манёвра с расстоянием и иконкой направления
- [ ] **UI-02**: Навигационный detent (.small) в bottom sheet при активной навигации
- [ ] **UI-03**: Контекст поездки в навигации — "День 2 из 7 — Токио"
- [ ] **UI-04**: Glassmorphism стиль для всех новых навигационных компонентов

### Офлайн

- [ ] **OFFL-01**: CachedRoute @Model в SwiftData для хранения сериализованных маршрутов
- [ ] **OFFL-02**: Cache-first lookup в RoutingService (офлайн маршрут если есть в кэше)
- [ ] **OFFL-03**: Кнопка "Подготовить офлайн" — предзагрузка маршрутов между всеми местами дня
- [ ] **OFFL-04**: Graceful degradation при отсутствии сети — сообщение "маршруты сохранены, тайлы зависят от подключения"

## v2 Requirements

### Live Activity

- **LIVE-01**: NavigationActivityAttributes с манёвром + расстоянием + ETA
- **LIVE-02**: Dynamic Island compact display с текущим поворотом
- **LIVE-03**: Per-step обновления из NavigationEngine в LiveActivityManager

### Расширенная навигация

- **NAVX-01**: Погодо-зависимый выбор транспорта ("дождь — лучше метро")
- **NAVX-02**: Межгородские маршруты на обзорной карте поездки
- **NAVX-03**: Lane guidance (подсказки по полосам) где доступно

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mapbox/MapLibre (custom tiles) | Нативный MapKit достаточен, бесплатен, glassmorphism из коробки |
| AR-навигация | Отдельный scope, не связан с картами |
| CarPlay | Сложные entitlements, минимальная потребность путешественников |
| Truck/motorcycle routing | MKDirections не поддерживает; пешком/авто/транспорт покрывают 99% |
| Speed cameras / превышение скорости | Не приложение для водителей; путешественники ходят пешком/ездят на транспорте |
| Подписка на навигацию | Навигация — core utility, должна быть бесплатной |
| Real-time crowd density | Требует сторонних данных; рейтинги мест достаточны |
| Custom TTS движок | AVSpeechSynthesizer бесплатен, офлайн, все языки iOS |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ROUTE-01 | Phase 3 | Pending |
| ROUTE-02 | Phase 3 | Pending |
| ROUTE-03 | Phase 3 | Pending |
| ROUTE-04 | Phase 1 | Pending |
| NAV-01 | Phase 1 | Pending |
| NAV-02 | Phase 1 | Complete |
| NAV-03 | Phase 1 | Pending |
| NAV-04 | Phase 1 | Pending |
| NAV-05 | Phase 1 | Pending |
| NAV-06 | Phase 2 | Pending |
| UI-01 | Phase 2 | Pending |
| UI-02 | Phase 2 | Pending |
| UI-03 | Phase 2 | Pending |
| UI-04 | Phase 2 | Pending |
| OFFL-01 | Phase 4 | Pending |
| OFFL-02 | Phase 4 | Pending |
| OFFL-03 | Phase 4 | Pending |
| OFFL-04 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-03-20*
*Last updated: 2026-03-20 after roadmap phase mapping*
