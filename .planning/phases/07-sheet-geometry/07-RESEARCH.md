# Phase 7: Sheet Geometry - Research

**Researched:** 2026-03-21
**Domain:** SwiftUI custom bottom sheet geometry — peek pill / half / full detents, UnevenRoundedRectangle shape morph, ultraThinMaterial, drag gesture, safe area
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Heights and proportions**
- D-01: Peek height = 56pt (handle 8+5+6 = 19pt + search content area)
- D-02: Half height = 40% of screen height (was 47%)
- D-03: Full height = full screen, background extends under status bar
- D-04: Bottom gap in peek = 8pt above safe area (pill floats above tab bar)
- D-05: Full mode top = handle immediately below status bar safe area (no extra offset)
- D-06: Uniform detent heights for all content modes (including navigation)
- D-07: Tab bar remains visible in peek/idle, pill sits above it
- D-08: Portrait only — landscape not supported
- D-09: Pill width = full screen width minus 32pt (16pt left + 16pt right)

**Background materials**
- D-10: Peek pill background = `.ultraThinMaterial` + `Color.black.opacity(0.35)` overlay + `.environment(\.colorScheme, .dark)`
- D-11: Expanded background (half/full) = `Color(uiColor: .systemBackground)` — fully opaque
- D-12: Peek pill shadow = `shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 4)`
- D-13: Expanded sheet top shadow = `shadow(color: .black.opacity(0.15), radius: 10, y: -5)`
- D-14: Peek → half background transition = opacity crossfade (`.transition(.opacity)`, 0.15s easeInOut)
- D-15: Sheet always dark — inherits dark scheme from map

**Unified shape**
- D-16: Single `UnevenRoundedRectangle` for all states (not two different shape types)
- D-17: Top radius = 22pt in all states (peek and expanded identical)
- D-18: Bottom radius = 22pt in peek, 0pt in half/full (animated parameter)
- D-19: `style: .continuous` (Apple squircle corners)
- D-20: Radii and horizontal paddings change on detent SNAP only (not during drag) — spring animation
- D-21: Horizontal paddings: 16pt in peek → 0pt in half/full (on snap)

**Drag handle**
- D-22: Handle visible in ALL states (peek, half, full) — implemented in Phase 7
- D-23: Handle inside pill (not floating above)
- D-24: Handle dimensions: 36pt × 5pt, `Color(.systemFill)`
- D-25: Handle paddings: top 8pt, bottom 6pt — identical in all states

**Performance**
- D-26: Use `.onGeometryChange` (iOS 17+) instead of GeometryReader for height measurement — does not participate in layout pass

**Safe area and keyboard**
- D-27: Expanded background `.ignoresSafeArea(.bottom)` — extends to screen edge
- D-28: Full mode background `.ignoresSafeArea(.top)` — under status bar
- D-29: Sheet uses `.ignoresSafeArea(.keyboard)` — manages its own position

**Drag gesture**
- D-30: Velocity threshold 0.3 + 20% lookahead — keep as-is
- D-31: Spring params: `response: 0.35, dampingFraction: 0.85` — LOCKED, do not change
- D-32: In peek: drag gesture on entire pill (handle + search + background)
- D-33: In half/full: drag only through handle capsule
- D-34: minimumDistance = 5pt

**Integration**
- D-35: Tab bar hide: existing `.toolbar(isIdleMode ? .visible : .hidden, for: .tabBar)`
- D-36: Pill visible only in peek/idle — in expanded it is part of sheet
- D-37: Navigation mode: same sheet geometry
- D-38: Offline: sheet hidden when isOfflineWithCache (existing behavior)

**Dead code**
- D-39: Delete `MapFloatingSearchPill.swift` — unused, dead code

**Accessibility**
- D-40: Basic a11y: accessibilityLabel on drag handle, accessibilityHint on pill

### Claude's Discretion

- Spring animation API: `.spring(response:dampingFraction:)` (current one)
- Crossfade duration can be tuned during implementation (guideline 0.15s)
- Exact shadow opacity values can be adjusted visually

### Deferred Ideas (OUT OF SCOPE)

- `@Namespace mapScope` + `Map(scope:)` — Phase 9 (Floating Controls)
- Scroll-to-top-then-drag behavior — too complex for current scope, may be added in Phase 11
- Full VoiceOver flow with state announcements — post-MVP
- `.regularMaterial` fallback for navigation mode (performance) — Phase 11 polish
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GEOM-01 | Peek mode height = 56pt (full search bar + top padding for drag handle) | D-01 confirms 56pt; existing code uses 50pt — needs update in `SheetDetent.peek.height()` |
| GEOM-02 | Peek mode background = `.ultraThinMaterial` with dark color scheme, rounded on all 4 corners (~22pt) | D-10, D-17, D-19 fully specify the material + shape; STACK.md provides exact code pattern |
| GEOM-03 | Peek mode horizontal padding 16pt — pill "floats" with margins from edges | D-09, D-21; Pitfall 1 documents the exact modifier ordering needed to avoid background stretching |
| GEOM-04 | Half mode = ~40% screen, opaque dark background, rounded top corners only | D-02, D-11, D-18; single `UnevenRoundedRectangle` with bottom radii = 0pt handles this |
| GEOM-05 | Full mode = full screen, same opaque dark background, search immediately below safeAreaTop | D-03, D-05, D-28; needs `.ignoresSafeArea(.top)` on background + safeAreaTop padding on content |
</phase_requirements>

---

## Summary

Phase 7 refactors `MapBottomSheet.swift` from its current dual-shape, solid-color implementation into a single `UnevenRoundedRectangle` with animated parameters, replacing the peek pill's hardcoded `Color.black.opacity(0.75)` with `.ultraThinMaterial` + dark color scheme enforcement. The three detent heights are also corrected (peek 50pt → 56pt, half 47% → 40%).

All research for this phase is effectively complete: the canonical STACK.md and PITFALLS.md documents (generated 2026-03-21) provide exact code patterns, verified API calls, and ranked pitfalls specific to this codebase. The existing `MapBottomSheet.swift` has the correct architectural skeleton (custom GeometryReader overlay, drag gesture, detent enum) — Phase 7 is a targeted visual refactor of that file plus deletion of the dead `MapFloatingSearchPill.swift`.

The single most important constraint is using one `UnevenRoundedRectangle` for all states rather than switching between `RoundedRectangle` (peek) and `UnevenRoundedRectangle` (expanded). SwiftUI can only morph between identical shape types — different types snap instead of animate (Pitfall 9). The second most important constraint is `.onGeometryChange` instead of a layout-participating `GeometryReader` for height measurement (D-26, Pitfall 5).

**Primary recommendation:** Refactor `MapBottomSheet.swift` in three focused tasks: (1) update `SheetDetent` heights, (2) replace dual backgrounds with single `UnevenRoundedRectangle` + animated params, (3) move drag handle to all states + replace material. Delete `MapFloatingSearchPill.swift` as first action.

---

## Standard Stack

### Core

| API | iOS Min | Purpose | Why Standard |
|-----|---------|---------|--------------|
| `UnevenRoundedRectangle` | iOS 17 | Single shape covering all three detent states with animatable corner radii | Only shape in SwiftUI that exposes independent corner radii as animatable parameters; enables smooth shape morph |
| `.ultraThinMaterial` | iOS 15 | Peek pill background — vibrancy-aware frosted glass | Composites against live map pixels; adapts to tile color automatically; hardcoded opacity does not |
| `.environment(\.colorScheme, .dark)` | iOS 13 | Force dark rendering of material on peek pill | Material resolves to dark variant only when color scheme is dark; map forces dark but material may inherit from system |
| `.onGeometryChange(for:of:action:)` | iOS 17 | Height measurement without layout pass participation | Replaces GeometryReader for measurement-only use; does not trigger layout cascade during drag |
| `DragGesture(minimumDistance: 5)` | iOS 13 | Drag-to-resize with velocity detection | Existing implementation; `minimumDistance: 5` prevents accidental triggers from taps |
| `withAnimation(.spring(response: 0.35, dampingFraction: 0.85))` | iOS 13 | Detent snap animation | Parameters already tuned to Apple Maps feel; LOCKED per D-31 |

### Supporting

| API | iOS Min | Purpose | When to Use |
|-----|---------|---------|-------------|
| `Color(uiColor: .systemBackground)` | iOS 14 | Expanded sheet opaque background | Adapts to dark scheme forced by `.preferredColorScheme(.dark)` on the map view |
| `Color(.systemFill)` | iOS 14 | Drag handle fill color | Semantic color — correct weight in dark mode; adapts if color scheme ever changes |
| `.ignoresSafeArea(edges: .bottom)` | iOS 14 | Expanded background extends to screen bottom | Half/full mode only; peek pill must NOT use this |
| `.ignoresSafeArea(edges: .top)` | iOS 14 | Full mode background extends under status bar | Full mode only |
| `.ignoresSafeArea(.keyboard)` | iOS 14 | Prevent system keyboard avoidance from shifting sheet | Sheet manages its own vertical position |
| `UIAccessibility.post(notification: .layoutChanged, ...)` | iOS 13 | Announce detent state changes to VoiceOver | On snap, after animation completes |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `UnevenRoundedRectangle` (single, all states) | `RoundedRectangle` (peek) + `UnevenRoundedRectangle` (expanded) | Dual shapes cannot be morphed — shape snaps on transition. Current code has this bug. |
| `.ultraThinMaterial` + dark env + 0.35 overlay | `Color.black.opacity(0.75)` | Solid color doesn't adapt to tile color; looks wrong on light tiles (parks, beaches) on real device |
| `.onGeometryChange` | `GeometryReader` with `.onAppear`/`.onChange` | GeometryReader participates in layout pass — causes map annotation redraws at 60Hz during drag |
| Custom overlay sheet | `.presentationDetents` | Native sheet dims map background, anchors to screen edge — floating pill is impossible |

**Installation:** No new packages. All APIs are native SwiftUI/UIKit available in iOS 17+.

---

## Architecture Patterns

### Current Code Structure (to be modified)

```
Travel app/Views/Map/
├── MapBottomSheet.swift       PRIMARY: refactor background, shape, detent heights, handle
├── TripMapView.swift          VERIFY: tab bar logic, safeAreaPadding
└── MapFloatingSearchPill.swift  DELETE: dead code (D-39)
```

### Pattern 1: Single UnevenRoundedRectangle for All Detent States

**What:** One `UnevenRoundedRectangle` instance whose `bottomLeadingRadius`/`bottomTrailingRadius` animate from 22pt (peek) to 0pt (half/full) on detent snap, and whose container padding animates from 16pt to 0pt simultaneously.

**When to use:** Every time the sheet background is rendered — peek, half, and full.

**Example:**
```swift
// Source: .planning/research/STACK.md + PITFALLS.md (Pitfall 9)
// Compute shape parameters from current detent (NOT during drag — only on snap)
let bottomRadius: CGFloat = detent == .peek ? 22 : 0
let hPadding: CGFloat = detent == .peek ? 16 : 0

// Single shape used in all states
UnevenRoundedRectangle(
    topLeadingRadius: 22,
    bottomLeadingRadius: bottomRadius,
    bottomTrailingRadius: bottomRadius,
    topTrailingRadius: 22,
    style: .continuous
)
// .animation wraps the state change in the snap handler, not here
```

### Pattern 2: Dual Background Crossfade (Peek → Expanded)

**What:** The peek material background and the expanded opaque background are two separate layers wrapped in a `ZStack` or conditional `Group`. Each carries `.transition(.opacity)`. Switching between them creates a 0.15s crossfade driven by `.animation(.easeInOut(duration: 0.15), value: isPeek)`.

**When to use:** The `background` modifier on the sheet container.

**Example:**
```swift
// Source: .planning/research/STACK.md
.background {
    if isPeek {
        UnevenRoundedRectangle(
            topLeadingRadius: 22, bottomLeadingRadius: 22,
            bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous
        )
        .fill(.ultraThinMaterial)
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 22, bottomLeadingRadius: 22,
                bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous
            )
            .fill(Color.black.opacity(0.35))
        )
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)            // tiny lift from tab bar
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 4)
        .transition(.opacity)
    } else {
        UnevenRoundedRectangle(
            topLeadingRadius: 22, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 22, style: .continuous
        )
        .fill(Color(uiColor: .systemBackground))
        .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
        .ignoresSafeArea(edges: .bottom)
        .transition(.opacity)
    }
}
.animation(.easeInOut(duration: 0.15), value: isPeek)
```

### Pattern 3: onGeometryChange Height Capture

**What:** Replace the layout-participating `GeometryReader` body with a zero-height overlay that uses `.onGeometryChange` exclusively for measurement. The stored `@State screenHeight` is used by detent calculations.

**When to use:** Anywhere screen height is needed for detent math. iOS 17+ only — project targets iOS 17.

**Example:**
```swift
// Source: .planning/research/PITFALLS.md (Pitfall 5), Apple Developer Docs
@State private var screenHeight: CGFloat = 0
@State private var safeAreaTop: CGFloat = 0

var body: some View {
    ZStack {
        // Zero-height measurement layer — does not affect layout
        Color.clear
            .onGeometryChange(for: CGFloat.self) { geo in
                geo.size.height
            } action: { newHeight in
                screenHeight = newHeight
            }
            .onGeometryChange(for: CGFloat.self) { geo in
                geo.safeAreaInsets.top
            } action: { newTop in
                safeAreaTop = newTop
            }
            .frame(height: 0)

        // Sheet content uses stored screenHeight, not live geo
        sheetContent
    }
}
```

### Pattern 4: Drag Handle in All States

**What:** The drag handle is always rendered regardless of `detent`. In peek mode it was previously hidden (`if !isPeek`). Now it appears at the top of the VStack in all three states, inside the pill/sheet boundary.

**When to use:** The VStack at the top of the sheet content.

**Example:**
```swift
// Source: .planning/research/STACK.md + 07-UI-SPEC.md (D-22, D-23, D-24, D-25)
Capsule()
    .fill(Color(.systemFill))
    .frame(width: 36, height: 5)
    .padding(.top, 8)
    .padding(.bottom, 6)
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
    // Drag gesture only on handle in half/full; entire pill in peek
    .gesture(isPeek ? nil : dragGesture(totalHeight: screenHeight))
    .accessibilityLabel("Переместить панель")
    .accessibilityHint("Потяните вверх или вниз для изменения размера")
```

### Anti-Patterns to Avoid

- **`.padding(.horizontal)` before `.background()`:** Background stretches to full screen width. Always apply outer floating padding AFTER `.background()` (see Pitfall 1).
- **Different shape types per state:** `RoundedRectangle` for peek + `UnevenRoundedRectangle` for expanded = shape snaps instead of morphs (Pitfall 9). One type only.
- **GeometryReader in sheet body during drag:** Causes layout re-pass at 60Hz, redraws map (Pitfall 5). Use `.onGeometryChange` instead.
- **Animating shape params during drag:** Shape morph animations (`bottomRadius` change) should only trigger on detent snap — not continuously during drag tracking. Keep `dragOffset` as a raw `CGFloat`, not an animated value.
- **`withAnimation` in `onChange` observers:** Only wrap snap logic in `withAnimation`. Observers for `searchQuery`, `sheetDetent`, etc. must not animate on every keystroke (causes stutter).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Vibrancy-aware dark frosted glass background | Custom `UIVisualEffectView` wrapper | `.ultraThinMaterial` + `.environment(\.colorScheme, .dark)` | Material composites against live map pixels; custom UIVisualEffectView requires UIViewRepresentable and breaks SwiftUI animation |
| Animatable corner radius morph | Two separate shapes with `.transition` | Single `UnevenRoundedRectangle` with animated parameters | SwiftUI interpolates struct properties of the same type; different types cannot be interpolated |
| Safe area height calculation | Manual `UIScreen.main.bounds` math | `geo.safeAreaInsets.top` via `.onGeometryChange` | UIScreen values are stale on device rotation; geo values are layout-pass accurate |
| Keyboard avoidance | Manual keyboard height observation + offset | `.ignoresSafeArea(.keyboard)` on sheet container | Sheet knows when it is full-screen; system handles the rest |
| Drag velocity detection | Manual timestamp math | `value.predictedEndTranslation.height` from `DragGesture.Value` | `predictedEndTranslation` is velocity-weighted — correct even at gesture end |

**Key insight:** The existing `MapBottomSheet.swift` already implements the correct patterns for gesture handling, detent snapping, and tab bar coordination. Phase 7 is a focused visual refactor — do not rewrite the gesture logic.

---

## Common Pitfalls

### Pitfall 1: Background Stretches to Screen Edges (Peek Mode)

**What goes wrong:** Peek pill background fills full screen width instead of floating with 16pt margins.

**Why it happens:** `.padding(.horizontal, 16).background(...)` — the background measures the padded (full-width) frame. Modifier order is strict.

**How to avoid:** Apply background first, then outer padding:
```swift
// CORRECT
.background(UnevenRoundedRectangle(...).fill(...))
.padding(.horizontal, 16)   // outer float padding AFTER background
```

**Warning signs:** Peek mode background extends edge-to-edge in Simulator preview.

---

### Pitfall 2: Material Looks Wrong Over Light Map Tiles (Physical Device)

**What goes wrong:** `Color.black.opacity(0.75)` appears dark in Simulator but shows green/brown tint from park tiles on real device.

**Why it happens:** Fixed-opacity color does not adapt to underlying pixel content. `.ultraThinMaterial` composites against live pixels.

**How to avoid:** D-10 — use `.ultraThinMaterial` + `Color.black.opacity(0.35)` overlay + dark color scheme. Test on physical iPhone with map over a park tile.

**Warning signs:** Pill color changes when panning map to light-colored areas.

---

### Pitfall 3: Shape Snaps Instead of Morphs at Detent Transition

**What goes wrong:** Peek → half transition shows a visual pop/snap instead of smooth corner radius morph.

**Why it happens:** `RoundedRectangle` (peek) and `UnevenRoundedRectangle` (half/full) are different types — SwiftUI cannot interpolate between them.

**How to avoid:** D-16 — single `UnevenRoundedRectangle` for all states. Animate `bottomLeadingRadius`/`bottomTrailingRadius` from 22pt to 0pt on snap.

**Warning signs:** Slow-motion (Simulator Debug → Slow Animations) shows a 1-frame shape pop.

---

### Pitfall 4: GeometryReader Causes 60Hz Map Redraws During Drag

**What goes wrong:** CPU spikes to 40%+ during sheet drag; map annotations flicker.

**Why it happens:** `GeometryReader` participates in layout pass — `dragOffset` changes at 60Hz, triggering layout re-evaluation for the entire `ZStack` including `Map`.

**How to avoid:** D-26 — replace layout-participating `GeometryReader` with zero-height `.onGeometryChange` measurement layer. Store height in `@State`, use stored value during drag.

**Warning signs:** Instruments shows "View Body Invocations" for `Map` view executing at drag frequency.

---

### Pitfall 5: Full Mode Content Hidden Behind Status Bar

**What goes wrong:** Drag handle appears under the clock/battery icons; content clipped by status bar.

**Why it happens:** Full mode sheet frame = `screenHeight` but `.padding(.top, safeAreaTop)` on content is missing or applying to the wrong view.

**How to avoid:** D-05 — pad VStack content by `safeAreaTop` when `detent == .full`. Apply `.ignoresSafeArea(.top)` only to the background shape, not the content VStack.

**Warning signs:** Handle partially overlaps status bar icons in full mode.

---

### Pitfall 6: Shape Morph Params Animate During Drag (Jank)

**What goes wrong:** `bottomRadius` and `hPadding` interpolate continuously during drag as the sheet moves between heights, causing visual noise.

**Why it happens:** If the shape params are derived from `currentHeight` (a continuous drag value) rather than from `detent` (a discrete snap value), they change on every drag tick.

**How to avoid:** D-20 — derive shape params from `detent` enum only. `dragOffset` is applied only to the sheet frame height, not to any shape or padding parameter.

**Warning signs:** Corners visibly squish/expand while dragging (not just when snapping).

---

## Code Examples

Verified patterns from existing codebase and canonical research docs:

### SheetDetent.height() Update

```swift
// Source: 07-CONTEXT.md D-01, D-02, D-03
func height(in screenHeight: CGFloat) -> CGFloat {
    switch self {
    case .peek: return 56          // was 50 — GEOM-01
    case .half: return screenHeight * 0.40  // was 0.47 — GEOM-04 (D-02)
    case .full: return screenHeight        // unchanged — GEOM-05
    }
}
```

### Full Mode Safe Area Padding

```swift
// Source: .planning/research/PITFALLS.md (Pitfall 3), 07-UI-SPEC.md
.padding(.top, detent == .full ? safeAreaTop : 0)
// Applied to VStack content ONLY — background shape uses .ignoresSafeArea(.top)
```

### Peek Pill Accessibility

```swift
// Source: 07-UI-SPEC.md — Accessibility section
Color.clear
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())
    .accessibilityLabel("Панель карты")
    .accessibilityHint("Нажмите для открытия поиска")
    .gesture(isPeek ? dragGesture(totalHeight: screenHeight) : nil)
```

### Background Transition Animation

```swift
// Source: .planning/research/STACK.md — Background Transition section
.animation(.easeInOut(duration: 0.15), value: isPeek)
// The .transition(.opacity) on each branch + this .animation produces the crossfade
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `GeometryReader` for size measurement | `.onGeometryChange(for:of:action:)` | WWDC 2024 (iOS 18 backport to 17) | Measurement without layout pass; eliminates cascade redraws |
| `RoundedRectangle` (all corners same radius) | `UnevenRoundedRectangle` (per-corner) | iOS 17 | Shape morph between peek and expanded states |
| `.presentationDetents` for map sheets | Custom overlay with `DragGesture` | Confirmed via iOS 16-18 bug reports | Floating pill over map impossible with system sheet |
| `Color.black.opacity(N)` | `.ultraThinMaterial` + tint overlay | iOS 15 material system | Correct vibrancy over any tile color on real device |

**Deprecated/outdated:**
- `MapFloatingSearchPill.swift`: Dead file, not rendered anywhere in current code — DELETE per D-39 (confirmed by code search: `TripMapView.swift` does not import or instantiate it).
- `GeometryReader` as layout measurement tool: Use `.onGeometryChange` instead for iOS 17+ targets.
- `Color(red: 0.11, green: 0.11, blue: 0.12)` hardcoded dark: Use `Color(uiColor: .systemBackground)` with forced dark scheme — current code has this in `MapBottomSheet.swift` line 84.

---

## Open Questions

1. **`.onGeometryChange` `safeAreaInsets` availability**
   - What we know: `.onGeometryChange` was introduced at WWDC 2024 for iOS 18, but documentation suggests backport to iOS 17
   - What's unclear: Whether `geo.safeAreaInsets` is accessible inside the `.onGeometryChange` transform closure
   - Recommendation: If `safeAreaInsets` is not available via `.onGeometryChange`, fall back to reading safe area via `GeometryReader` on a zero-height overlay (the existing pattern in `MapBottomSheet.swift` lines 91-94 does this correctly)

2. **Half mode bottom padding for content**
   - What we know: Half mode uses `Color(uiColor: .systemBackground)` with `.ignoresSafeArea(.bottom)`. Existing `MapSearchContent` has its own bottom padding.
   - What's unclear: Whether `Spacer(minLength: 0)` at the bottom of the sheet VStack will create empty space in half mode over the home indicator.
   - Recommendation: Keep `Spacer(minLength: 0)` — it fills the sheet frame; content fills from top. This is correct behavior.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest / SwiftUI Preview — no dedicated test target currently configured |
| Config file | None — manual Xcode test target setup required |
| Quick run command | Xcode Simulator visual verification + Debug → Slow Animations |
| Full suite command | Physical device testing per 07-UI-SPEC.md physical device checklist |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GEOM-01 | Peek height = 56pt | manual — view hierarchy debug | Xcode Debug View Hierarchy → measure height | ❌ Wave 0 |
| GEOM-02 | Peek background = ultraThinMaterial, dark, rounded 22pt | manual — physical device visual | Physical device over park tile | ❌ Wave 0 |
| GEOM-03 | Peek horizontal padding = 16pt (pill floats) | manual — simulator visual | Simulator preview — check gap at edges | ❌ Wave 0 |
| GEOM-04 | Half mode = 40% opaque dark, top-only corners | manual — simulator slow animations | Debug → Slow Animations → drag to half | ❌ Wave 0 |
| GEOM-05 | Full mode = full screen, search under status bar | manual — simulator visual | Full mode: verify handle below clock | ❌ Wave 0 |

**Note:** This phase is pure geometry and visual polish. All acceptance tests are visual/manual — automated XCTest cannot meaningfully verify rendered material blur or pixel-level shadow values. The acceptance criteria in 07-CONTEXT.md (physical device blur test, side-by-side with Apple Maps, slow-motion shape morph) are the authoritative tests.

### Sampling Rate

- **Per task commit:** Build succeeds, Simulator shows correct geometry in all three detent states
- **Per wave merge:** Physical device test — pill remains dark over park tiles, shape morph confirmed in slow motion
- **Phase gate:** All 5 GEOM requirements pass visual inspection before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] No automated test infrastructure gaps block this phase — geometry is manually verified via Simulator + physical device
- [ ] Xcode test target may need creation for future phases — not required for Phase 7

*(Existing test infrastructure: none detected for SwiftUI views. Phase 7 is intentionally visual-only — manual acceptance criteria are the standard.)*

---

## Sources

### Primary (HIGH confidence)

- `.planning/research/STACK.md` (researched 2026-03-21) — exact API patterns for material, shape, mapScope, peek height, background transition; code verified against Apple Developer Docs
- `.planning/research/PITFALLS.md` (researched 2026-03-21) — 10 pitfalls with prevention strategies specific to this codebase; includes direct code analysis of `MapBottomSheet.swift`
- `.planning/phases/07-sheet-geometry/07-CONTEXT.md` — 40 locked decisions across 9 categories
- `.planning/phases/07-sheet-geometry/07-UI-SPEC.md` — full component inventory with exact values
- `Travel app/Views/Map/MapBottomSheet.swift` — direct code review (current state baseline)
- `Travel app/Views/Map/TripMapView.swift` — direct code review (integration points)
- [onGeometryChange official docs — Apple Developer](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)/) — iOS 17+ measurement API
- [UnevenRoundedRectangle — Apple Developer](https://developer.apple.com/documentation/swiftui/unevenroundedrectangle) — iOS 17+ shape API
- [SwiftUI Material — Apple Developer](https://developer.apple.com/documentation/swiftui/material/) — ultraThinMaterial, environment colorScheme

### Secondary (MEDIUM confidence)

- [Tracking geometry changes with onGeometryChange — Swift with Majid](https://swiftwithmajid.com/2024/08/13/tracking-geometry-changes-in-swiftui/) — confirmed onGeometryChange replaces GeometryReader for measurement
- [GeometryReader: Blessing or Curse — fatbobman](https://fatbobman.com/en/posts/geometryreader-blessing-or-curse/) — GeometryReader layout performance characteristics

### Tertiary (LOW confidence)

- None — all findings verified against official docs or direct code analysis.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs are iOS 17 native, verified in STACK.md against official docs
- Architecture: HIGH — patterns derived from existing working code + canonical research; no new patterns introduced
- Pitfalls: HIGH — PITFALLS.md was generated from direct code analysis of the actual failing code (GeometryReader, dual-shape, solid color)

**Research date:** 2026-03-21
**Valid until:** 2026-06-21 (90 days — all APIs are stable iOS 17 platform APIs; no fast-moving dependencies)
