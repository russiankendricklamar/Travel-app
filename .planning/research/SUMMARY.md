# Project Research Summary

**Project:** Travel App — Apple Maps UI Parity (v1.1 Milestone)
**Domain:** iOS SwiftUI — MapKit bottom sheet, floating controls, search pill visual polish
**Researched:** 2026-03-21
**Confidence:** HIGH

## Executive Summary

This milestone is a UI-only visual refactor of the existing map screen to achieve visual parity with Apple Maps. The navigation engine, routing, offline caching, and voice guidance are fully complete from v1.0. What remains is a set of targeted changes to `MapBottomSheet.swift`, `MapSearchContent.swift`, and `TripMapView.swift` — plus a new `MapFloatingControls.swift` component extracted from inline code in `TripMapView`. The changes are surgical: wrong background materials, oversized drag handle, incorrect peek height, jarring control visibility toggles, and a missing shape morph animation are the core problems. None require architectural rethinking.

The recommended approach is to work in dependency order: fix peek geometry first (height, background material, padding), then polish the search bar, then extract floating controls to their own component, then do a final content and animation pass. Every change has low regression risk because the components are already well-isolated — the sheet does not know about its content, and the content does not know about the sheet's shape. The hardest single task is the peek-to-half shape morph, which can be deferred as an optional v1.1 nice-to-have and replaced with a simple opacity crossfade if time is short.

The primary risk is introducing visual regressions in the gesture interaction surface. The drag gesture, spring parameters (`response: 0.35, dampingFraction: 0.85`), and focus management timing (150ms delay before `isSearchFocused = true`) are already correct in the existing code — pitfall research confirms these should not be touched. The recommended change set is additive (new material types, new component extraction) rather than behavioral.

## Key Findings

### Recommended Stack

The project already uses the correct stack. No new frameworks or packages are required for this milestone. All APIs are available on iOS 17+ which is the current minimum target.

**Core technologies:**
- `.ultraThinMaterial` / `.regularMaterial` (iOS 15+): Background blur for peek pill and floating controls — replaces hardcoded `Color.black.opacity(0.75)` and `Color(.secondarySystemGroupedBackground)`
- `@Namespace` + `Map(scope:)` + `.mapScope(_:)` (iOS 17+): Scoped map controls enabling `MapUserLocationButton`, `MapCompass`, `MapPitchToggle` as standalone positioned views — cannot be positioned manually without this
- `UnevenRoundedRectangle` (iOS 17+): Single parameterized shape for smooth peek-to-half corner radius morphing — mandatory to avoid shape-type snap
- `matchedGeometryEffect` (iOS 14+): Search pill to expanded bar animation — fallback to `.transition(.opacity.combined(with: .scale))` if z-index conflicts arise across ZStack layers
- `.onGeometryChange` (iOS 17+, WWDC24): Preferred over `GeometryReader` for height measurement to avoid layout-pass redraws during drag

**What NOT to add:**
- `.presentationDetents` — cannot reproduce floating pill; confirmed content-height bugs on iOS 16-18; only fixed in iOS 26
- Third-party sheet libraries (BottomSheet, Introspect) — fragile across iOS updates, adds SPM dependency
- `UIViewRepresentable` wrapping `UISheetPresentationController` — breaks @Observable pattern, unnecessary

### Expected Features

**Must have (table stakes — v1.1 target):**
- Peek pill height 56pt (from 50pt) — search content is clipped at current height; UISearchBar baseline is 56pt (HIGH confidence)
- `.ultraThinMaterial` blur on peek pill — flat opaque color reads as a stuck-on bar over the map, not glass
- `.regularMaterial` on floating controls — visual consistency with pill; prevents glass-over-glass conflict
- Controls use `.opacity()` + `.allowsHitTesting()` fade (not `if/else` toggle) — instant removal is jarring
- Bottom gap 8pt below peek pill — pill must visually float, not press against safe area
- Drag handle 36pt wide (from 60pt) — current 60pt is non-standard and oversized
- Sheet top corner radius 22pt (from 30pt) — 30pt is too large for a sheet top

**Should have (nice-to-have, v1.1):**
- User avatar circle (28-30pt) at trailing of search pill — present in Apple Maps since iOS 15; requires `AuthManager` state check with `person.circle.fill` fallback
- Shadow tuning on peek pill: softer shadow (opacity 0.18, radius 16) from current (opacity 0.3, radius 12)
- Peek-to-half shape morph — pill grows to full-width during drag via interpolated `horizontalPadding` and `cornerRadius` — highest complexity, highest visual impact; optional crossfade fallback accepted

**Defer (v1.2+):**
- Weather badge top-left on map (WeatherKit on map view — separate feature)
- Look Around left-side floating button
- Favorites/recent searches persistent section
- "Search here" button after manual map pan (iOS 18 feature)

**Confirmed app-specific deviations from Apple Maps (intentional — keep):**
- AI sparkles toggle replaces microphone icon
- Today's places section replaces Home/Work/Favorites circles
- Map controls section (layers, weather, discover) replaces Guides

### Architecture Approach

The architecture is already correct and requires extension, not replacement. `MapBottomSheet.swift` handles shape and drag; content views are agnostic to sheet geometry; `MapViewModel.swift` (974 lines, @Observable) is the single source of truth for all sheet state. The only structural change is extracting the inline location button and recenter button from `TripMapView.swift` into a new `MapFloatingControls.swift` — this reduces TripMapView complexity and gives controls a coherent home with proper visibility logic. `MapFloatingSearchPill.swift` (currently unused) should be repurposed or deleted and replaced by the new component.

**Major components:**
1. `MapBottomSheet.swift` — shape interpolation (pill vs. sheet), background material, drag gesture and snap. Only visual geometry changes needed here.
2. `MapSearchContent.swift` — search bar rendering, cancel button, category chips, today's places, map controls. Remove inner capsule background in peek; minor padding adjustment.
3. `MapFloatingControls.swift` (new, renamed from `MapFloatingSearchPill.swift`) — location button, recenter button; visibility tied to `vm.isNavigating` and `vm.sheetDetent`.
4. `TripMapView.swift` — ZStack layer assembly, task orchestration. Simplified by extracting floating controls; adds `@Namespace mapScope` for native MapKit controls.
5. `MapViewModel.swift` — add computed `showFloatingControls` property; change `SheetDetent.peek.height` value; no structural changes needed.

**Data flow is unchanged:** detent enum drives visual shape; ViewModel state machine methods drive detent changes; `FocusState` lives in `TripMapView` and is passed as a binding to `MapSearchContent` (FocusState must live in the view that owns the layout — correct pattern, do not change).

### Critical Pitfalls

1. **Background stretching to screen edges** — SwiftUI modifier order is strict: apply `.background()` before outer padding, not after. Incorrect order makes the pill expand to full screen width. Pattern: inner content padding → `.background(shape)` → outer floating padding. Phase 1 must verify pill has visible gap from screen edges on all screen sizes.

2. **Opacity-based background looks wrong on device** — `Color.black.opacity(0.75)` appears correct in Simulator but shows incorrect tint over light map tiles (parks, beaches) on a real device. Replace with `.ultraThinMaterial` + optional `Color.black.opacity(0.35)` tint overlay. Must test on physical device with varied map tiles.

3. **Separate shape types cannot animate between states** — `RoundedRectangle` (peek) and `UnevenRoundedRectangle` (half/full) are different types; SwiftUI cannot morph between them. Use a single `UnevenRoundedRectangle` for all states with animated parameters: `bottomRadius: isPeek ? 22 : 0`. This is the root cause of the current shape-snap visual.

4. **Drag gesture conflicts with ScrollView** — Attaching `DragGesture` to a parent of `ScrollView` will be silently overridden. Attach only to the drag handle capsule. Current implementation is correct; do not regress when adding content sections to half/full modes.

5. **GeometryReader redraws during drag** — `GeometryReader` inside the sheet re-executes at drag frequency (60Hz), potentially causing the `Map` behind it to repaint. Use `.onGeometryChange` (iOS 17+) for one-time height measurement stored in `@State`. Profile in Instruments after implementation — target <10% CPU during sheet drag.

## Implications for Roadmap

Based on research, the milestone maps to 5 phases with clear sequential and parallel dependencies. All changes are confined to 4-5 existing files plus one new file. No new external dependencies are required.

### Phase 1: Sheet Geometry and Background Materials

**Rationale:** All other visual changes depend on correct peek geometry. The background material (Pitfall 2) and modifier order (Pitfall 1) must be established before search bar sizing or controls positioning can be validated. This is the highest-risk phase because the shape morph is the most complex change.
**Delivers:** Peek pill uses `.ultraThinMaterial` blur; correct 56pt height; 8pt bottom gap; corner radius 22pt; single `UnevenRoundedRectangle` for smooth morph (or opacity crossfade fallback).
**Addresses:** Peek height, blur material, bottom gap, corner radius, shape morph animation.
**Files:** `MapBottomSheet.swift` only — isolated, zero regression risk to other screens.
**Avoids:** Pitfall 1 (modifier order), Pitfall 2 (opacity material on device), Pitfall 3 (shape type mismatch / snap animation).

### Phase 2: Search Bar Polish and Keyboard Interaction

**Rationale:** Depends on correct peek height from Phase 1. Inner capsule background removal, padding adjustment, and pill height validation (~44pt content area inside the 56pt pill) only make sense once the outer geometry is stable.
**Delivers:** Search bar fits naturally inside the pill with no double-background; correct `padding(.vertical, 7)` for icon and text; keyboard-sheet timing verified (sheet to full → 150ms → focus); optional user avatar at trailing.
**Files:** `MapSearchContent.swift` primarily; keyboard timing in `TripMapView.swift` (verify, not change).
**Avoids:** Pitfall 7 (search pill too tall — verify ~44pt rendered height via Xcode View Hierarchy Debugger), Pitfall 10 (keyboard + sheet conflict).

### Phase 3: Floating Controls Extraction and Native MapKit Integration

**Rationale:** Independent of Phase 2 — can be parallelized. Must complete before Phase 5 visual integration. Extracting controls from `TripMapView` reduces that file's complexity from inline VStack blocks to a single `MapFloatingControls` reference.
**Delivers:** `MapFloatingControls.swift` with location button and recenter button; controls use `.ultraThinMaterial` backgrounds; visibility uses `.opacity()` + `.allowsHitTesting()` instead of `if/else`; `@Namespace mapScope` wired to `Map` and `MapUserLocationButton`, `MapPitchToggle`, `MapCompass`.
**Files:** `MapFloatingControls.swift` (new), `TripMapView.swift` (extraction + mapScope addition).
**Avoids:** Anti-Pattern 5 (hiding controls too aggressively — keep location button visible at half detent, not just peek).

### Phase 4: Content Sections and Half Mode Verification

**Rationale:** Build on stable geometry (Phase 1) and stable search bar (Phase 2). This phase verifies existing sections are correctly gated and fills the half-mode frame. `MapViewModel` gets the two new computed properties documented in ARCHITECTURE.md.
**Delivers:** Half mode has no blank dark area; section headers match Apple Maps style (small caps, secondary color); `MapViewModel.showFloatingControls` computed property; `SheetDetent.peek.height` value updated.
**Files:** `MapSearchContent.swift` (section verification), `MapViewModel.swift` (minor additions).
**Avoids:** Pitfall 8 (half mode empty area — verify each content mode fills the frame).

### Phase 5: Visual Polish and Physical Device Validation

**Rationale:** All structural changes are complete. This phase is verification and targeted cosmetic fixes. Must be done on a physical device — Simulator cannot validate `.ultraThinMaterial` appearance over real map tiles.
**Delivers:** Shadow tuning (opacity 0.18, radius 16); spring parameter verification (must not deviate from `response: 0.35, dampingFraction: 0.85`); controls fade timing 0.2s; all acceptance checklist items verified.
**Files:** All map files (read-mostly; targeted single-value fixes only).
**Avoids:** Pitfall 6 (spring parameters — mark as intentional in code to prevent regression), Pitfall 2 final verification on physical device over park/beach tiles.

### Phase Ordering Rationale

- **Phases 1 → 2 are strictly sequential** — search bar sizing is meaningless before peek geometry is correct.
- **Phase 3 runs parallel to Phase 2** — floating controls extraction has no dependency on search bar content.
- **Phase 4 is gated on Phase 1 and 2** — half-mode content sections can only be validated after sheet shape is stable.
- **Phase 5 is last** — it is verification and cosmetic polish, not construction.
- The shape morph is the highest-complexity item. If `UnevenRoundedRectangle` parameter interpolation does not produce smooth results during Phase 1, switch to the opacity crossfade fallback (documented in STACK.md) rather than blocking the phase.

### Research Flags

Phases needing careful validation (not additional research — patterns are known):
- **Phase 1:** Verify peek pill behavior on iPhone SE (small screen) and iPhone 16 Pro Max (large screen). The `screenHeight * 0.47` half detent may need a small per-device adjustment.
- **Phase 3 (floating controls extraction):** Medium risk — touches `TripMapView.swift` which has complex state and many `onChange` handlers. Test all interactive paths after extraction: search tap, place pin tap, navigation start, recenter button.
- **Phase 5:** Requires a physical device. Simulator will not expose the material appearance problems described in Pitfall 2.

Phases with standard patterns (sufficient research, no additional research-phase needed):
- **Phase 2:** Material swaps and padding changes are deterministic SwiftUI changes with no platform-specific behavior.
- **Phase 4:** Content sections are already implemented; this is verification and minor conditional gating logic only.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All APIs are iOS 17+ native, verified via WWDC23/24 sessions and official Apple docs. No third-party dependencies introduced. |
| Features | MEDIUM | Apple does not publish pixel-level specs. Measurements marked ESTIMATED in FEATURES.md may need ±4pt tuning. Verified measurements (material types, spring params, corner radii) are HIGH confidence. |
| Architecture | HIGH | Derived from direct codebase analysis of the actual files being modified. All decisions are grounded in existing code behavior, not external assumptions. |
| Pitfalls | HIGH | Six critical pitfalls are directly derived from failures observable in the existing code. Four are confirmed by WWDC sessions and official documentation. Two (GeometryReader redraws, gesture conflicts) are confirmed by multiple community sources. |

**Overall confidence:** HIGH

### Gaps to Address

- **Exact peek height:** STACK.md specifies 58pt; FEATURES.md specifies 56pt; UISearchBar baseline is 56pt (HIGH confidence from Apple UIKit forums). Use 56pt as the starting value and tune during Phase 1 on a physical device.
- **User avatar implementation:** Requires checking `AuthManager` sign-in state and deciding on the fallback (`person.circle.fill` when not signed in). Phase 2 nice-to-have — do not block Phase 1 on this decision.
- **Shape morph complexity:** The interpolated `horizontalPadding` + `cornerRadius` morph during drag needs to be prototyped before committing. If `UnevenRoundedRectangle` animated parameters produce jank or unexpected behavior, the opacity crossfade fallback is the approved alternative — document which was chosen in the PLAN.
- **`.ultraThinMaterial` performance during navigation:** PITFALLS.md notes frame drops on iPhone 12 and older with active navigation polyline. Phase 5 must profile with Instruments and decide whether to switch to `.regularMaterial` in navigation mode.

## Sources

### Primary (HIGH confidence)
- [Meet MapKit for SwiftUI — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10043/) — MapScope, standalone controls API, mapScope namespace
- [Build a UIKit app with the new design — WWDC25](https://developer.apple.com/videos/play/wwdc2025/284/) — maps removes buttons when sheet expands to prevent glass-over-glass
- [onGeometryChange — Apple Developer](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)/) — WWDC24 GeometryReader replacement
- [MapUserLocationButton docs](https://developer.apple.com/documentation/mapkit/mapuserlocationbutton) — native control three-state behavior
- [SwiftUI Material docs](https://developer.apple.com/documentation/swiftui/material/) — material hierarchy, vibrancy behavior
- [Animate with springs — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10158/) — spring duration/bounce API, gesture velocity
- [background ignoresSafeAreaEdges — Apple Developer](https://developer.apple.com/documentation/swiftui/view/background(_:ignoressafeareaedges:)) — safe area + background modifier
- Codebase direct analysis: `MapBottomSheet.swift`, `MapSearchContent.swift`, `TripMapView.swift`, `MapViewModel.swift`, `MapFloatingSearchPill.swift`

### Secondary (MEDIUM confidence)
- [Adding Map Controls — createwithswift.com](https://www.createwithswift.com/adding-map-controls-to-a-map-view-with-swiftui-and-mapkit/) — mapControls modifier patterns
- [Mastering MapKit — swiftwithmajid.com](https://swiftwithmajid.com/2023/12/05/mastering-mapkit-in-swiftui-customizations/) — mapScope namespace with code examples
- [SwiftUI Bottom Sheet — dev.to, 2025](https://dev.to/sebastienlato/how-to-build-a-floating-bottom-sheet-in-swiftui-drag-snap-blur-lfp) — handle: 40×5pt, cornerRadius 3, ultraThinMaterial
- [GeometryReader: Blessing or Curse — fatbobman.com](https://fatbobman.com/en/posts/geometryreader-blessing-or-curse/) — redraws during drag analysis
- [Tracking geometry changes — swiftwithmajid.com](https://swiftwithmajid.com/2024/08/13/tracking-geometry-changes-in-swiftui/) — onGeometryChange usage
- [iOS 18 Apple Maps — MacRumors](https://www.macrumors.com/guide/ios-18-maps/) — user avatar presence since iOS 15
- [presentationDetents bugs — Hacking with Swift Forums](https://www.hackingwithswift.com/forums/swiftui/swiftui-presentationdetents-behaves-incorrectly-on-ios-16-18-but-works-correctly-on-ios-26/30435) — confirmed content-height bug justifying custom sheet

### Tertiary (LOW confidence — needs physical device validation)
- UISearchBar default height 56pt — Apple UIKit forums + GitHub Simplenote iOS issue #930
- Apple Maps pixel measurements — developer teardowns and community reproductions; no official spec published by Apple

---
*Research completed: 2026-03-21*
*Ready for roadmap: yes*
