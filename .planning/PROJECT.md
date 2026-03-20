# Travel App — Map Navigation Overhaul

## What This Is

Полная переработка навигационной механики в Travel app — iOS приложении для планирования путешествий. Улучшаем существующую карту до уровня Apple Maps: мультимодальные маршруты, полная turn-by-turn навигация с голосовыми подсказками, современный UI с bottom sheet и floating search, полный офлайн с предзагрузкой карт.

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
- ✓ Turn-by-turn навигация с отслеживанием положения — Validated in Phase 1: Navigation Engine
- ✓ Голосовые подсказки через AVSpeechSynthesizer (500м/200м/прибытие) — Validated in Phase 1
- ✓ Пошаговые инструкции поворотов (NavigationStep модель) — Validated in Phase 1
- ✓ Автоматическое перестроение маршрута при отклонении (30м + 8с debounce) — Validated in Phase 1
- ✓ Фоновый GPS при заблокированном экране — Validated in Phase 1
- ✓ Floating HUD с иконкой манёвра, инструкцией и расстоянием — Validated in Phase 2: Navigation UI
- ✓ Старт/стоп навигации из карточки маршрута — Validated in Phase 2
- ✓ Камера следует за пользователем с heading lock — Validated in Phase 2
- ✓ Bottom sheet в навигационном режиме (peek + expanded step list) — Validated in Phase 2
- ✓ Контекст поездки "День N из M" во время навигации — Validated in Phase 2

### Active

- [ ] Построение маршрутов через MKDirections с несколькими вариантами (2-3 альтернативы)
- [ ] Мультимодальные маршруты (пешком, авто, транспорт) с переключением
- [ ] ETA и расстояние на каждом варианте маршрута
- [ ] Комбинированные маршруты (метро + пешком) в одном маршруте
- [ ] Lane guidance (подсказки полос) где доступно
- [x] Apple Maps UI: выдвижной bottom sheet с detents (.small, .medium, .large) — Validated in Phase 2
- [ ] Floating search bar поверх карты
- [ ] Карточки мест в стиле Apple Maps
- [ ] Полный офлайн: предзагрузка карт региона (MKTileOverlay или MapKit offline)
- [ ] Офлайн маршрутизация по закэшированным данным
- [ ] Live Activity при активной навигации (Dynamic Island)

### Out of Scope

- AR-навигация — отдельный scope, не связан с картами
- Свой рендеринг карт (MapLibre/Mapbox) — используем нативный MapKit
- Навигация для грузовиков/мотоциклов — только пешком, авто, транспорт
- Платные дороги / избегание автомагистралей — Apple Maps не даёт этого через MKDirections
- Свой собственный TTS движок — системный AVSpeechSynthesizer достаточен

## Context

- Существующий MapViewModel и Map views нужно улучшить, не переписывать с нуля
- Текущие файлы карты: MapViewModel.swift, TripMapView.swift, MapBottomSheet.swift, MapFloatingSearchPill.swift, MapPinViews.swift, MapPlaceDetailContent.swift, MapRouteContent.swift, MapSearchContent.swift, MapTransportOverlays.swift
- RoutingService.swift уже существует с базовой маршрутизацией
- Приложение работает на Swift/SwiftUI с @Observable pattern
- Glassmorphism дизайн-система (blur + semi-transparent + gradients)
- Русскоязычный интерфейс
- iOS 17+ minimum target

## Constraints

- **Platform**: iOS only, MapKit only (no third-party map SDKs)
- **Offline**: MKMapSnapshotter для тайлов; Apple не предоставляет офлайн routing API напрямую — потребуется кэширование предпостроенных маршрутов
- **Voice**: AVSpeechSynthesizer — системный, бесплатный, поддерживает все языки iOS
- **Design**: Glassmorphism стиль приложения должен сохраняться в новых компонентах карты
- **Architecture**: @Observable pattern, SwiftData для persistence

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| MapKit вместо Mapbox/MapLibre | Нативная интеграция, бесплатно, Apple Maps стиль из коробки | — Pending |
| AVSpeechSynthesizer для голоса | Бесплатный, офлайн, все языки iOS | — Pending |
| Улучшение а не переписывание | Сохраняем рабочий функционал, меньше риск регрессий | — Pending |
| Кэш маршрутов для офлайн | Apple не даёт офлайн routing, кэшируем построенные маршруты | — Pending |

---
## Current State

Phase 2 (Navigation UI) complete — NavigationHUDView (glassmorphism HUD), MapRecenterButton, NavigationSheetContent (peek/expanded), кнопка "Начать навигацию" в MapRouteContent. Всё интегрировано в TripMapView с heading-lock камерой, dismiss guard, и pan detection.

*Last updated: 2026-03-20 after Phase 2 completion*
