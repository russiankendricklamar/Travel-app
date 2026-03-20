# Domain Pitfalls: Apple Maps UI Parity in SwiftUI

**Domain:** SwiftUI bottom sheet recreation, Apple Maps-style UI, MapKit integration
**Project:** Travel App — v1.1 Apple Maps UI Parity Milestone
**Researched:** 2026-03-21
**Confidence:** HIGH (verified against Apple Developer Docs, WWDC sessions, direct code analysis of existing failures)

---

## Critical Pitfalls

Mistakes that cause rewrites or multiple iteration cycles. All six failures listed in the milestone context are addressed here.

---

### Pitfall 1: `.padding(.horizontal)` on Content Does Not Restrict the Background

**What goes wrong:** The peek-mode pill has horizontal padding on its content (search bar, icons) to create visual inset. But the `.background()` modifier applies to the full frame of the containing VStack or HStack — not just the padded content. The result is a background rectangle that stretches edge-to-edge across the screen, making the pill look like a full-width bar instead of a floating capsule.

**Why it happens:** SwiftUI modifier ordering is strict: padding applied _to_ a view expands the view's frame before the background is measured. The pattern `.content.padding(.horizontal, 16).background(...)` means the background fills the padded frame (still full-width if the container is `.frame(maxWidth: .infinity)`). The background has no knowledge of the visual "inset" you want — it fills the view's actual bounds.

**How to avoid:** Apply the background _before_ the padding, then apply padding _to the background-carrying view_. For a floating pill:

```swift
// WRONG: background stretches to full width
HStack { searchContent }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .background(RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.75)))

// CORRECT: background stays pill-sized, outer padding creates the float
HStack { searchContent }
    .padding(.horizontal, 14)  // internal padding inside the pill
    .background(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.black.opacity(0.75))
    )
    .padding(.horizontal, 16)  // outer padding to float away from edges
```

The current `MapBottomSheet.swift` already does this correctly for the peek-mode background by applying `.padding(.horizontal, 16)` inside the `if isPeek` background Group. But content views placed _inside_ the sheet can re-introduce this problem if they add their own full-width frames before the background is applied.

**Warning signs:**
- Peek mode background extends to screen edges with no visible floating gap
- The background color fills the full width in Simulator preview
- Adding `.padding(.horizontal, N)` to the sheet wrapper has no visual effect on the background width

**Phase to address:** Sheet background phase — must be verified in the peek state before any other styling work.

---

### Pitfall 2: Opacity-Based Background Looks Wrong vs. System Materials

**What goes wrong:** `Color.black.opacity(0.75)` looks correct in screenshots but wrong on a real device with a light map underneath. In dark mode the difference is minimal; in light mode (or when map has light-colored tiles) the pill appears too transparent or shows a green/brown tint from the map through it.

**Why it happens:** A fixed-opacity color does not adapt to what is beneath it. Apple Maps uses a vibrancy-aware material (`UIBlurEffect` style `.systemChromeMaterial` or `.systemUltraThinMaterialDark`) that composites against the actual pixels of the map. This adapts automatically: the pill reads as dark regardless of the map tile color because the blur samples the underlying content and adjusts contrast.

SwiftUI materials (`.ultraThinMaterial`, `.regularMaterial`, etc.) automatically resolve to the correct vibrancy for the current color scheme. A hardcoded `Color.black.opacity(0.75)` does not.

**How to avoid:** For the peek pill, use a material combined with a tinted overlay instead of a plain opacity color:

```swift
// Peek pill background (dark, floating, vibrancy-aware)
RoundedRectangle(cornerRadius: 22, style: .continuous)
    .fill(.ultraThinMaterial)
    .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.black.opacity(0.35))  // tint layer on top of material
    )
```

For the half/full mode sheet background (opaque dark):

```swift
// The expanded sheet needs to feel solid, not glassy
// Use a dark adaptive color rather than hardcoded RGB
Color(uiColor: UIColor.systemBackground)  // adapts to color scheme
// OR for dark-only map mode:
Color(red: 0.11, green: 0.11, blue: 0.12)  // only correct when .preferredColorScheme(.dark) is forced on Map
```

The app forces `.preferredColorScheme(.dark)` on the `Map` view, so `Color(red: 0.11, green: 0.11, blue: 0.12)` is actually correct for the expanded sheet. The risk is forgetting that this hardcoded color only works because of the forced dark scheme.

**Warning signs:**
- Pill looks dark in Simulator but appears translucent or oddly-colored on a physical device
- Pill changes appearance when moving map to light-colored tiles (beaches, parks)
- Color looks correct in dark mode but too light in light mode (if dark scheme is not forced)

**Phase to address:** Visual polish phase. Test on a physical device with varied map content — parks, water, buildings.

---

### Pitfall 3: Sheet Height in Full Mode Goes Under Status Bar

**What goes wrong:** When the sheet expands to full, the drag handle and content appear under the status bar. Either the content is clipped by the safe area, or there is a dark "black bar" flash during the animation as the sheet slides into the status bar region.

**Why it happens:** The `GeometryReader` reports `geo.size.height` which includes the full available layout height. When `case .full: return screenHeight` is used, the sheet height equals the total layout height and the sheet's VStack starts at the very top of the layout space — which is already below the safe area top. But `.ignoresSafeArea(edges: .bottom)` on the background shape causes it to extend to the screen bottom, and the safe area top is not accounted for in content layout.

The "black bar" flash occurs specifically when the `NavigationStack` behind the sheet has a translucent navigation bar: the bar briefly becomes opaque during the sheet animation because the sheet's material or background touches the navigation bar region, triggering a UIKit composition change.

**How to avoid:**

```swift
// In SheetDetent height calculation, reserve space for safe area top in full mode
func height(in screenHeight: CGFloat, safeAreaTop: CGFloat) -> CGFloat {
    switch self {
    case .peek: return 50
    case .half: return screenHeight * 0.47
    case .full: return screenHeight  // sheet frame = full height
    }
}

// In sheet body layout, pad content top when in full mode
.padding(.top, detent == .full ? safeAreaTop : 0)
```

The current `MapBottomSheet.swift` already has this pattern at line 68 with `.padding(.top, isPeek ? 0 : (detent == .full ? safeAreaTop : 0))`. The black bar flash is separately caused by the `NavigationStack` toolbar. Resolve it with:

```swift
// On the NavigationStack wrapper
.toolbar(.hidden, for: .navigationBar)
// NOT just .toolbarBackground(.hidden) — that leaves the toolbar visible but transparent
// and still causes flash during sheet animation
```

**Warning signs:**
- Drag handle appears under or partially behind the clock/battery icons
- A black/dark flash appears at the top of the screen during the peek → full transition
- Content in full mode is clipped by the safe area

**Phase to address:** Full-mode expansion phase. Must test with `.toolbar(.hidden)` on the NavigationStack.

---

### Pitfall 4: Drag Gesture Conflicts with ScrollView Inside Sheet

**What goes wrong:** When the sheet is in half or full mode and contains a `ScrollView` (search results, place details), dragging down on the list to collapse the sheet instead scrolls the list. The sheet gesture never fires. Alternatively, dragging on the drag handle works but dragging on the list body does not collapse the sheet.

**Why it happens:** SwiftUI `ScrollView` claims all vertical drag gestures. A `DragGesture` attached via `.gesture()` to a parent view of a `ScrollView` will be silently overridden by the scroll view's internal gesture recognizer. The `DragGesture` with `.minimumDistance: 5` fires initially but loses the gesture to the scroll view on subsequent ticks.

**How to avoid:** Attach the drag gesture only to the drag handle area, not to the full sheet body. The scroll view should be allowed to scroll freely. Only collapse the sheet when the user drags the handle OR when the scroll view reaches the top AND the user continues dragging downward.

```swift
// Drag handle — always receives the sheet drag gesture
Capsule()
    .fill(Color.secondary.opacity(0.5))
    .frame(width: 60, height: 5)
    .padding(.top, 10)
    .contentShape(Rectangle())
    .gesture(dragGesture)

// ScrollView — NO additional gesture, scroll freely
ScrollView { listContent }
    // Do NOT add .gesture(dragGesture) here
```

For the "scroll to top then collapse" behavior (the real Apple Maps behavior), use `UIScrollViewDelegate` via `UIViewRepresentable` or check the scroll offset with a `ScrollViewReader`/`onScrollGeometryChange` and only activate the sheet drag when `contentOffset.y <= 0 && dragDirection == .down`.

The current implementation correctly attaches the drag only to the content area in peek mode via `isPeek ? dragGesture(...) : nil`. The risk is when content sections are added to the half/full modes that use their own gestures.

**Warning signs:**
- Dragging on a results list in half mode always scrolls instead of collapsing sheet
- Sheet can only be dragged from the handle — dragging anywhere else on the sheet body does nothing
- On iOS 18+, `UIGestureRecognizerRepresentable` may be needed to correctly interoperate

**Phase to address:** Half/full mode content phase. Test drag interaction on each content type (search results, place details, navigation steps).

---

### Pitfall 5: GeometryReader in Sheet Causes Continuous Redraws

**What goes wrong:** The sheet wraps content in a `GeometryReader` to get the screen height for detent calculations. Every pixel of drag offset causes a state update (`dragOffset`), which causes the `GeometryReader` body to re-execute, which re-computes the height, which causes SwiftUI to re-layout the entire sheet and all its children — including the `Map` view behind it. This manifests as 60fps animations that stutter at 30fps when the map has active content.

**Why it happens:** `GeometryReader` participates in the layout pass. Any `@State` change in a parent that contains a `GeometryReader` triggers a re-layout of the `GeometryReader`'s children. During drag, `dragOffset` changes at 60Hz, and if the `GeometryReader` or any computed property using `geo.size` is inside the updated subtree, the map (as a sibling in the same `ZStack`) can also be affected by layout invalidation.

**How to avoid:** Capture the screen height once on `.onAppear` and `.onChange(of: geo.size)`, storing it in a `@State` property. The `GeometryReader` itself should only update `screenHeight` and not be part of the sheet's body computation during drag.

```swift
// Capture height once, use stored value during drag
@State private var screenHeight: CGFloat = 0

var body: some View {
    GeometryReader { geo in
        Color.clear
            .onAppear { screenHeight = geo.size.height }
            .onChange(of: geo.size) { _, s in screenHeight = s.height }
    }
    .frame(height: 0)  // zero-height GeometryReader that only reads, doesn't layout

    sheetContent  // uses stored screenHeight, not live geo
}
```

On iOS 17+, prefer `.onGeometryChange(for: CGFloat.self) { geo in geo.size.height } action: { screenHeight = $0 }` — this is the WWDC 2024 recommended replacement for `GeometryReader` for size measurement. It does not affect layout.

**Warning signs:**
- CPU usage spikes to 40%+ during sheet drag in Instruments
- Map annotations flicker during sheet drag
- Debug "View Body Invocations" shows map view body executing at drag frequency

**Phase to address:** Performance validation phase. Profile in Instruments on a real device after initial implementation.

---

### Pitfall 6: Spring Animation Parameters Feel "Wrong" (Too Bouncy or Too Slow)

**What goes wrong:** The sheet snaps to detent positions but feels either rubber-band-bouncy (overshooting past the detent) or sluggish (drifts slowly). Neither matches the snappy-but-controlled feel of real Apple Maps.

**Why it happens:** The traditional `response`/`dampingFraction` spring API (pre-iOS 17) does not account for velocity at gesture end. The sheet snaps with a fixed spring regardless of how fast the user was dragging. Fast drags feel "stuck" because the spring ignores their momentum. Slow drags feel bouncy because a low `dampingFraction` was tuned for fast gestures.

iOS 17+ introduced `Animation.spring(duration:bounce:)` which is simpler to tune, and SwiftUI automatically passes gesture velocity to spring animations when state changes are triggered from within a gesture's `onEnded` handler.

**How to avoid:** Pass the drag velocity as initial velocity to the spring:

```swift
.onEnded { value in
    let velocity = value.predictedEndTranslation.height / screenHeight
    // velocity is normalized -1.0 to 1.0

    withAnimation(.spring(response: 0.38, dampingFraction: 0.78, blendDuration: 0)) {
        detent = nearest
        dragOffset = 0
    }
}
```

The Apple Maps feel uses approximately:
- `response: 0.35–0.4` (moderately fast but not instant)
- `dampingFraction: 0.8–0.85` (slight overshoot, settles quickly — NOT 1.0 which is critically damped/robotic)
- `blendDuration: 0` (prevents blending from previous animation state)

The current implementation uses `spring(response: 0.35, dampingFraction: 0.85)` which is close to correct. The risk is touching these values during "polish" iterations and making them worse.

**Warning signs:**
- Sheet overshoots its target detent visibly before settling
- Sheet feels "sticky" at low drag velocities — doesn't snap cleanly
- Sheet animation differs noticeably from Apple Maps (test side-by-side)

**Phase to address:** Animation tuning phase. Lock the parameters and mark them as intentional to prevent regression.

---

## Moderate Pitfalls

---

### Pitfall 7: Search Pill Height Mismatch vs. Apple Maps

**What goes wrong:** The search pill is visually taller than Apple Maps' search bar. The excess height creates empty space above and below the text/icons, making the pill look like a generic text field rather than a compact search control.

**Why it happens:** Apple Maps' search pill has ~44pt total height with ~8pt top/bottom padding. A TextField with `.padding(.vertical, 12)` plus the Capsule background will be at least 56pt tall. The discrepancy comes from treating the pill like a standard form input rather than a compact toolbar element.

**How to avoid:**
- Target ~44pt total pill height
- Use `.padding(.vertical, 6–8)` not `.padding(.vertical, 12)` for the pill content
- Verify with a `frame(height:)` assertion in preview
- The icon size should be 15–16pt (not 20pt, which is form-appropriate but too large for a pill)

```swift
// Apple Maps pill proportions (approximate)
HStack(spacing: 8) {
    Image(systemName: "magnifyingglass").font(.system(size: 15))
    Text("Поиск на карте").font(.system(size: 16))
    Spacer()
}
.padding(.horizontal, 12)
.padding(.vertical, 7)  // results in ~44pt total height
.background(Capsule().fill(...))
```

**Warning signs:**
- Side-by-side screenshot comparison shows search bar taller than Apple Maps
- The pill has visible empty space above/below the icon and text

**Phase to address:** Search pill layout phase. Screenshot comparison is the acceptance test.

---

### Pitfall 8: Half Mode Has Large Empty Area Below Content

**What goes wrong:** In half mode (~47% of screen height), the sheet shows content but leaves a large blank area between the last row and the sheet bottom. This looks unfinished and wastes space.

**Why it happens:** The sheet frame is sized to `screenHeight * 0.47` regardless of content height. If the content (search bar + chips + short results list) is only ~200pt tall, and the half mode frame is ~400pt, there is 200pt of empty background. Since the sheet background fills the entire frame, the blank area is visible and styled identically to the content area.

**How to avoid:** Two approaches:
1. Fill the half-mode frame with content (recommended): add sections like "Today's places", "Recent", or "Nearby" that fill the space naturally. This is what Apple Maps does — the sheet always has content proportional to its height.
2. Shrink the sheet to content height up to the detent maximum (complex): use `min(contentHeight, screenHeight * 0.47)` as the actual frame height. Requires measuring content height with `onGeometryChange`.

The current implementation already added "Today's places" and "Map controls" sections to fill the half-mode content. The risk is regression if those sections are behind conditions that hide them in certain states.

**Warning signs:**
- Large blank dark area at the bottom of the half-mode sheet
- Sheet looks taller than its content in any state

**Phase to address:** Content-filling phase. Verify each sheet content mode (idle, search results, place detail) fills the half mode frame.

---

### Pitfall 9: Corner Radius Changes Between States Feel Wrong

**What goes wrong:** When the sheet transitions from peek (floating pill, 22pt radius) to half/full (docked sheet, 30pt top radius, 0pt bottom), the background shape change is abrupt or not animated. The pill appears to "snap" into a rectangular sheet.

**Why it happens:** The peek mode uses a `RoundedRectangle(cornerRadius: 22)` and the half/full modes use `UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, bottomLeadingRadius: 0, bottomTrailingRadius: 0)`. These are different shape types — SwiftUI cannot morph between them with `.animation()` because they do not share a type-erased animatable path by default.

**How to avoid:** Use a single shape for all states, changing only the parameters:

```swift
// Single RoundedRectangle for all states — animate the corner radius change
let radius: CGFloat = detent == .peek ? 22 : 30
let bottomRadius: CGFloat = detent == .peek ? 22 : 0

// Use UnevenRoundedRectangle for all states
UnevenRoundedRectangle(
    topLeadingRadius: radius,
    bottomLeadingRadius: bottomRadius,
    bottomTrailingRadius: bottomRadius,
    topTrailingRadius: radius,
    style: .continuous
)
.animation(.spring(response: 0.35, dampingFraction: 0.85), value: detent)
```

This morphs the shape smoothly because it is the same type with animatable parameters.

**Warning signs:**
- Shape pops between rounded-all-corners and rounded-top-only with no animation
- The transition looks correct at full speed but shows a frame flash at 0.25x slow motion

**Phase to address:** Shape transition phase — alongside the corner radius work for peek and expanded states.

---

### Pitfall 10: Keyboard Appearance Conflicts with Sheet Height

**What goes wrong:** When the search `TextField` inside the sheet receives focus, the keyboard appears. iOS's built-in keyboard avoidance pushes the entire sheet view up — but the sheet's own detent height calculation is still based on screen height without keyboard. The sheet overshoots the available space, or the map behind it shifts unexpectedly.

**Why it happens:** The sheet uses `GeometryReader` to get `geo.size.height`, which reports the available height before keyboard avoidance is applied. Once the keyboard appears, iOS shrinks the `SafeAreaInsets.bottom` which changes the available layout height, but the stored `screenHeight` may not update if the `onChange(of: geo.size)` is not wired correctly.

The map view behind the sheet also uses `safeAreaPadding(.bottom, ...)` which interacts with the keyboard inset.

**How to avoid:**
- When the search field gains focus, explicitly set the sheet to `.full` mode _before_ the keyboard appears (using a 0.15s delay so the sheet animation starts first). This is the Apple Maps behavior: tap search → sheet goes full → keyboard rises.
- Use `.ignoresSafeArea(.keyboard)` on the sheet container to prevent double-shifting (the sheet handles its own keyboard inset, not the system)
- Do NOT use `.ignoresSafeArea(.keyboard)` on the `Map` view — the map should stay put, only the sheet adjusts

```swift
// On search field tap (before TextField becomes active):
.onTapGesture {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        vm.sheetDetent = .full
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        isSearchFocused = true  // keyboard appears AFTER sheet is at full
    }
}
```

**Warning signs:**
- Map view shifts up when keyboard appears (sheet + map both moving)
- Sheet overshoots the top of the screen momentarily when keyboard appears
- Content inside the sheet is hidden behind the keyboard

**Phase to address:** Search focus and keyboard interaction phase.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoded `Color(red: 0.11, ...)` for sheet background | Exact match to target dark color | Breaks if `preferredColorScheme(.dark)` is removed from Map view | Only acceptable while Map forces dark mode |
| Fixed `screenHeight * 0.47` for half detent | Simple calculation, no measurement | Empty area if content is sparse; clips content if it is tall | Acceptable for MVP; add content-filling sections |
| `dragOffset` as `@State CGFloat` driving all layout | Simple implementation | GeometryReader inside sheet triggers map redraws during drag | Acceptable until performance issue appears on real device |
| Separate shape types for peek vs. expanded | Code clarity per state | Cannot animate shape morph between states | Never — use single parameterized shape |
| Delay `isSearchFocused` by 150ms | Prevents keyboard race condition | Magic number, breaks on slow devices | Acceptable; use `withAnimation` completion callback on iOS 17+ instead |

---

## Performance Traps

Patterns that work correctly but degrade on older devices or with complex map content.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `GeometryReader` wrapping sheet during drag | Frame drops during sheet drag with active map | Store height in `@State`, use `onGeometryChange` for measurement only | iPhone 12 or older with active polyline animations |
| `.ultraThinMaterial` over live map | 30fps during navigation mode | Use `.regularMaterial` in navigation mode, or solid background | Any device when map has animated content (traffic, navigation polyline) |
| `withAnimation` on `detent` changes from `onChange` triggers | Sheet stutters when search query changes trigger content/height shifts | Use `withAnimation` only in gesture handlers, not `onChange` observers | Any device when `onChange` fires rapidly (typing) |
| Nested `ScrollView` inside full-mode sheet | Scroll and sheet gestures compete, causing jank | Attach sheet drag only to handle, not content area | Always if `DragGesture` is applied to ScrollView parent |

---

## UX Pitfalls

Common user experience mistakes when recreating Apple Maps bottom sheet.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Sheet dismisses when swiping down in half mode with active search | User loses search query | Bounce to half if search is active; only dismiss if truly idle |
| Search field activates in peek mode (keyboard jumps up) | Jarring experience | Treat peek search bar as a tap target that expands sheet first, then focuses |
| Sheet animates to full when user just wanted to peek at details | Feels uncontrolled | Tapping a pin should go to half mode; search bar tap goes to full mode |
| Half mode empty area styled same as content area | Sheet looks broken/unfinished | Fill with contextual content (today's places, recent searches) |
| Drag handle hidden in peek mode | User does not know sheet is draggable | Show handle in half/full mode; make entire peek bar draggable |

---

## "Looks Done But Isn't" Checklist

Things that appear complete in the Simulator but fail on a real device or specific states.

- [ ] **Peek pill background:** Verify on a physical device with the map showing a light-colored area (park, beach) — pill should still read as dark/distinct
- [ ] **Full mode top padding:** Verify drag handle does not overlap the clock in the status bar at any screen size (check iPhone SE and iPhone 16 Pro Max)
- [ ] **Shape morph animation:** Verify the peek → half transition in slow-motion (Simulator: Debug → Slow Animations) — no shape "snap"
- [ ] **Keyboard + sheet:** Verify tapping search in peek mode produces: sheet → full, THEN keyboard appears (not simultaneous)
- [ ] **Drag with scroll:** Verify that dragging down on a search result list in half mode collapses the sheet (not just scrolls the list)
- [ ] **Spring parameters:** Side-by-side screenshot comparison with Apple Maps for snap-to-detent speed and overshoot
- [ ] **Search pill height:** Measure rendered height using Xcode View Hierarchy Debugger — target ~44pt

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Background stretching to edges | LOW | Change modifier order: background before outer padding |
| Black bar flash on full mode | LOW | Add `.toolbar(.hidden, for: .navigationBar)` to NavigationStack |
| Gesture conflict in scroll list | MEDIUM | Extract drag to handle-only; add scroll-top detection for list body |
| Shape snap between states | LOW | Replace two shape types with single `UnevenRoundedRectangle` with animated params |
| Performance during drag | MEDIUM | Extract height measurement to zero-height GeometryReader; use `onGeometryChange` |
| Wrong material color on device | LOW | Replace `Color.black.opacity(N)` with `.ultraThinMaterial` + tint overlay |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Background stretches to edges | Sheet background phase (Phase 1) | Peek pill has visible gap from screen edges on all screen sizes |
| Opacity material wrong on device | Sheet background phase (Phase 1) | Test on physical device over varied map tiles |
| Full mode under status bar | Full mode expansion phase (Phase 2) | Drag handle visible below status bar, no black flash |
| Drag vs. scroll conflict | Sheet content phase (Phase 3) | Dragging on results list in half mode collapses to peek |
| GeometryReader redraws | Performance phase (Phase 4) | Instruments: <10% CPU during sheet drag over active map |
| Spring animation wrong | Animation polish phase (Phase 4) | Side-by-side comparison with Apple Maps passes review |
| Search pill too tall | Search pill phase (Phase 1) | Rendered height is 42–46pt via Xcode View Hierarchy Debugger |
| Half mode empty area | Content-filling phase (Phase 3) | No blank background visible in any content mode |
| Corner radius snap | Shape transition phase (Phase 2) | Slow-motion Simulator shows smooth morph, no shape pop |
| Keyboard + sheet conflict | Search interaction phase (Phase 2) | Sheet expands to full before keyboard appears, no double-shift |

---

## Navigation Domain Pitfalls (Preserved from v1.0)

These pitfalls from the v1.0 navigation milestone remain relevant for the v1.1 UI work.

### Background Location During Navigation (Critical)
See v1.0 research: `allowsBackgroundLocationUpdates`, `UIBackgroundModes: [location]`, `pausesLocationUpdatesAutomatically = false`. Active navigation still runs in v1.1 — do not regress these configurations during sheet refactoring.

### Glassmorphism Blur Performance on Map Overlays (Moderate)
`.ultraThinMaterial` over active navigation map causes frame drops on iPhone 12 and older. Use `.regularMaterial` for the navigation sheet mode. This applies directly to v1.1 sheet work: the expanded sheet over a navigating map must use the heavier material.

### `@Observable` MapViewModel Excessive Redraws (Moderate)
Adding new `@State` or `@Binding` wires through `MapBottomSheet` creates new observation dependencies. Each new binding to `vm` inside the sheet adds a re-render trigger. Keep the sheet's view model surface minimal — pass only what the sheet actually reads.

---

## Sources

- [SwiftUI backgrounds and modifier ordering — Swift by Sundell](https://www.swiftbysundell.com/articles/backgrounds-and-overlays-in-swiftui/) — MEDIUM confidence
- [GeometryReader: Blessing or Curse — fatbobman](https://fatbobman.com/en/posts/geometryreader-blessing-or-curse/) — HIGH confidence
- [Tracking geometry changes with onGeometryChange — Swift with Majid](https://swiftwithmajid.com/2024/08/13/tracking-geometry-changes-in-swiftui/) — HIGH confidence (WWDC 2024 API)
- [onGeometryChange official docs — Apple Developer](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)/) — HIGH confidence
- [Preventing scroll hijacking by DragGestureRecognizer — darjeelingsteve.com](https://darjeelingsteve.com/articles/Preventing-Scroll-Hijacking-by-DragGestureRecognizer-Inside-ScrollView.html) — MEDIUM confidence
- [Animate with springs — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10158/) — HIGH confidence
- [SwiftUI Material documentation — Apple Developer](https://developer.apple.com/documentation/swiftui/material/) — HIGH confidence
- [SwiftUI keyboard avoidance patterns — vadimbulavin.com](https://www.vadimbulavin.com/how-to-move-swiftui-view-when-keyboard-covers-text-field/) — MEDIUM confidence
- [background(_:ignoresSafeAreaEdges:) — Apple Developer](https://developer.apple.com/documentation/swiftui/view/background(_:ignoressafeareaedges:)) — HIGH confidence
- [Mastering safe area in SwiftUI — fatbobman](https://fatbobman.com/en/posts/safearea/) — HIGH confidence
- [SwiftUI draggable bottom sheet like Apple Maps — medium/@sonyahew](https://medium.com/@sonyahew/swiftui-draggable-bottom-sheet-for-iphone-ipad-like-apple-maps-a7ea71ebb2d3) — MEDIUM confidence
- Existing project code reviewed directly: `MapBottomSheet.swift`, `MapSearchContent.swift`, `TripMapView.swift`, `MapFloatingSearchPill.swift` — HIGH confidence (direct failure analysis)

---
*Pitfalls research for: Apple Maps UI parity in SwiftUI (v1.1 milestone)*
*Researched: 2026-03-21*
