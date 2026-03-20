# Architecture Patterns: Apple Maps UI Parity

**Domain:** iOS SwiftUI — MapKit bottom sheet, floating controls, search pill
**Researched:** 2026-03-21
**Confidence:** HIGH (based on deep existing codebase analysis + iOS platform constraints)

---

## What This Covers

This document supersedes the v1.0 navigation overhaul architecture. It focuses specifically on the v1.1 Apple Maps UI Parity milestone — restructuring the existing sheet, search bar, floating controls, and content sections to visually match Apple Maps.

The navigation engine, routing, offline caching, and voice services are **already complete** (v1.0). This milestone is UI-only.

---

## Current Component Inventory

| File | Current State | Action |
|------|--------------|--------|
| `MapBottomSheet.swift` | Custom draggable sheet, peek=50pt pill, half/full as opaque dark sheet | Restructure |
| `MapSearchContent.swift` | Search + chips + today's places + map controls, all in one file | Split or refactor |
| `TripMapView.swift` | ZStack root: map + HUD + sheet; owns `isSearchFocused: FocusState` | Extend (floating controls layer) |
| `MapViewModel.swift` | 974 lines, `sheetDetent: SheetDetent`, `sheetContent: MapSheetContent` | Add new state properties |
| `MapFloatingSearchPill.swift` | Unused idle-state button (`.ultraThinMaterial`, `.plain` style) | Remove or integrate |
| `MapPlaceDetailContent.swift` | Place detail card in sheet | No change needed |
| `MapRouteContent.swift` | Route info panel | No change needed |
| `NavigationSheetContent.swift` | Navigation mode sheet | No change needed |

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     TripMapView (ZStack)                     │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: Map (MapKit / offline gallery / radar)             │
│  Layer 2: NavigationHUD (floats top, visible when nav)       │
│  Layer 3: FloatingMapControls (right rail, idle only)  [NEW] │
│  Layer 4: MapBottomSheet (always present)                    │
│             └── SheetBody router:                            │
│                   .idle / .searchResults → MapSearchContent  │
│                   .placeDetail / etc → MapPlaceDetailContent  │
│                   .routeInfo → MapRouteContent               │
│                   .navigation → NavigationSheetContent       │
└─────────────────────────────────────────────────────────────┘
```

---

## Component Boundaries (What Changes in Which File)

### MapBottomSheet.swift — The Visual Shape Problem

**The core challenge:** Apple Maps has two completely different visual states for the same logical component:

- **Peek:** A floating pill — rounded on all sides, ~120pt tall, dark blur, horizontal padding (not touching screen edges), drag handle hidden, sheet floats above the map with clear air on all sides.
- **Half/Full:** A full-width bottom sheet — only top corners rounded, extends to screen edges, opaque dark background, drag handle visible at top.

**Current problem:** The existing code uses a single `RoundedRectangle` / `UnevenRoundedRectangle` and `padding(.horizontal, 16)` in peek mode. The transition between these two shapes is missing — it snaps rather than morphing.

**Recommended approach:** Keep the single `MapBottomSheet` component but use `interpolatingSpring` or a geometry-driven interpolation to morph the shape properties:

```swift
// In MapBottomSheet.body:
let isPeek = detent == .peek && dragOffset == 0
let cornerRadius: CGFloat = isPeek ? 22 : 30
let hPadding: CGFloat = isPeek ? 16 : 0
let backgroundOpacity: Double = isPeek ? 0.75 : 1.0
```

The `.background` modifier switches between a `RoundedRectangle` (all corners, for peek) and `UnevenRoundedRectangle` (top only, for half/full). This is already in the code. The issue is the background animates but the padding does not — add an `.animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPeek)` to the padding modifier itself.

**Drag handle:** Already conditionally hidden in peek. Keep this. In Apple Maps, the drag handle appears inside the sheet in half/full mode — this is already correct.

**Peek height:** Currently 50pt. Apple Maps peek is approximately 110-120pt — tall enough to show the search bar, drag handle area, and a hint of category chips. Change `case .peek: return 120` in `SheetDetent.height(in:)`.

**Responsibility of this file after changes:**
- Shape interpolation (pill vs. sheet)
- Background material (blur in peek, opaque in half/full)
- Drag gesture + snap logic
- No content awareness

### MapSearchContent.swift — Search Bar Architecture

**Same component, different rendering per detent.** Apple Maps does not swap the search bar component between states — the same bar is used in all states, but it renders differently:

- **Peek:** Search field acts as a tappable button (no cursor). Single-line, compact padding. No cancel button. Drag handle is outside to the left of the bar (but in this implementation, the drag handle is above — keep that).
- **Half/Full (idle):** Real `TextField`, keyboard appears. Cancel button slides in from trailing edge. Category chips visible below.
- **Full (focused):** Same as half but keyboard is up, chips shift to scroll view.

**Current code already handles this** via the `if vm.sheetDetent == .peek && !isSearchFocused` conditional in `searchFieldContent`. This is the right pattern. The refactor needed:

1. Remove the `.ultraThinMaterial` capsule background when in peek (the outer sheet IS the pill background already).
2. The "Отмена" button logic (`if isSearchFocused || !vm.searchQuery.isEmpty`) is correct — keep it.
3. `@FocusState.Binding var isSearchFocused` threading from TripMapView is correct — keep it.

**Text field focus management:** When sheet transitions from peek to half/full via drag (not tap), the text field should NOT auto-focus. Auto-focus only happens on tap of the peek search bar. This is already handled by `DispatchQueue.main.asyncAfter` + `isSearchFocused = true` in the tap handler.

**Responsibility of this file after changes:**
- Search bar rendering (peek placeholder vs. real TextField)
- Cancel button conditional
- Category chips (focus-only)
- Typeahead completer results
- Today's places section
- Map controls section (layers, precipitation, discover, zoom)

### FloatingMapControls — New Component

**Apple Maps has a right-side vertical stack:** compass, transit, location button. Currently the app has:
- Location button inline in TripMapView's ZStack (65 lines, hard to maintain)
- Compass and scale rendered via `mapControls { MapScaleView(); MapCompass() }` (system-provided, bottom-left)
- No transit toggle button

**Recommendation: Extract to `MapFloatingControls.swift`** (rename/repurpose `MapFloatingSearchPill.swift` or create new file).

```
MapFloatingControls
  ├── Compass button (or keep system MapCompass, reposition)
  ├── Location button (extracted from TripMapView)
  └── Recenter button (currently inline in TripMapView, move here)
```

Visibility rules:
- Entire stack: hide when navigating (navigation has its own recenter button)
- Location button: show when `isIdleMode`
- Recenter button: show when `isNavigating && isOffNavCenter`

The existing `MapRecenterButton` component can be reused inside `MapFloatingControls`.

**Position:** Right edge, above the peek sheet. Use `padding(.trailing, 16)` and `padding(.bottom, peekHeight + 16)` where `peekHeight` is read from the environment or passed as a parameter.

**Z-ordering:** In the TripMapView ZStack, this layer should be above the map but below the sheet. The sheet already sits at the bottom of the ZStack. Controls sit between map and sheet.

**Responsibility of this file:**
- Location button
- Recenter button (replaces inline version in TripMapView)
- Animated show/hide based on `vm.isNavigating` and `vm.isIdleMode`

### TripMapView.swift — Simplification

Current TripMapView has inline VStack/HStack blocks for several floating controls. Extract these:

**Remove from TripMapView (move to MapFloatingControls):**
- Location button block (~20 lines, currently lines 150-181)
- Recenter button block (~10 lines, currently lines 138-147)

**Keep in TripMapView:**
- Map layer switch (offline/radar/live map)
- NavigationHUD overlay
- Precipitation label overlay
- Offline cache indicator (the green checkmark)
- MapBottomSheet
- All `.sheet()`, `.fullScreenCover()`, `.task()`, `.onChange()` modifiers

**`isIdleMode` computed property:** Keep. Used to drive tab bar visibility and floating controls.

**Responsibility of this file after changes:**
- ZStack layer assembly
- Map state (offline vs. live vs. radar)
- Task orchestration (location, camera, transport overlays)
- Sheet/cover presentation

### MapViewModel.swift — New State Properties

Currently 974 lines. The following additions are needed:

```swift
// Floating controls visibility
var showFloatingControls: Bool {
    !isNavigating && sheetDetent == .peek
}

// Sheet background interpolation helper
var sheetBackgroundProgress: Double {
    // 0.0 = full peek (pill), 1.0 = half/full (opaque sheet)
    sheetDetent == .peek ? 0.0 : 1.0
}
```

No structural changes to `MapSheetContent` enum or `SheetDetent` enum are needed.

`SheetDetent.peek.height(in:)` changes from 50 to 120 — this is the only model change.

---

## Data Flow

### Sheet State Machine (unchanged)

```
User interaction
    → MapViewModel.sheetDetent: SheetDetent (enum)
    → MapViewModel.sheetContent: MapSheetContent (enum)
    → MapBottomSheet reads detent → renders shape + height
    → TripMapView.sheetBody routes to correct content view
    → MapSearchContent / MapPlaceDetailContent / etc
```

### Floating Controls ↔ Sheet State

```
vm.sheetDetent == .peek && !vm.isNavigating
    → MapFloatingControls visible (location + optional recenter)
    → Tab bar visible (TripMapView.isIdleMode)

vm.sheetDetent == .half or .full
    → MapFloatingControls hidden (sheet covers right rail)
    → Tab bar hidden

vm.isNavigating
    → MapFloatingControls hidden
    → NavigationHUD shown
    → MapRecenterButton shown when vm.isOffNavCenter (inside FloatingControls or NavigationHUD area)
```

### Search Focus Flow

```
User taps peek search bar
    → vm.sheetDetent = .full (withAnimation)
    → DispatchQueue.main.asyncAfter(0.15) { isSearchFocused = true }

User drags sheet to peek
    → onChange(of: vm.sheetDetent) fires
    → if hasActiveSearch: bounce to .half (search stays)
    → if no search: vm.dismissDetail()

User taps "Отмена"
    → vm.dismissSearch()
    → isSearchFocused = false
    → vm.sheetDetent = .peek (inside dismissSearch)
```

### Key Data Flows

1. **Detent changes drive visual shape:** `MapBottomSheet` reads `detent` binding, computes height, applies spring animation. Content is agnostic to shape.
2. **Content changes drive detent:** `MapViewModel` state machine methods (`onPlaceSelected()`, `selectSearchResult()`, etc.) call `withAnimation { sheetDetent = .half }`. This is the existing pattern — keep it.
3. **Focus state crosses two files:** `isSearchFocused: FocusState` lives in `TripMapView`, passed as `$isSearchFocused` to `MapSearchContent`. This is correct (FocusState must live in the view that owns the layout).

---

## Suggested Build Order

Dependencies determine this order. Each step is independently testable.

### Step 1: Fix peek height and shape (MapBottomSheet.swift)
**Why first:** All other visual changes depend on the correct peek geometry.
- Change `case .peek: return 120` in `SheetDetent.height(in:)`
- Add horizontal padding animation to `MapBottomSheet.body`
- Verify: peek shows full search bar, half/full extends edge-to-edge
- Risk: none — isolated to one file

### Step 2: Search bar visual polish (MapSearchContent.swift)
**Why second:** Depends on correct peek height being established in Step 1.
- Remove inner capsule background when `vm.sheetDetent == .peek`
- Adjust padding to `vm.sheetDetent == .peek ? 6 : 10` for vertical padding
- Verify: search bar sits flush in the pill, inner capsule appears only in half/full
- Risk: low — styling only

### Step 3: Extract FloatingMapControls (new file + TripMapView.swift)
**Why third:** Independent of sheet changes, but should be done before sheet content restructuring.
- Create `MapFloatingControls.swift`
- Move location button and recenter button from TripMapView into it
- Wire `vm.isNavigating` and `vm.isIdleMode` for show/hide
- Remove extracted blocks from TripMapView
- Risk: medium — touches TripMapView which has complex state; test all interactive paths

### Step 4: Sheet content sections (MapSearchContent.swift)
**Why fourth:** Build on top of the polished search bar from Step 2.
- Verify category chips, today's places, and map controls are correctly gated behind `isSearchFocused`
- Polish section headers to match Apple Maps style (small caps, secondary color)
- Risk: low — these sections are already implemented; this is refinement

### Step 5: Visual polish pass (all map files)
**Why last:** All structural changes are done; this is cosmetic.
- Verify background colors, corner radii, shadows match target
- Verify animations are spring-based and feel correct
- Verify tab bar hide/show transitions are smooth

---

## What to Keep vs. What to Rewrite

| Component | Keep | Rewrite/Extract | Reason |
|-----------|------|-----------------|--------|
| `MapBottomSheet.swift` | Drag gesture, spring snap logic, detent enum | Peek height (50→120), padding animation | Gesture logic is correct; only geometry needs tuning |
| `MapSearchContent.swift` | All content sections, focus management, cancel button | Remove inner capsule in peek | Content is correct; only styling wrong in peek |
| `TripMapView.swift` | ZStack assembly, task modifiers, onChange handlers | Extract location + recenter buttons | Reduce inline VStack complexity |
| `MapViewModel.swift` | All state, all methods | `sheetDetent.peek` height value | 974 lines are correctly structured; no rewrite needed |
| `MapFloatingSearchPill.swift` | Nothing | Entire file → rename to `MapFloatingControls.swift` | Current file is a standalone button that was never integrated |
| `MapRecenterButton.swift` | Component as-is | Usage site (move into FloatingControls) | Component is fine; its host changes |

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Separate peek overlay + sheet component

**What people do:** Create a separate floating pill view for peek and a separate bottom sheet for half/full. Toggle between them with `.transition`.

**Why it's wrong:** The drag gesture must be continuous across the three states. Swapping components resets gesture recognizers and creates a pop at the transition boundary. Apple Maps uses one physical component that morphs.

**Do this instead:** Single `MapBottomSheet` that changes its background shape and padding based on `detent`. The current code is already correct in this regard.

### Anti-Pattern 2: Reading sheet height from environment

**What people do:** Sheet content tries to read its own height to position elements.

**Why it's wrong:** Creates layout cycles. GeometryReader inside the sheet fights with the sheet's own GeometryReader.

**Do this instead:** Pass peek height as a constant to floating controls (`let peekHeight: CGFloat = 136` — peek height + safe area bottom). Don't read it dynamically.

### Anti-Pattern 3: Animating `isSearchFocused` directly

**What people do:** Set `isSearchFocused = true` synchronously when the sheet starts animating to full.

**Why it's wrong:** The keyboard appears before the sheet animation completes, causing a visual collision.

**Do this instead:** `DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isSearchFocused = true }`. The current code already does this — keep the delay.

### Anti-Pattern 4: Using `.sheet()` for the map bottom sheet

**What people do:** Use SwiftUI's built-in `.sheet()` or `.presentationDetents()` for the map bottom sheet.

**Why it's wrong:** SwiftUI's system sheet has a white/system background that cannot be changed to the dark opaque color. `UISheetPresentationController` requires bridging and breaks @Observable pattern. The glassmorphism blur in peek mode is impossible with system sheets.

**Do this instead:** The existing custom `MapBottomSheet` with GeometryReader + DragGesture. Keep it.

### Anti-Pattern 5: Hiding all floating controls during any search

**What people do:** Hide the right-rail controls whenever `sheetDetent != .peek`.

**Why it's wrong:** The location button is useful when sheet is at half (user wants to re-center while browsing results).

**Do this instead:** Hide floating controls only when `sheetDetent == .full` (keyboard likely up, controls obscured). At `.half`, keep the location button visible, positioned above the half-sheet.

---

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|--------------|-------|
| `TripMapView` ↔ `MapBottomSheet` | `@Binding var detent: SheetDetent` | No content coupling; sheet is layout-only |
| `TripMapView` ↔ `MapSearchContent` | `@Bindable var vm: MapViewModel` + `@FocusState.Binding` | FocusState must live in TripMapView |
| `MapViewModel` ↔ all content views | `@Bindable var vm: MapViewModel` | Single source of truth; @Observable pattern |
| `MapFloatingControls` ↔ `TripMapView` | `@Bindable var vm: MapViewModel` | Reads `isNavigating`, `isOffNavCenter`, `isIdleMode` |
| `MapFloatingControls` ↔ `MapRecenterButton` | Composition (MapRecenterButton embedded inside) | Avoids duplicating visibility logic |

---

## Roadmap Implications for Phase Structure

Given the dependency analysis, the Apple Maps UI Parity milestone maps cleanly to this phase ordering:

1. **Sheet geometry (peek height + shape morphing)** — all other visual work depends on correct geometry
2. **Search bar polish** — depends on correct peek height so the search bar fits naturally
3. **Floating controls extraction** — independent track, can be parallelized with Step 2
4. **Content sections polish** — final pass once layout is stable
5. **Visual integration pass** — animations, timing, color verification

**Files touched per phase:**

| Step | Primary File | Secondary Files |
|------|-------------|-----------------|
| 1 — Sheet geometry | `MapBottomSheet.swift` | None |
| 2 — Search bar | `MapSearchContent.swift` | None |
| 3 — Floating controls | `MapFloatingControls.swift` (new) | `TripMapView.swift` |
| 4 — Content sections | `MapSearchContent.swift` | `MapViewModel.swift` (minor) |
| 5 — Polish | All map files | None |

---

## Sources

- Codebase analysis: `MapBottomSheet.swift`, `MapSearchContent.swift`, `TripMapView.swift`, `MapViewModel.swift` (all read directly, 2026-03-21)
- Platform: SwiftUI GeometryReader, DragGesture, FocusState, @Observable — iOS 17+
- Visual reference: Apple Maps iOS 17/18 — peek pill with `ultraThinMaterial` blur, full-width opaque dark sheet for half/full
- Architecture confidence: HIGH — all decisions derived from existing code; no external sources needed

---
*Architecture research for: Apple Maps UI Parity — bottom sheet, search pill, floating controls*
*Researched: 2026-03-21*
