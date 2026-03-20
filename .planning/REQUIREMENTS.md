# Requirements: Map Navigation Overhaul

**Defined:** 2026-03-20
**Core Value:** Путешественник может построить маршрут между любыми точками, получить пошаговую навигацию с голосом на любом транспорте, и всё это работает офлайн в чужой стране без интернета.

## v1 Requirements

### Маршрутизация

- [x] **ROUTE-01**: Построение маршрута через MKDirections с 2-3 альтернативными вариантами
- [x] **ROUTE-02**: Переключение транспортного режима (пешком, авто, транспорт, велосипед)
- [x] **ROUTE-03**: Отображение ETA и расстояния для каждого транспортного режима одновременно
- [x] **ROUTE-04**: Список пошаговых инструкций (turn-by-turn step list) в bottom sheet

### Навигация

- [x] **NAV-01**: Активный режим навигации с auto-pan карты и heading lock
- [x] **NAV-02**: Голосовые подсказки через AVSpeechSynthesizer (язык устройства, включая русский)
- [x] **NAV-03**: Детекция отклонения от маршрута (>30м) с автоматическим перестроением
- [x] **NAV-04**: Дебаунс перестроения маршрута (минимум 8с между запросами)
- [x] **NAV-05**: Корректная работа GPS в фоне (allowsBackgroundLocationUpdates + UIBackgroundModes plist)
- [x] **NAV-06**: Кнопка "Начать навигацию" в UI маршрута

### UI карты

- [x] **UI-01**: NavigationHUD — floating карточка следующего манёвра с расстоянием и иконкой направления
- [x] **UI-02**: Навигационный detent (.small) в bottom sheet при активной навигации
- [x] **UI-03**: Контекст поездки в навигации — "День 2 из 7 — Токио"
- [x] **UI-04**: Glassmorphism стиль для всех новых навигационных компонентов

### Офлайн

- [x] **OFFL-01**: CachedRoute @Model в SwiftData для хранения сериализованных маршрутов
- [ ] **OFFL-02**: Cache-first lookup в RoutingService (офлайн маршрут если есть в кэше)
- [x] **OFFL-03**: Кнопка "Подготовить офлайн" — предзагрузка маршрутов между всеми местами дня
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
| ROUTE-01 | Phase 3 | Complete |
| ROUTE-02 | Phase 3 | Complete |
| ROUTE-03 | Phase 3 | Complete |
| ROUTE-04 | Phase 1 | Complete |
| NAV-01 | Phase 1 | Complete |
| NAV-02 | Phase 1 | Complete |
| NAV-03 | Phase 1 | Complete |
| NAV-04 | Phase 1 | Complete |
| NAV-05 | Phase 1 | Complete |
| NAV-06 | Phase 2 | Complete |
| UI-01 | Phase 2 | Complete |
| UI-02 | Phase 2 | Complete |
| UI-03 | Phase 2 | Complete |
| UI-04 | Phase 2 | Complete |
| OFFL-01 | Phase 4 | Complete |
| OFFL-02 | Phase 5 | Pending |
| OFFL-03 | Phase 4 | Complete |
| OFFL-04 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-03-20*
*Last updated: 2026-03-21 after milestone audit gap closure*
