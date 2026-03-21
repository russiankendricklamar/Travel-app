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

- ✓ Bottom sheet geometry: 3 detent states (peek 56pt / half 40% / full) с правильной стилистикой — v1.1 (Phase 7)
- ✓ Peek mode: тёмная полупрозрачная таблетка с `.ultraThinMaterial` blur — v1.1 (Phase 7)
- ✓ Half/Full mode: непрозрачный тёмный фон, единый `UnevenRoundedRectangle` shape — v1.1 (Phase 7)
- ✓ Search bar в стиле Apple Maps: 17pt пропорции, RoundedRectangle(10), clear/sparkles, sticky header — v1.1 (Phase 8)
- [ ] Floating map buttons: компас, транспорт, локация (правый вертикальный стек)
- [ ] Sheet контент: структура как в Apple Maps (транспорт, места, недавние)

### Deferred

- [ ] Комбинированные маршруты (метро + пешком) в одном маршруте
- [ ] Lane guidance (подсказки полос) где доступно
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

## Current Milestone: v1.1 Apple Maps UI Parity

**Goal:** Точное воспроизведение UI карты Apple Maps — bottom sheet, search pill, floating buttons, контент sheet.

**Target features:**
- Bottom sheet с 3 detent states идентичный Apple Maps
- Search pill с drag handle, стиль и пропорции Apple Maps
- Floating map buttons (компас, транспорт, локация) как в Apple Maps
- Sheet контент (транспорт рядом, места, недавние) в стиле Apple Maps
- Визуальная полировка: фоны, скругления, тени, отступы

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-21 after Phase 8 (Search Bar + Handle) completion*
