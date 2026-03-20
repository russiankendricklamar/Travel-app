# Retrospective

## Milestone: v1.0 — Map Navigation Overhaul

**Shipped:** 2026-03-21
**Phases:** 6 | **Plans:** 12

### What Was Built

1. NavigationEngine state machine with step tracking, off-route detection (>30m), auto-rerouting (8s debounce)
2. NavigationVoiceService with AVSpeechSynthesizer distance-triggered announcements (500m/200m/arrival)
3. NavigationHUDView glassmorphism floating card with heading-locked camera
4. RouteAlternativeCard carousel with 2-3 alternatives, transport mode switching, parallel ETA
5. Two-tier offline cache (L1 memory + L2 SwiftData CachedRoute @Model)
6. Graceful offline degradation with cache-first lookup and user messaging

### What Worked

- **Pure logic first (Phase 1)** — building NavigationEngine without UI produced a stable API that Phase 2 consumed without changes
- **Dependency chain** — phases 1→2, 1→3, 1+3→4 kept scope clean and testable
- **Gap closure phases (5, 6)** — milestone audit caught two integration bugs before shipping
- **Audit-driven quality** — re-audit confirmed 18/18 requirements after gap closure

### What Was Inefficient

- Phases 5 and 6 were gap closures that could have been caught during Phase 4 integration
- VERIFICATION.md missing for Phases 5 and 6 (non-blocking but noted as tech debt)
- Some print() debug statements left in RoutingService (3 sites)

### Patterns Established

- `@Observable` + SwiftData `@Model` coexistence pattern for RoutingService
- L1/L2 cache pattern (memory + SwiftData) for offline-first features
- Place-UUID overloads for cache-addressable routing
- NavigationEngine as pure state machine (no UI dependencies)

### Key Lessons

- Always test offline paths during phase integration, not just at milestone audit
- `modelContext` injection timing matters in SwiftUI — `.onAppear` is the earliest safe point
- MKDirections cycling → walking mapping is acceptable but should be documented

### Cost Observations

- Sessions: ~3 focused sessions over 21 days
- Model mix: primarily opus for planning, sonnet for execution
- Notable: gap closure phases (5, 6) added minimal code but closed critical offline path

---

## Cross-Milestone Trends

| Metric | v1.0 |
|--------|------|
| Phases | 6 |
| Plans | 12 |
| Commits | 83 |
| Lines changed | +2,880 / -523 |
| Gap closure phases | 2 |
| Requirements satisfied | 18/18 |
