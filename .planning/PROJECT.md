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

### Active

- [ ] Построение маршрутов через MKDirections с несколькими вариантами (2-3 альтернативы)
- [ ] Мультимодальные маршруты (пешком, авто, транспорт) с переключением
- [ ] ETA и расстояние на каждом варианте маршрута
- [ ] Комбинированные маршруты (метро + пешком) в одном маршруте
- [ ] Полная turn-by-turn навигация с отслеживанием положения
- [ ] Голосовые подсказки через системный TTS (AVSpeechSynthesizer, язык устройства)
- [ ] Пошаговые инструкции поворотов с иконками направлений
- [ ] Автоматическое перестроение маршрута при отклонении
- [ ] Lane guidance (подсказки полос) где доступно
- [ ] Apple Maps UI: выдвижной bottom sheet с detents (.small, .medium, .large)
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
*Last updated: 2026-03-20 after initialization*
