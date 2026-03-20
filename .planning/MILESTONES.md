# Milestones

## v1.0 Map Navigation Overhaul (Shipped: 2026-03-21)

**Phases completed:** 6 phases, 12 plans
**Timeline:** 21 days (2026-02-28 → 2026-03-21)
**Commits:** 83
**Lines changed:** +2,880 / -523
**Total codebase:** 44,806 LOC Swift

**Delivered:** Полная turn-by-turn навигация с голосовыми подсказками, мультимодальными маршрутами, и офлайн кэшированием — путешественник ориентируется в чужой стране без интернета.

**Key accomplishments:**

1. Turn-by-turn navigation engine с step tracking, off-route detection (>30m), auto-rerouting (8s debounce)
2. Voice guidance через AVSpeechSynthesizer с distance-triggered announcements (500m/200m/arrival)
3. Glassmorphism NavigationHUD с heading-locked camera и collapsible bottom sheet
4. Multi-route alternatives (2-3 варианта) с transport mode switching и parallel ETA display
5. Two-tier offline route caching (L1 memory + L2 SwiftData) с "Подготовить офлайн" pre-cache
6. Graceful offline degradation с cache-first lookup и clear user messaging

**Git range:** `8e881fd` → `dccd0bc`
**Tag:** v1.0
**Archive:** `milestones/v1.0-ROADMAP.md`, `milestones/v1.0-REQUIREMENTS.md`

---
