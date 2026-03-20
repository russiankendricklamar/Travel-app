# Travel App — Map Navigation Overhaul

## What This Is

Полная переработка навигационной механики в Travel app — iOS приложении для планирования путешествий. Реализована полноценная turn-by-turn навигация уровня Apple Maps: мультимодальные маршруты с альтернативами, голосовые подсказки на любом языке, glassmorphism UI с floating HUD и bottom sheet, полный офлайн с двухуровневым кэшированием маршрутов.

## Core Value

Путешественник может построить маршрут между любыми точками, получить пошаговую навигацию с голосом на любом транспорте, и всё это работает офлайн в чужой стране без интернета.

## Requirements

### Validated

- ✓ Базовая карта с MapKit — existing
- ✓ Отображение мест и пинов на карте — existing
- ✓ AI поиск мест на карте — existing
- ✓ Отображение маршрутов (polyline) — existing
- ✓ Bottom sheet с деталями мест — existing
- ✓ Офлайн кэш снимков карты (MKMapSnapshotter) — existing
- ✓ MapViewModel с состояниями — existing
- ✓ Turn-by-turn навигация с отслеживанием положения — v1.0 (Phase 1)
- ✓ Голосовые подсказки через AVSpeechSynthesizer (500м/200м/прибытие) — v1.0 (Phase 1)
- ✓ Пошаговые инструкции поворотов (NavigationStep модель) — v1.0 (Phase 1)
- ✓ Автоматическое перестроение маршрута при отклонении (30м + 8с debounce) — v1.0 (Phase 1)
- ✓ Фоновый GPS при заблокированном экране — v1.0 (Phase 1)
- ✓ Floating HUD с иконкой манёвра, инструкцией и расстоянием — v1.0 (Phase 2)
- ✓ Старт/стоп навигации из карточки маршрута — v1.0 (Phase 2)
- ✓ Камера следует за пользователем с heading lock — v1.0 (Phase 2)
- ✓ Bottom sheet в навигационном режиме (peek + expanded step list) — v1.0 (Phase 2)
- ✓ Контекст поездки "День N из M" во время навигации — v1.0 (Phase 2)
- ✓ Построение маршрутов с 2-3 альтернативами — v1.0 (Phase 3)
- ✓ Мультимодальные маршруты (пешком, авто, транспорт, велосипед) — v1.0 (Phase 3)
- ✓ ETA и расстояние на каждом варианте маршрута — v1.0 (Phase 3)
- ✓ CachedRoute @Model для хранения маршрутов в SwiftData — v1.0 (Phase 4)
- ✓ Cache-first lookup в RoutingService — v1.0 (Phase 4, 6)
- ✓ "Подготовить офлайн" предзагрузка маршрутов дня — v1.0 (Phase 4)
- ✓ Graceful degradation без сети — v1.0 (Phase 4, 5)

### Active

- [ ] Комбинированные маршруты (метро + пешком) в одном маршруте
- [ ] Lane guidance (подсказки полос) где доступно
- [ ] Floating search bar поверх карты
- [ ] Карточки мест в стиле Apple Maps
- [ ] Полный офлайн: предзагрузка тайлов карты региона
- [ ] Live Activity при активной навигации (Dynamic Island)

### Out of Scope

- AR-навигация — отдельный scope, не связан с картами
- Свой рендеринг карт (MapLibre/Mapbox) — используем нативный MapKit
- Навигация для грузовиков/мотоциклов — только пешком, авто, транспорт
- Свой собственный TTS движок — системный AVSpeechSynthesizer достаточен
- CarPlay — сложные entitlements, минимальная потребность путешественников

## Context

Shipped v1.0 with 44,806 LOC Swift.
Tech stack: SwiftUI, MapKit, SwiftData, AVFoundation, @Observable pattern.
Navigation system: NavigationEngine (state machine) + NavigationVoiceService + RoutingService (multi-source).
Offline: Two-tier L1/L2 cache (memory + SwiftData), OfflineCacheManager with NWPathMonitor.
Glassmorphism design system throughout.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| MapKit вместо Mapbox/MapLibre | Нативная интеграция, бесплатно, Apple Maps стиль | ✓ Good — glassmorphism + MapKit отлично сочетаются |
| AVSpeechSynthesizer для голоса | Бесплатный, офлайн, все языки iOS | ✓ Good — работает на всех языках без API ключей |
| Улучшение а не переписывание | Сохраняем рабочий функционал, меньше риск регрессий | ✓ Good — 2,880 строк добавлено в существующую архитектуру |
| Кэш маршрутов для офлайн | Apple не даёт офлайн routing | ✓ Good — L1+L2 cache покрывает все use cases |
| NavigationEngine как pure logic (Phase 1) | Стабильный API до UI работы | ✓ Good — Phase 2 UI построен без изменений engine |
| Google Routes API для альтернатив | MKDirections не даёт альтернативы надёжно | ✓ Good — 2-3 альтернативы через Edge Function |
| JSON Data вместо externalStorage | Маршруты маленькие, нужны predicate queries | ✓ Good — быстрый поиск по UUID |
| modelContext injection через .onAppear | Earliest safe point для SwiftData контекста | ✓ Good — решило @MainActor isolation |

## Constraints

- **Platform**: iOS only, MapKit only (no third-party map SDKs)
- **Offline**: MKMapSnapshotter для тайлов; кэширование предпостроенных маршрутов в SwiftData
- **Voice**: AVSpeechSynthesizer — системный, бесплатный, все языки iOS
- **Design**: Glassmorphism стиль приложения
- **Architecture**: @Observable pattern, SwiftData для persistence

---
*Last updated: 2026-03-21 after v1.0 milestone*
