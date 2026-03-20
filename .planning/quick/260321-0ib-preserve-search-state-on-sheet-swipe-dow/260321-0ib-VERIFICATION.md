---
status: passed
score: 4/4
---

# Verification: 260321-0ib Preserve search state on sheet swipe-down

## Must-Haves Check

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Swipe-down during search does NOT reset searchQuery/searchResults | PASS | TripMapView.swift:232-237 — `hasActiveSearch` branch bounces to `.half`, never calls `dismissDetail()` |
| 2 | Swipe-down during detail DOES reset | PASS | TripMapView.swift:239-241 — `isInDetailMode` branch calls `dismissDetail()` |
| 3 | Sheet bounces to .half when search is active | PASS | TripMapView.swift:235-237 — `withAnimation(.spring) { vm.sheetDetent = .half }` |
| 4 | Cancel button fully resets search | PASS | MapViewModel.swift:441-452 — `dismissSearch()` clears all state, sets `.peek`/`.idle` |

## Build Status

BUILD SUCCEEDED

## Human Verification Items

- [ ] Type search query, swipe sheet down → results persist, sheet stays at half
- [ ] Tap search result to see detail, swipe down → detail dismisses, returns to idle
- [ ] Type query, swipe down, swipe up → results still visible
- [ ] Tap "Отмена" → everything resets to idle/peek
- [ ] During navigation, swipe sheet → navigation persists (existing guard)
