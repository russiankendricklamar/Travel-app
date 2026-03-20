---
phase: quick
plan: 260321-4vl
subsystem: map-place-detail
tags: [ui, glassmorphism, ai, map, swiftui]
dependency_graph:
  requires: []
  provides: [rich-place-detail-card]
  affects: [MapPlaceDetailContent, MapViewModel]
tech_stack:
  added: []
  patterns: [ultraThinMaterial glass, gradient placeholder, lazy AI fetch via .task]
key_files:
  modified:
    - Travel app/Views/Map/MapPlaceDetailContent.swift
    - Travel app/Views/Map/MapViewModel.swift
decisions:
  - heroSection converted from computed var to func(categoryIcon:) to accept parameter
  - Used Place.day?.cityName (not dayPlan) per actual SwiftData model shape
  - AI description skipped for .aiResultDetail mode (already has rec.description)
  - PlaceInfo.Section uses .text property (not .content as plan mentioned)
metrics:
  duration: ~15 minutes
  completed: 2026-03-21
  tasks_completed: 2
  files_modified: 2
---

# Quick Task 260321-4vl: Rich Place Detail Card on Map with Photo

**One-liner:** Glassmorphism action buttons, 84pt photo thumbnails, gradient category-icon placeholder hero, and lazy-loaded AI description card in the map place detail sheet.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Glass buttons + bigger thumbnails + gradient placeholder hero | 459c4ee |
| 2 | Lazy AI description section inline in card | 9a70e97 |

## Changes Made

### MapPlaceDetailContent.swift (826 -> 922 lines)

**Task 1 — Visual upgrades:**
- `heroSection` converted from `private var` to `private func heroSection(categoryIcon: String)` — accepts category icon name as parameter to render in placeholder
- New `else` branch in hero: `LinearGradient` (sakuraPink 15%→5%, topLeading→bottomTrailing) at height 160 with category `Image(systemName:)` at 36pt + "Нет фото" label — shows when no LookAround and no Google photos
- Photo thumbnails: `56x56` → `84x84`, `cornerRadius: 8` → `cornerRadius: 10`
- `circularButton`: unfilled now uses `Circle().fill(.ultraThinMaterial)` + `Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5)` overlay; size `44` → `48`; filled keeps solid color fill

**Task 2 — AI description:**
- New `aiDescriptionSection(name:categoryIconName:)` `@ViewBuilder` method
- Loading state: `ProgressView` + "AI описание..." text
- Result state: glass card (`ultraThinMaterial` + sakuraPink 0.15 stroke) with `sparkles` icon + "AI" tracking label + description text (14pt secondary)
- `.task(id: name)` modifier drives lazy loading — re-fetches if place name changes
- Skips display entirely when `vm.sheetContent == .aiResultDetail`
- Inserted between `quickStatusRow` and `actionButtons` in `unifiedDetailContent`

### MapViewModel.swift (945 -> 974 lines)

- Two new state properties: `var inlineAIDescription: String?` and `var isLoadingAIDescription = false`
- `loadInlineAIDescription(name:category:city:)` async method: calls `PlaceInfoService.shared.fetchInfo`, takes `firstSection.text`, truncates to 250 chars + "..."
- Guard prevents double-loading: `guard inlineAIDescription == nil, !isLoadingAIDescription`
- Reset calls added to: `onPlaceSelected()`, `selectSearchResult()`, `selectAIResult()`, `clearSelection()`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wrong property name for city lookup**
- **Found during:** Task 2 implementation
- **Issue:** Plan referenced `vm.selectedPlace?.dayPlan?.cityName` but `Place` model has `var day: TripDay?` not `dayPlan`
- **Fix:** Changed to `vm.selectedPlace?.day?.cityName`
- **Files modified:** MapPlaceDetailContent.swift

**2. [Rule 1 - Bug] PlaceInfo.Section uses .text not .content**
- **Found during:** Task 2 implementation
- **Issue:** Plan referenced `firstSection.content` but the struct property is named `text`
- **Fix:** Used `firstSection.text` in `loadInlineAIDescription`
- **Files modified:** MapViewModel.swift

## Self-Check: PASSED

- `/Users/egorgalkin/Travel app/Travel app/Views/Map/MapPlaceDetailContent.swift` — exists, 922 lines
- `/Users/egorgalkin/Travel app/Travel app/Views/Map/MapViewModel.swift` — exists, 974 lines
- Commit 459c4ee — verified in git log
- Commit 9a70e97 — verified in git log
- Build: ** BUILD SUCCEEDED **
