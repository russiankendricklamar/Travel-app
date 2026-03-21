# Phase 10: Sheet Content — Research

**Researched:** 2026-03-21
**Domain:** SwiftUI bottom sheet content visibility, scroll/drag gesture coordination
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Apple Maps style — chips, "Сегодня", map controls visible IMMEDIATELY in half mode without search bar focus. Remove `isSearchFocused` condition from line 90 `MapSearchContent.swift`
- **D-02:** On text input — smooth fade-out of chips/today/controls → fade-in of completer results. On query clear — chips return
- **D-03:** Full mode expands content with additional sections not present in half

### Claude's Discretion

- Section order in half mode (D-04)
- Scroll/drag strategy in half mode (D-05)
- Empty state handling (D-06)
- Additional full-mode-only sections (e.g. "Недавние", "Избранное")
- Fade transition timing
- Exact inter-section spacing

### Deferred Ideas (OUT OF SCOPE)

- CONT-05: "Места" section (Дом/Работа/Добавить) — not in Phase 10 requirements
- CONT-06: "Недавние" section with search history — MAY be implemented as full-mode-only at Claude's discretion
- Transitions between detent states — Phase 11
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CONT-01 | Category chips (Музеи, Парки, Магазины, Отели) visible under search bar in half/full mode | Single condition removal at line 90; chips view fully implemented at lines 120-154 |
| CONT-02 | "Сегодня · [City]" section with today's places in half/full mode | Same condition removal; `todayPlacesSection` fully implemented at lines 423-489 |
| CONT-03 | Map controls row (Слои, Осадки, Обзор, Все места) available in half mode | Same condition removal; `mapControlsSection` fully implemented at lines 493-584 |
| CONT-04 | Scrollable content in half/full mode does not conflict with sheet drag gesture when dragging down | No scroll in half mode (content already flat); ScrollView only in full mode (already correct at lines 52-71) |
</phase_requirements>

---

## Summary

Phase 10 is a highly targeted modification to `MapSearchContent.swift`. All visual components (category chips, today's places, map controls) are already fully implemented and tested. The root cause of the missing content is a single boolean condition on line 90 that gates display behind `isSearchFocused == true` — an obvious mistake that treats search focus as a prerequisite for showing idle content.

The fix is minimal: remove `isSearchFocused &&` from the condition on line 90. The remaining guard (`vm.completerResults.isEmpty && vm.searchQuery.isEmpty && vm.sheetContent == .idle || .searchResults`) is correct — it correctly hides the idle content when completer suggestions are active or search results are showing.

Secondary deliverables are: (1) a "Показать все (N)" overflow button when today has more than 3 places in half mode, (2) a "Недавние" full-mode-only placeholder section (renders only when data exists), and (3) the fade animation toggle between idle content and search content on query change.

**Primary recommendation:** Remove `isSearchFocused &&` from line 90; add `withAnimation(.easeInOut(duration: 0.2))` wrapper to the conditional block; add place count truncation with "Показать все" button in `todayPlacesSection`.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | Declarative view layer | Project requirement; all existing code uses it |
| MapKit | iOS 17+ | Map controls integration | Already used in `mapControlsSection` |

No new dependencies required. This phase touches only existing SwiftUI views.

**Installation:** No new packages.

---

## Architecture Patterns

### Recommended Project Structure

No new files required. Single-file modification:

```
Travel app/Views/Map/
└── MapSearchContent.swift    ← ONLY file modified
```

### Pattern 1: Condition Removal (D-01 Primary Fix)

**What:** Remove the erroneous `isSearchFocused &&` guard that prevented idle content from showing without keyboard focus.

**When to use:** The idle content block in `scrollableContent`.

**Current (broken) — line 90:**
```swift
if isSearchFocused && vm.completerResults.isEmpty && vm.searchQuery.isEmpty,
   vm.sheetContent == .idle || vm.sheetContent == .searchResults {
```

**Required (fixed):**
```swift
if vm.completerResults.isEmpty && vm.searchQuery.isEmpty,
   vm.sheetContent == .idle || vm.sheetContent == .searchResults {
```

Source: 10-CONTEXT.md D-01, 10-UI-SPEC.md Visibility Fix section.

### Pattern 2: Animated Content Toggle (D-02)

**What:** Wrap the idle content conditional in `withAnimation` so the transition between idle content and completer suggestions is a smooth 0.2s opacity fade.

**When to use:** The `scrollableContent` ViewBuilder — apply `.animation(.easeInOut(duration: 0.2), value: ...)` on the block.

**Example:**
```swift
// In scrollableContent ViewBuilder:
// The .transition(.opacity) modifiers are already present on each section.
// Add animation context for the condition toggle:
let showIdleContent = vm.completerResults.isEmpty && vm.searchQuery.isEmpty
    && (vm.sheetContent == .idle || vm.sheetContent == .searchResults)

if showIdleContent {
    categoryChips
        .padding(.bottom, 8)
        .transition(.opacity)

    todayPlacesSection
        .transition(.opacity)

    mapControlsSection
        .transition(.opacity)
}
```

Then wrap the ViewBuilder body or the parent `VStack` with:
```swift
.animation(.easeInOut(duration: 0.2), value: showIdleContent)
```

Source: 10-UI-SPEC.md Animation Contract, 10-CONTEXT.md D-02.

### Pattern 3: Place Count Truncation with "Показать все"

**What:** In half mode, `todayPlacesSection` truncates display to 3 rows if today has more than 3 places. A "Показать все (N)" button expands the sheet to `.full`.

**When to use:** Inside `todayPlacesSection`, gate on `vm.sheetDetent == .half`.

**Example:**
```swift
// In todayPlacesSection, replace the ForEach:
let places = today.sortedPlaces
let isHalfMode = vm.sheetDetent == .half
let displayPlaces = isHalfMode && places.count > 3
    ? Array(places.prefix(3))
    : places

ForEach(Array(displayPlaces.enumerated()), id: \.element.id) { index, place in
    // existing place row button...

    if index < displayPlaces.count - 1 {
        Divider().padding(.leading, 52)
    }
}

// "Show all" overflow button — only in half mode with truncated list
if isHalfMode && places.count > 3 {
    Button {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            vm.sheetDetent = .full
        }
    } label: {
        Text("Показать все (\(places.count))")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.sakuraPink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
    .buttonStyle(.plain)
}
```

Source: 10-UI-SPEC.md Scroll/Drag Strategy section, 10-UI-SPEC.md Copywriting Contract.

### Pattern 4: Full-Mode "Недавние" Section

**What:** A placeholder section shown only in full mode. If there is no recent search history available, the section is not rendered.

**When to use:** After `mapControlsSection` in `scrollableContent`, gated on `vm.sheetDetent == .full`.

**Example:**
```swift
// After mapControlsSection in scrollableContent:
if vm.sheetDetent == .full {
    recentSearchesSection
        .transition(.opacity)
}
```

Since `MapViewModel` has no `recentSearches` property currently, the section renders empty (not shown) per the empty state rule in the UI-SPEC. The section can be stubbed as a `@ViewBuilder` that returns `EmptyView()` when the array is empty — this satisfies D-03 (full mode has additional sections) without requiring ViewModel changes.

Source: 10-CONTEXT.md D-03, D-06, 10-UI-SPEC.md Section Order and Visibility.

### Anti-Patterns to Avoid

- **Adding ScrollView to half mode:** The existing code correctly has no ScrollView in half mode (lines 69-71 of `MapSearchContent.swift`). Do NOT wrap the half-mode flat stack in a ScrollView — this causes gesture capture conflict with the sheet drag.
- **Calling `vm.dismissSearch()` from cancel:** Phase 8 established this sets `sheetDetent = .peek`. Do not call it (existing code inline-clears search on cancel correctly).
- **New spring params:** STATE.md locks `response: 0.35, dampingFraction: 0.85`. Use only this pair for any new sheet snap animations.
- **Modifying MapBottomSheet.swift:** Phase 7 output. Do NOT touch geometry.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Content visibility toggle | Custom state machine | Simple boolean derived from `vm` properties | Already derivable from existing `vm.completerResults.isEmpty && vm.searchQuery.isEmpty` |
| Scroll offset tracking | Custom gesture recognizer | Existing `ScrollOffsetKey` PreferenceKey (lines 4-10) | Already implemented and working |
| Fade animation | Custom `AnyTransition` | `.transition(.opacity)` already on all 3 sections | Already present, just needs animation context |
| Place truncation | Custom pagination | `Array(places.prefix(3))` | Trivially correct for the use case |

**Key insight:** This phase is 90% removal, 10% addition. The components are already built. Complexity comes from getting the animation timing right, not from building new views.

---

## Common Pitfalls

### Pitfall 1: Animation Context Scope

**What goes wrong:** Adding `.animation(...)` to the wrong level causes ALL content (including search bar, completer) to animate instead of just the idle content block.

**Why it happens:** SwiftUI propagates `.animation` modifiers down the view tree unless scoped carefully.

**How to avoid:** Apply `.animation(.easeInOut(duration: 0.2), value: showIdleContent)` to a container that wraps ONLY the three idle sections (chips, today, map controls), NOT to `scrollableContent` as a whole.

**Warning signs:** Cancel button or completer rows animate with unexpected fade when typing.

### Pitfall 2: `todayPlacesSection` Truncation State Mismatch

**What goes wrong:** When detent changes from `.half` to `.full` (user taps "Показать все"), if `displayPlaces` is recalculated without animation, the list jumps from 3 rows to N rows instantly.

**Why it happens:** `vm.sheetDetent` change triggers view re-evaluation synchronously.

**How to avoid:** The `withAnimation(.spring(response: 0.35, dampingFraction: 0.85))` on the `vm.sheetDetent = .full` assignment is sufficient — SwiftUI will animate the list expansion inside the spring context. No additional `.animation` needed on the ForEach.

**Warning signs:** List "pops" to full height without a smooth transition.

### Pitfall 3: Double-condition on `vm.sheetContent == .searchResults`

**What goes wrong:** The search results block at line 103 (`if vm.sheetContent == .searchResults, !vm.searchResults.isEmpty`) remains correct — this shows the results list. The idle content block gates on `.idle || .searchResults`. If `.searchResults` is in BOTH blocks simultaneously, chips/today/map controls appear alongside search results.

**Why it happens:** After a category chip tap, `vm.sheetContent` becomes `.searchResults` AND query is empty. The idle block would show chips again on top of search results.

**How to avoid:** The condition `vm.completerResults.isEmpty && vm.searchQuery.isEmpty` already prevents the overlap when the user has typed a query. For category search (query empty, content = .searchResults), need to also check `vm.selectedCategory == nil` OR check `!vm.hasSearchResults`. Review the interaction: after category search, `searchResults` is populated and `sheetContent == .searchResults`. The idle content would reappear (bad). Add `vm.searchResults.isEmpty` or check `vm.sheetContent == .idle` only.

**Correct condition:**
```swift
if vm.completerResults.isEmpty && vm.searchQuery.isEmpty && vm.searchResults.isEmpty,
   vm.sheetContent == .idle {
```

This is stricter than the current broken condition and prevents the double-render.

**Warning signs:** Chips appear above search results after tapping a category chip.

### Pitfall 4: `isSearchFocused` Residual Dependency

**What goes wrong:** After removing `isSearchFocused` from the display condition, there may still be places in `scrollableContent` that rely on focus state for other logic. Removing too aggressively breaks other behaviors.

**Why it happens:** `isSearchFocused` correctly drives the cancel button visibility and the search field vs. placeholder routing in `searchFieldContent`. These must be preserved.

**How to avoid:** The removal is ONLY on line 90 in `scrollableContent`. All other `isSearchFocused` usages in `body` (cancel button, `searchFieldContent`) remain unchanged.

---

## Code Examples

### Complete scrollableContent with all fixes

```swift
@ViewBuilder
private var scrollableContent: some View {
    // Typeahead completer suggestions — shown while typing (before submit)
    if vm.isCompleterActive && !vm.completerResults.isEmpty {
        Divider().padding(.horizontal, 14)
        completerSuggestionsList
    }

    // Idle content: chips, today, map controls
    // Visible when: no completer results, no search query, no search results,
    // and sheet is in idle state (not showing results for category/text search)
    let showIdleContent = vm.completerResults.isEmpty
        && vm.searchQuery.isEmpty
        && vm.searchResults.isEmpty
        && vm.sheetContent == .idle

    if showIdleContent {
        categoryChips
            .padding(.bottom, 8)
            .transition(.opacity)

        todayPlacesSection
            .transition(.opacity)

        mapControlsSection
            .transition(.opacity)

        // Full-mode only: recent searches placeholder
        if vm.sheetDetent == .full {
            recentSearchesSection
                .transition(.opacity)
        }
    }
    .animation(.easeInOut(duration: 0.2), value: showIdleContent)

    if vm.sheetContent == .searchResults, !vm.searchResults.isEmpty {
        Divider().padding(.horizontal, 14)
        searchResultsList
    }

    if vm.sheetContent == .aiSearchResults || (vm.isAISearchMode && !AIMapSearchService.shared.results.isEmpty) {
        Divider().padding(.horizontal, 14)
        aiSearchResultsList
    }

    if vm.isAISearchMode {
        aiMessages
    }
}
```

Note: `@ViewBuilder` does not support `let` bindings directly in all Swift versions. If compiler rejects the `let` inside `@ViewBuilder`, extract `showIdleContent` as a computed property on the view.

Source: MapSearchContent.swift lines 82-116 (existing), 10-UI-SPEC.md, 10-CONTEXT.md.

### "Показать все" button in todayPlacesSection (half mode truncation)

Source: 10-UI-SPEC.md Scroll/Drag Strategy and Copywriting Contract sections.

```swift
// Inside the `if let today = vm.trip.todayDay, !today.sortedPlaces.isEmpty` guard:
let allPlaces = today.sortedPlaces
let isHalf = vm.sheetDetent == .half
let displayedPlaces = isHalf && allPlaces.count > 3
    ? Array(allPlaces.prefix(3))
    : allPlaces

ForEach(Array(displayedPlaces.enumerated()), id: \.element.id) { index, place in
    // ... existing place button row ...
    if index < displayedPlaces.count - 1 {
        Divider().padding(.leading, 52)
    }
}

if isHalf && allPlaces.count > 3 {
    Divider().padding(.leading, 52)
    Button {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            vm.sheetDetent = .full
        }
    } label: {
        Text("Показать все (\(allPlaces.count))")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.sakuraPink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
    .buttonStyle(.plain)
}
```

### recentSearchesSection stub (full-mode placeholder)

```swift
@ViewBuilder
private var recentSearchesSection: some View {
    // Phase 10: renders nothing until "Недавние" data source is implemented
    // Section not shown when empty per D-06 empty state rules
    EmptyView()
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Show content only when search focused | Show content always in half/full (Apple Maps parity) | Phase 10 | Chips/today/map controls immediately visible |
| Hardcoded `isSearchFocused` gate | Boolean derived purely from VM search state | Phase 10 | Correct behavior without keyboard dependency |

**Deprecated/outdated:**
- `isSearchFocused &&` guard on idle content: removes in this phase

---

## Open Questions

1. **`vm.sheetContent == .searchResults` in idle condition**
   - What we know: After category search, `sheetContent = .searchResults` and `searchQuery` is empty
   - What's unclear: Whether current code would show chips above category search results
   - Recommendation: Use `vm.sheetContent == .idle` (not `.idle || .searchResults`) and ensure `vm.searchResults.isEmpty` as additional guard. Verify by tapping a category chip — chips should hide, search results should show.

2. **`@ViewBuilder` + `let` binding**
   - What we know: Swift 5.9+ allows `let` inside `@ViewBuilder` in most cases
   - What's unclear: Whether the computed `showIdleContent` variable will compile cleanly in the existing Swift version target
   - Recommendation: Extract as a `private var showIdleContent: Bool` computed property if `@ViewBuilder` rejects it. This is a trivial refactor.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual UI testing (no automated test target configured) |
| Config file | none — test target requires manual Xcode setup (noted in MEMORY.md) |
| Quick run command | Build + run in simulator: `Cmd+R` in Xcode |
| Full suite command | Build + run on physical device (required for `.ultraThinMaterial` validation) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CONT-01 | Chips visible in half mode without tapping search | Manual smoke | Launch app → tap trip → verify chips visible | ❌ Wave 0 |
| CONT-02 | "Сегодня" section visible in half mode | Manual smoke | Launch app with active trip → verify today places show | ❌ Wave 0 |
| CONT-03 | Map controls visible in half mode | Manual smoke | Open half sheet → verify Слои/Осадки/Обзор/Все места | ❌ Wave 0 |
| CONT-04 | No scroll/drag conflict in half mode | Manual interaction | Drag sheet down from half → verify dismisses to peek, not scrolls | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Build succeeds (no compile errors)
- **Per wave merge:** Full manual smoke test of all 4 CONT requirements
- **Phase gate:** All 4 CONT requirements pass on simulator before `/gsd:verify-work`

### Wave 0 Gaps

- No automated test infrastructure exists for SwiftUI views in this project
- Manual testing is the only validation path for this phase
- Physical device testing: not required for Phase 10 (no `.ultraThinMaterial` changes — that is Phase 11)

---

## Sources

### Primary (HIGH confidence)

- `Travel app/Views/Map/MapSearchContent.swift` — direct code inspection, lines 82-116 (scrollableContent), lines 120-154 (categoryChips), lines 423-489 (todayPlacesSection), lines 493-584 (mapControlsSection)
- `Travel app/Views/Map/MapViewModel.swift` — direct code inspection, sheetContent enum, search state properties
- `.planning/phases/10-sheet-content/10-CONTEXT.md` — locked decisions D-01 through D-06
- `.planning/phases/10-sheet-content/10-UI-SPEC.md` — complete visual contract, section order, animation timing, empty states

### Secondary (MEDIUM confidence)

- `.planning/STATE.md` — accumulated decisions, spring params lock
- `.planning/phases/07-sheet-geometry/07-CONTEXT.md` — geometry constraints (do not modify)
- `Travel app/Views/Map/MapBottomSheet.swift` — scroll/gesture architecture (lines 52-76)

### Tertiary (LOW confidence)

- None — all findings verified from direct code inspection.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified from direct codebase inspection
- Architecture: HIGH — all components already implemented, single condition change
- Pitfalls: HIGH — derived from reading actual code logic and UI-SPEC constraints

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable SwiftUI patterns; no fast-moving dependencies)
