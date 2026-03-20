---
plan: 260321-0ib
status: complete
tasks_completed: 1
tasks_total: 1
---

# Quick Task 260321-0ib: Preserve search state on sheet swipe-down

## What Changed

**TripMapView.swift** — `onChange(of: vm.sheetDetent)` handler now has three-branch conditional logic:

1. **Detail mode** (placeDetail/searchItemDetail/aiResultDetail) → `dismissDetail()` as before
2. **Active search** (non-empty query, results, or completer suggestions) → bounce to `.half` instead of `.peek`, preserving all search state
3. **No search, no detail** → `dismissDetail()` as before

## Why

Previously, any swipe-down to peek unconditionally called `dismissDetail()` which cleared `searchQuery`, `searchResults`, `completerResults`, and reset `sheetContent` to `.idle`. This meant users lost their search results every time they minimized the sheet.

Apple Maps behavior: minimizing the sheet preserves search. Users can swipe back up to see results again. Only the "Cancel" button (Отмена) fully resets search state.

## Files Changed

| File | Change |
|------|--------|
| Travel app/Views/Map/TripMapView.swift | Conditional dismiss logic in onChange(of: sheetDetent) |
