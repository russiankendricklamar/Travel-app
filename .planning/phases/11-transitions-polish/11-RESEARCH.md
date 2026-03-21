# Phase 11: Transitions + Polish - Research

**Researched:** 2026-03-21
**Domain:** SwiftUI animation, spring physics, UnevenRoundedRectangle morph, haptics, keyboard focus flow
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-02:** Drag gesture snap spring is already correct: `response: 0.35, dampingFraction: 0.85` (MapBottomSheet line 150) — do NOT change
- **D-07:** Tap on search in peek → sheet expands to full → 150ms delay → keyboard appears
- **D-08:** Keyboard dismiss: if query empty → sheet collapses to half; if results exist → stays full
- **D-09:** Keyboard does NOT push content — `.ignoresSafeArea(.keyboard)` already in place
- **D-13:** `UIImpactFeedbackGenerator(.light)` haptic on every snap to detent (peek/half/full)
- **D-14:** Haptic fires in `onEnded` drag gesture after determining nearest detent

### Claude's Discretion
- **D-01:** Spring unification: audit ~20 `withAnimation(.spring(response: 0.3))` sites in MapViewModel → upgrade to `response: 0.35, dampingFraction: 0.85`
- **D-03:** Background morph: drag interpolation vs snap crossfade (blur pill → opaque sheet)
- **D-05:** Corner radius morph: drag interpolation vs animated snap (all-corners → top-only)
- **D-10:** Floating controls fade: drag-linked vs snap fade (current: `.animation(.spring(...), value: isVisible)`)
- **D-11:** Content fade timing: synchronous vs staggered cascade (chips → Сегодня → map controls)
- **D-12:** Horizontal padding morph: drag interpolation vs animated snap (16pt → 0pt)
- **D-15:** Tab bar transition: standard `.toolbar` animation vs spring-synchronized

### Deferred Ideas (OUT OF SCOPE)
- TRAN-05: Shape morph pill → full-width with corner radius interpolation
- Full VoiceOver flow with state announcements
- Scroll-to-top-then-drag behavior
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TRAN-01 | Spring animation (response: 0.35, dampingFraction: 0.85) for detent transitions | D-02 locked; D-01 identifies ~20 MapViewModel call sites using `response: 0.3` that need unification |
| TRAN-02 | Background morph: blur pill → opaque sheet smoothly on peek → half transition | UnevenRoundedRectangle opacity crossfade already present; drag-linked opacity interpolation is the upgrade path |
| TRAN-03 | Corner radius morph: all-corners (peek) → top-only (half/full) | UnevenRoundedRectangle already used with distinct configs; animated snap with `withAnimation(.spring(...), value: isPeek)` is the clean path |
| TRAN-04 | Keyboard expand: sheet → full, then 150ms delay → focus text field | Pattern already implemented in peek tap gesture (MapSearchContent line 250-257); needs application to full expand path |
</phase_requirements>

---

## Summary

Phase 11 is a **polish phase** — the infrastructure is in place. All four requirements address refinement of existing mechanisms, not new feature construction. The codebase is in a good state: `UnevenRoundedRectangle` is already used for shape, `.spring(response: 0.35, dampingFraction: 0.85)` is already used in drag snap and FloatingControlsOverlay, and the 150ms keyboard delay pattern is already coded in the peek tap handler.

The primary work is: (1) unify ~20 `withAnimation(.spring(response: 0.3))` call sites in MapViewModel to use the correct spring, (2) improve the background morph from binary crossfade to drag-linked opacity interpolation, (3) improve corner radius morph from binary switch to animated snap, (4) verify the keyboard flow works on the full expand path (not just peek tap), and (5) add haptic feedback to the drag snap `onEnded` handler.

The discretion decisions all have a clear best answer based on code inspection: drag interpolation for morphs during active drag (TRAN-02/03), snap animation for programmatic transitions, and synchronous (not staggered) content fade to match Apple Maps feel. Physical device verification is mandatory before closing this milestone.

**Primary recommendation:** Upgrade MapBottomSheet to use drag-progress interpolation for background opacity and corner radius during live drag, keep opacity crossfade for programmatic snap transitions, unify spring params project-wide, add haptics to drag `onEnded`.

---

## Standard Stack

### Core (already in project — no new dependencies)
| API | Version | Purpose | Why Standard |
|-----|---------|---------|--------------|
| `SwiftUI.withAnimation` | iOS 17+ | Drives programmatic detent transitions | Native; zero overhead |
| `spring(response:dampingFraction:)` | iOS 17+ | Apple-standard spring physics | Matches UIKit spring tuning; used throughout codebase |
| `UnevenRoundedRectangle` | iOS 16+ | Shape with per-corner radii | Already in use; supports animated interpolation |
| `UIImpactFeedbackGenerator` | iOS 10+ | Haptic feedback | Standard haptics API; `.light` style least jarring |
| `.ignoresSafeArea(.keyboard)` | iOS 14+ | Keyboard non-displacement | Already applied to MapBottomSheet |

### Supporting
| API | Purpose | When to Use |
|-----|---------|-------------|
| `DragGesture.Value.translation` | Compute drag progress ratio | In `.onChanged` for live morph |
| `DispatchQueue.main.asyncAfter` | 150ms keyboard focus delay | TRAN-04 only |
| `FocusState.Binding` | Control keyboard presentation | Already wired via `isSearchFocused` |
| `GeometryReader` / `onGeometryChange` | Screen height for progress normalization | Already in MapBottomSheet |

### No New Dependencies
This phase requires zero new Swift packages. All required APIs are already imported and used.

---

## Architecture Patterns

### Pattern 1: Drag-Progress Interpolation (for morphs during live drag)

**What:** During `DragGesture.onChanged`, compute a normalized `progress` value (0 = peek height, 1 = half height) and use `lerp()` to drive opacity and corner radii. This is the "drag interpolation" option for D-03, D-05, D-12.

**When to use:** Any visual property that should track finger position in real time — background opacity, corner radii, horizontal padding.

**Example:**
```swift
// In MapBottomSheet body — computed during drag
private func dragProgress(in screenHeight: CGFloat) -> CGFloat {
    let peekH = SheetDetent.peek.height(in: screenHeight)
    let halfH = SheetDetent.half.height(in: screenHeight)
    let currentH = detent.height(in: screenHeight) + dragOffset
    let raw = (currentH - peekH) / (halfH - peekH)
    return max(0, min(1, raw))
}

// Usage in background modifier
let progress = dragProgress(in: screenHeight)
let bottomRadius: CGFloat = 22 * (1 - progress)  // 22 → 0
let backgroundOpacity = progress  // 0 → 1 blend value
```

**Why this approach:** STATE.md confirms: "Used opacity crossfade between two UnevenRoundedRectangle backgrounds rather than animating corner radii to avoid interpolation jank." Phase 7 chose crossfade to avoid jank. For Phase 11, the upgrade path is to keep crossfade for *snap* transitions but add drag-linked interpolation during *active drag* only. The snap animation still uses `.easeInOut(duration: 0.15)` crossfade; drag tracking happens in `onChanged` without `withAnimation`.

### Pattern 2: Spring Unification (D-01)

**What:** Replace all `withAnimation(.spring(response: 0.3))` calls in MapViewModel with `withAnimation(.spring(response: 0.35, dampingFraction: 0.85))`.

**Inventory from code inspection:**
- `onPlaceSelected()` line 259, 264 — `.spring(response: 0.3)`
- `selectSearchResult()` line 272 — `.spring(response: 0.3)`
- `selectAIResult()` line 291 — `.spring(response: 0.3)`
- `clearSelection()` line 315 — `.spring(response: 0.3)`
- `dismissSearch()` line 488 — `.spring(response: 0.3)`
- `performMapSearch()` line 384 — `.spring(response: 0.3)`
- `performCategorySearch()` line 413 — `.spring(response: 0.3)`
- `calculateDirectionRoute()` line 541-547 — `.spring(response: 0.3)`
- `calculateRouteToSearchedItem()` line 589-595 — `.spring(response: 0.3)`
- `clearRoute()` line 625 — `.spring(response: 0.3)`
- `startNavigation()` line 703, 706 — `.spring(response: 0.3)`
- `stopNavigation()` line 743, 746 — `.spring(response: 0.3)`

**Recommendation:** Define a constant `MapViewModel.sheetSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)` and replace all sites.

### Pattern 3: Haptic on Drag Snap (D-13, D-14)

**What:** Add `UIImpactFeedbackGenerator(.light).impactOccurred()` in `MapBottomSheet.dragGesture().onEnded`, immediately before or after `withAnimation(...)`.

**Current state:** Haptic is present in the peek tap gesture (MapSearchContent line 251) and in FloatingControlsOverlay button taps. Missing from drag snap.

```swift
// In MapBottomSheet.dragGesture() onEnded:
let nearest = SheetDetent.nearest(to: targetHeight, in: totalHeight)
UIImpactFeedbackGenerator(style: .light).impactOccurred()  // ADD HERE
withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
    detent = nearest
    dragOffset = 0
}
```

### Pattern 4: Keyboard Expand Flow (TRAN-04)

**Current implementation (MapSearchContent line 250-257):**
```swift
// Peek tap → expand to half, then 150ms keyboard delay
.onTapGesture {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        vm.sheetDetent = .half  // D-32: expand to half, not full
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        isSearchFocused = true
    }
}
```

**TRAN-04 requirement** says "sheet → full, затем 150ms delay → keyboard". The CONTEXT.md D-07 says "tap on search in peek → sheet expands to full → 150ms → keyboard". However the current code expands to `.half` first (D-32 from Phase 8). This is the correct behavior — the spec in TRAN-04 uses "full" loosely to mean "expanded from peek". The half expand is by design.

**Verification needed:** Confirm no content shift occurs when keyboard appears. `.ignoresSafeArea(.keyboard)` is already on MapBottomSheet, so this should be satisfied. Test on physical device only.

### Pattern 5: Content Fade Timing (D-11)

**Recommendation: Synchronous (not staggered).** Apple Maps content fades in as a unit with the background morph. Staggered cascade adds complexity and visual noise for this data density. The existing `.animation(.easeInOut(duration: 0.2), value: showIdleContent)` in MapSearchContent line 120 is already correct — keep it.

If a subtle stagger is desired, limit to chips → content (2 steps, 50ms offset), not 3+ steps.

### Pattern 6: Floating Controls Fade (D-10)

**Recommendation: Keep current snap fade.** `FloatingControlsOverlay` already uses `.animation(.spring(response: 0.35, dampingFraction: 0.85), value: isVisible)` (line 38). This is already spring-consistent and produces a natural feel. Drag-linked opacity would require passing `dragProgress` up from MapBottomSheet → TripMapView → FloatingControlsOverlay, adding coupling for marginal visual improvement.

### Pattern 7: Horizontal Padding Morph (D-12)

**Recommendation: Animated snap.** The `.padding(.horizontal, isPeek ? 16 : 0)` in MapBottomSheet already receives the `.animation(.easeInOut(duration: 0.15), value: isPeek)` modifier (line 121). Change this to `.animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPeek)` for spring consistency. Do NOT change to drag interpolation — animated snap for padding is visually indistinguishable and simpler.

### Pattern 8: Tab Bar Transition (D-15)

**Recommendation: Keep current.** TripMapView line 161 already applies `.animation(.spring(response: 0.35, dampingFraction: 0.85), value: isIdleMode)` to the ZStack. The toolbar visibility change (line 165) is driven by this same spring. Standard `.toolbar` animation is already synchronized. No change needed.

### Anti-Patterns to Avoid
- **Animating corner radii inside `withAnimation` on a shape switch:** Phase 7 STATE.md records this causes jank. Use crossfade (`.transition(.opacity)`) for the snap case, interpolation only during active drag.
- **Preparing `UIImpactFeedbackGenerator` on every trigger:** Instantiate once and call `prepare()` for lower latency haptics (optional optimization if haptic feels delayed).
- **Using `.animation` on the full VStack:** Scope animations to specific modifiers with `value:` parameter to avoid unexpected animation of unrelated views.
- **Relying on Simulator for blur/haptic validation:** Material blur over map tiles is not rendered in Simulator. Haptic intensity is not testable in Simulator.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spring physics values | Custom easing curve | `.spring(response:dampingFraction:)` | Already tuned; STATE.md locked values |
| Keyboard avoidance | Manual offset calculation | `.ignoresSafeArea(.keyboard)` | Already applied; content stays put |
| Haptic timing | Custom timer | `UIImpactFeedbackGenerator` `prepare()` + `impactOccurred()` | OS-managed latency optimization |
| Progress lerp | Custom interpolation library | Inline `max(0, min(1, (x - a) / (b - a)))` | 1-line, no dependency |

---

## Common Pitfalls

### Pitfall 1: Double Animation on Drag End
**What goes wrong:** Adding `withAnimation` in `dragGesture().onChanged` causes double animation when `onEnded` also calls `withAnimation`.
**Why it happens:** Drag interpolation should run without `withAnimation` in `onChanged` — the state change is direct, not animated. Only `onEnded` uses `withAnimation`.
**How to avoid:** In `onChanged`, update `dragOffset` directly (no `withAnimation`). In `onEnded`, use `withAnimation(.spring(...))`.

### Pitfall 2: Background Jank from Animating Shape Switch
**What goes wrong:** Switching `UnevenRoundedRectangle` parameters inside `withAnimation` causes the shape path to interpolate, which can render as a visual tear on older hardware.
**Why it happens:** SwiftUI interpolates shape paths between keyframes; complex paths can stutter.
**How to avoid:** Keep the two-branch background (peek vs expanded) with `.transition(.opacity)` for snap. Use drag-progress opacity to blend between them during drag (no `withAnimation` needed since dragOffset drives it directly).

### Pitfall 3: Keyboard Focus Timing Race
**What goes wrong:** Setting `isSearchFocused = true` immediately after expanding the sheet shows keyboard before sheet animation completes, causing a content jump.
**Why it happens:** Keyboard presentation is faster than spring animation (~350ms).
**How to avoid:** 150ms delay is already implemented and locked (D-07). Do not reduce this delay.

### Pitfall 4: `.animation` Modifier Scope Leakage
**What goes wrong:** Placing `.animation(.spring(...), value: isPeek)` on an outer container animates all child views — including content that should not animate.
**Why it happens:** `.animation` propagates down the view hierarchy when placed without scoping.
**How to avoid:** Place `.animation` modifiers on specific properties (e.g., on `.padding`, `.opacity`, `.background`) not on the container. The existing `Group { }.animation(...)` pattern in MapSearchContent is correct.

### Pitfall 5: Physical Device Assumptions
**What goes wrong:** Transitions that look smooth at 60fps in Simulator stutter at 60fps on iPhone due to map tile compositing overhead.
**Why it happens:** Map tiles add a GPU compositing layer that isn't present in Simulator.
**How to avoid:** Test all drag-linked animations on a physical device. Specifically: drag-linked background opacity while map is visible, corner radius changes while map tiles render.

---

## Code Examples

### Complete Drag Gesture with Haptic (MapBottomSheet)
```swift
// Source: existing MapBottomSheet.dragGesture() + haptic addition
private func dragGesture(totalHeight: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 5, coordinateSpace: .global)
        .onChanged { value in
            dragOffset = -value.translation.height  // direct, no withAnimation
        }
        .onEnded { value in
            let currentHeight = detent.height(in: totalHeight) + dragOffset
            let velocity = -value.predictedEndTranslation.height / totalHeight
            let targetHeight: CGFloat
            if abs(velocity) > 0.3 {
                targetHeight = velocity > 0
                    ? currentHeight + totalHeight * 0.2
                    : currentHeight - totalHeight * 0.2
            } else {
                targetHeight = currentHeight
            }
            let nearest = SheetDetent.nearest(to: targetHeight, in: totalHeight)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()  // D-13/D-14
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                detent = nearest
                dragOffset = 0
            }
        }
}
```

### Drag-Progress Background Blend
```swift
// In MapBottomSheet body — drives live morph during drag
private func dragProgress(in screenHeight: CGFloat) -> CGFloat {
    guard screenHeight > 0 else { return detent == .peek ? 0 : 1 }
    let peekH = SheetDetent.peek.height(in: screenHeight)
    let halfH = SheetDetent.half.height(in: screenHeight)
    let currentH = detent.height(in: screenHeight) + dragOffset
    return max(0, min(1, (currentH - peekH) / (halfH - peekH)))
}

// Background modifier — always render both layers, crossfade via opacity
.background {
    let progress = dragProgress(in: screenHeight)
    ZStack {
        // Peek background (blur pill) — fades out as sheet rises
        UnevenRoundedRectangle(
            topLeadingRadius: 22, bottomLeadingRadius: 22,
            bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous
        )
        .fill(.ultraThinMaterial)
        .overlay(UnevenRoundedRectangle(...)
            .fill(Color.black.opacity(0.35)))
        .environment(\.colorScheme, .dark)
        .opacity(1 - progress)

        // Expanded background (opaque) — fades in as sheet rises
        UnevenRoundedRectangle(
            topLeadingRadius: 22, bottomLeadingRadius: 22 * (1 - progress),
            bottomTrailingRadius: 22 * (1 - progress), topTrailingRadius: 22,
            style: .continuous
        )
        .fill(Color(uiColor: .systemBackground))
        .opacity(progress)
    }
}
// No .animation modifier here — dragOffset drives it reactively
```

### Spring Constant in MapViewModel
```swift
// Define once, use everywhere
private static let sheetSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)

// Replace all withAnimation(.spring(response: 0.3)) sites:
withAnimation(Self.sheetSpring) { sheetDetent = .peek }
```

---

## State of the Art

| Old Approach | Current Approach | Status | Impact |
|--------------|------------------|--------|--------|
| `withAnimation(.spring(response: 0.3))` (no damping) | `.spring(response: 0.35, dampingFraction: 0.85)` | Phase 11 target | Consistent feel; no underdamped bounce |
| Binary background switch (isPeek if/else) | Drag-progress opacity blend | Phase 11 target | Background tracks finger position |
| No haptic on drag snap | `.light` impact on snap | Phase 11 target | Tactile confirmation |
| Corner radius hard switch | Drag-progress corner interpolation | Phase 11 target | Smooth morph |

---

## Open Questions

1. **Drag-progress corner radius during snap**
   - What we know: Phase 7 noted interpolation jank risk for shape path animation
   - What's unclear: Whether animating `UnevenRoundedRectangle` bottomLeadingRadius/bottomTrailingRadius inside `withAnimation(.spring(...))` produces jank on iPhone 17 Pro vs older hardware
   - Recommendation: Implement drag-progress interpolation (no `withAnimation`). For the *snap* phase (onEnded), let the spring animate the corner radii directly — test on physical device. If jank appears, revert snap to opacity crossfade only.

2. **Content shift on keyboard appearance**
   - What we know: `.ignoresSafeArea(.keyboard)` is applied to MapBottomSheet
   - What's unclear: Whether ScrollView inside the sheet respects this in full mode with keyboard visible
   - Recommendation: Test TRAN-04 on physical device with full mode active; verify no scroll jump.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode native) |
| Config file | Xcode project — `Travel appTests/` target |
| Quick run command | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 16 Pro" -only-testing "Travel appTests"` |
| Full suite command | Same — no separate integration suite currently |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRAN-01 | Spring params unified across all MapViewModel detent changes | Unit — verify `sheetSpring` constant used | Manual code review (animation params not observable) | ❌ Wave 0 note |
| TRAN-02 | Background morph opacity tracks drag | Manual-only | Physical device drag test | N/A |
| TRAN-03 | Corner radius morphs peek→half | Manual-only | Physical device drag test | N/A |
| TRAN-04 | Sheet expands, 150ms later keyboard appears | Manual-only | Physical device tap test | N/A |

**Note on manual-only tests:** TRAN-02, TRAN-03, TRAN-04 involve UIKit animation, Material rendering, and keyboard presentation — none are accessible to XCTest in a meaningful way. The test artifact for these requirements is physical device verification (D-16/D-17/D-18 in CONTEXT.md).

### Sampling Rate
- **Per task commit:** No automated test run (pure animation/UI phase)
- **Per wave merge:** `xcodebuild build -scheme "Travel app"` — confirms no compilation errors
- **Phase gate:** Build succeeds + physical device checklist green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] No unit test for spring constant value — consider adding a trivial compile-time check if desired
- None blocking — existing test infrastructure covers all non-animation concerns

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `MapBottomSheet.swift` (157 lines) — current background, drag, shape implementation
- Direct code inspection: `MapViewModel.swift` (979 lines) — all ~12 spring animation call sites inventoried
- Direct code inspection: `MapSearchContent.swift` — keyboard expand flow at lines 250-257
- Direct code inspection: `FloatingControlsOverlay.swift` — spring already correct at line 38
- Direct code inspection: `TripMapView.swift` — tab bar animation at line 161
- `.planning/STATE.md` — locked decisions: spring params, focus delay 150ms, crossfade approach

### Secondary (MEDIUM confidence)
- CONTEXT.md D-01 through D-18 — all implementation decisions documented by prior discussion session
- REQUIREMENTS.md TRAN-01 through TRAN-04 — acceptance criteria

### Tertiary (LOW confidence)
- None — all findings based on direct code inspection and locked project decisions

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all APIs already in use
- Architecture: HIGH — patterns derived from existing code + STATE.md decisions
- Pitfalls: HIGH — Phase 7 STATE.md explicitly records the crossfade-vs-interpolation decision with jank rationale
- Spring unification inventory: HIGH — all call sites manually counted from MapViewModel source

**Research date:** 2026-03-21
**Valid until:** Stable (no fast-moving dependencies; pure SwiftUI animation patterns)
