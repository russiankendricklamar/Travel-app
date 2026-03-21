---
phase: quick
plan: 260321-m0i
subsystem: map-ui
tags: [search-pill, layout, dimensions, map-bottom-sheet]
key-files:
  modified:
    - Travel app/Views/Map/MapBottomSheet.swift
    - Travel app/Views/Map/MapSearchContent.swift
    - Travel app/Views/Map/FloatingControlsOverlay.swift
decisions:
  - Solid black Color.black fill (not ultraThinMaterial) for peek pill background — matches reference screenshot
  - 257pt maxWidth chosen to match Apple Maps-style centered pill proportions
  - 72pt bottom clearance in FloatingControlsOverlay ensures controls do not overlap the pill
metrics:
  duration: "5 min"
  completed: "2026-03-21"
  tasks_completed: 2
  files_modified: 3
---

# Quick Task 260321-m0i: Match Search Pill Layout to Reference Summary

**One-liner:** Verified and committed 257x36pt solid black search pill centered 28pt above tab bar, with 72pt floating controls clearance.

## What Was Done

Verified that uncommitted changes in three map view files already contained correct dimensions matching the reference screenshot. Built the project to confirm zero compilation errors, then committed all three files atomically.

## Dimensions Confirmed

### MapBottomSheet.swift

| Property | Value | Location |
|----------|-------|----------|
| Peek height | 36pt | `SheetDetent.height()` case `.peek` |
| Max width in peek | 257pt | `.frame(maxWidth: isPeek ? 257 : .infinity)` |
| Bottom padding in peek | 28pt | `.padding(.bottom, isPeek ? 28 : 0)` |
| Peek background | `Color.black` solid fill | `UnevenRoundedRectangle.fill(Color.black)` |
| Shadow | `black.opacity(0.28), radius: 30` | Peek layer only |

### MapSearchContent.swift

| Property | Value | Location |
|----------|-------|----------|
| HStack spacing (peek) | 6pt | `HStack(spacing: vm.sheetDetent == .peek ? 6 : 0)` |
| Magnifying glass size (peek) | 15pt | `.font(.system(size: vm.sheetDetent == .peek ? 15 : 17))` |
| Icon color | `Color.white.opacity(0.6)` | `.foregroundStyle(vm.sheetDetent == .peek ? Color.white.opacity(0.6) : .secondary)` |
| "Поиск" text size | 17pt | `.font(.system(size: 17, weight: .regular))` |
| Text color | `Color.white.opacity(0.6)` | `.foregroundStyle(Color.white.opacity(0.6))` |
| Vertical padding (peek) | 9pt | `.padding(.vertical, vm.sheetDetent == .peek ? 9 : 8)` |

### FloatingControlsOverlay.swift

| Property | Value | Location |
|----------|-------|----------|
| Bottom padding | 72pt | `.padding(.bottom, 72)` |

## Build Result

`** BUILD SUCCEEDED **` — no compilation errors or warnings.

## Commit

`9b493a4` — feat(map): match search pill layout to reference — 257pt wide, 36pt peek, 28pt above tab bar, solid black capsule

## Deviations from Plan

None — plan executed exactly as written. All dimensions were already in place in the uncommitted changes.

## Self-Check: PASSED

- MapBottomSheet.swift exists and contains all required values
- MapSearchContent.swift exists and contains all required values
- FloatingControlsOverlay.swift exists and contains all required values
- Commit 9b493a4 exists in git log
- Build succeeded with no errors
