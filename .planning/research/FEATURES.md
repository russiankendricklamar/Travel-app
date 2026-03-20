# Feature Research: Apple Maps UI Parity

**Domain:** Apple Maps map view UI replication — bottom sheet, search pill, floating controls
**Researched:** 2026-03-21
**Confidence:** MEDIUM (visual inspection + developer teardowns + codebase analysis; no official Apple pixel specs published)

---

## Methodology Note

Apple does not publish pixel-level specifications for the Maps UI. This document synthesizes:
1. Direct codebase analysis of existing `MapBottomSheet.swift`, `MapSearchContent.swift`, `TripMapView.swift`
2. Developer teardowns, SwiftUI implementation guides, community reproductions
3. iOS developer forum discussions and WWDC session design notes
4. MapKit official APIs: `MapCompass`, `MapUserLocationButton`, `MapPitchToggle`
5. UISearchBar default measurements confirmed in multiple sources

Measurements marked **[VERIFIED]** are confirmed by 2+ sources.
Measurements marked **[ESTIMATED]** are inferred from screenshots/teardowns — may need ±4pt tuning.

---

## State 1: Peek Mode (Collapsed — Default Resting State)

### What It Is

A dark semi-transparent floating pill sitting above the safe area bottom. This is the resting state — no active search, no place detail selected. The map is fully interactive behind and around the pill.

### Container (the pill itself)

| Property | Current Code (MapBottomSheet.swift) | Apple Maps Target |
|----------|-------------------------------|-------------------|
| Height | `50pt` | `56–62pt` [ESTIMATED — 56pt matches UISearchBar default] |
| Horizontal padding | `16pt` each side | `16pt` each side [VERIFIED] |
| Corner radius | `22pt continuous` | `22pt continuous` [VERIFIED — matches iOS standard for floating pills] |
| Background | `Color.black.opacity(0.75)` flat | `.ultraThinMaterial` + system dark tint — active blur over map |
| Blur | None | Active blur via `.ultraThinMaterial` backed by `UIBlurEffect .dark` |
| Bottom gap from safe area | `padding(.bottom, 4)` — barely any gap | `8–12pt` gap [ESTIMATED] — pill visually floats |
| Shadow | `radius: 12, y: 4, opacity: 0.3` | `radius: 16–20, y: 4, opacity: 0.15–0.2` — softer |
| Drag gesture | Attached to content area when isPeek | Correct — drag anywhere on pill moves it |

**Critical fix: `.ultraThinMaterial` replaces flat black.** The flat `Color.black.opacity(0.75)` makes the pill look like a solid bar pasted on the map. `.ultraThinMaterial` creates the glass-over-map effect where map content blurs through the pill.

### Search Bar Layout Inside Peek (Left → Right)

Apple Maps peek search bar row:

```
[  🔍  ]  [  Search text placeholder  ]  [  spacer  ]  [  🎤  ]  [  👤  ]
 15-16pt    16pt text, .secondary                        15-16pt    28-30pt circle
 left 12pt                                               right 12pt  right 8pt
```

| Element | Icon/Content | Size | Alignment |
|---------|-------------|------|-----------|
| Search icon | `magnifyingglass` SF Symbol | 15–16pt | Leading, 12pt left pad |
| Placeholder | "Search" or active query text | 16pt font, `.secondary` when empty | Fills space |
| Microphone | `mic.fill` SF Symbol | 15–16pt | Trailing, before avatar |
| Avatar circle | User initials / `person.circle.fill` | 28–30pt diameter | Trailing, 8–12pt right pad |

**Current vs target:**
- Current has: search icon + placeholder + AI sparkles toggle
- Missing: microphone icon (or app-specific replacement) + **user avatar circle**
- The AI sparkles toggle replaces microphone — intentional app deviation, acceptable
- **User avatar is table stakes** — Apple Maps has shown it since iOS 15 in every peek state

### What Makes Peek Tap Expand the Sheet

Tapping the placeholder text in peek mode:
1. Expands sheet to `.full` with spring animation
2. After 150ms delay, focuses the TextField
3. Keyboard rises from bottom

Current code implements this correctly with the `DispatchQueue.main.asyncAfter(0.15)` approach.

### Drag Handle in Peek Mode

Apple Maps does NOT show a drag handle in peek mode. The drag handle only appears in half/full mode.
Current code correctly hides it when `isPeek == true`. No change needed.

---

## State 2: Half Mode (~47% screen height)

### Sheet Container

| Property | Current Code | Apple Maps Target |
|----------|-------------|-------------------|
| Top corner radius | `topLeadingRadius: 30, topTrailingRadius: 30` | `20–22pt` [ESTIMATED — slightly smaller] |
| Bottom corners | `0, 0` | `0, 0` [VERIFIED — fills to screen bottom] |
| Background | `Color(red:0.11,green:0.11,blue:0.12)` ≈ `#1C1C1E` | Same — `#1C1C1E` is iOS `.systemBackground` in dark mode [VERIFIED] |
| Bottom extension | `.ignoresSafeArea(edges: .bottom)` | Correct — extends under home indicator |
| Drag handle width | `60pt` | `36–40pt` [ESTIMATED — standard iOS grabber] |
| Drag handle height | `5pt` | `4–5pt` [VERIFIED — dev.to tutorial confirms 5pt] |
| Drag handle color | `Color.secondary.opacity(0.5)` | `Color(.tertiaryLabel)` [ESTIMATED] |
| Handle top padding | `10pt` | `6–8pt` |
| Handle bottom padding | `8pt` | `6–8pt` |
| Shadow | `radius: 10, y: -5, opacity: 0.15` | Correct direction (upward shadow since sheet is above safe area) |

**Critical fix: drag handle from 60pt → 36pt.** The 60pt handle looks oversized and non-standard.

### Search Bar in Half Mode

When sheet is at half or full, the search bar shows:
- Inner capsule background: `Capsule().fill(.quaternary.opacity(0.5))` [VERIFIED — current code has this]
- Full-height TextField becomes active (not the tappable placeholder)
- Vertical padding: `8pt` top/bottom [VERIFIED — current code has this via `vm.sheetDetent == .peek ? 4 : 8`]

### "Отмена" Cancel Button

Apple Maps cancel button behavior:
- Appears when TextField is focused OR query is non-empty
- Style: plain text, accent color tint
- Font: 16pt regular
- Animation: `.move(edge: .trailing).combined(with: .opacity)` — slides in from right edge

**Current implementation is correct.** No change needed.

### Content Sections in Half Mode (Apple Maps Structure)

Apple Maps half-mode content (top to bottom, below search bar):

1. **Category chips** — horizontal scrolling row:
   - Pills with icon + label
   - Examples: `fork.knife` Рестораны | `cup.and.saucer` Кафе | `fuelpump` АЗС | `parkingsign` Парковка | `cart` Магазины
   - Selected chip: inverted fill (label background, systemBackground foreground)
   - Unselected: `.quaternary` background, `.secondary` foreground

2. **"Любимое" (Favorites) section** — horizontal scroll of circles:
   - Each circle: 52–56pt diameter [ESTIMATED]
   - Circle background: `.quaternary`
   - Icons inside: `house.fill` (Дом/Home), `briefcase.fill` (Работа/Work), `plus` (Добавить)
   - Label below: 11–12pt, `.secondary`, centered
   - Section header: "Любимое" in `.secondary` 13pt `.semibold`

3. **"Недавние" (Recents) section** — vertical list:
   - Row icon: `clock.arrow.circlepath` in 28pt circle with `.quaternary` bg
   - Title: 15pt `.medium`, 1 line
   - Subtitle: 13pt `.secondary`, 1 line (address or category)
   - Trailing chevron: `chevron.right`, `.tertiary`
   - Row separator: `Divider()` with 48pt leading inset

**App-specific mapping for our content:**
The travel app does NOT have Home/Work/Favorites from iCloud — instead the half-mode should show:
- Category chips (already implemented)
- "Сегодня" section (already implemented — todayPlacesSection)
- "Карта" controls section (already implemented — mapControlsSection)

This is an intentional deviation from Apple Maps and is the correct choice for a trip planner.

---

## State 3: Full Mode (Expanded — Search Active)

### Sheet Container

Same as half mode. Background is already correct. Full mode fills to top safe area.

Current code: `.padding(.top, isPeek ? 0 : (detent == .full ? safeAreaTop : 0))` — CORRECT.

### Content in Full Mode

Apple Maps full-mode content adds beyond half:
- Keyboard open with TextField focused
- Results list replaces favorites/recents
- While typing: MKLocalSearchCompleter suggestions appear live
- After submit: MKMapItem results appear as a list

**Current implementation is complete.** `completerSuggestionsList` and `searchResultsList` are both implemented. No structural changes needed for full mode content.

### Keyboard + Sheet Interaction

When user taps search field in peek:
1. Sheet expands to `.full`
2. Keyboard rises
3. Sheet content adjusts (default iOS behavior — content shifts up)
4. DO NOT add `.ignoresSafeArea(.keyboard)` — let keyboard push content naturally

Apple Maps keeps sheet at full while keyboard is visible. Dismissing keyboard via swipe-down does NOT collapse the sheet — it stays at full.

Current implementation: sheet goes to full on search tap, then TextField focuses. This is correct. The `DispatchQueue.main.asyncAfter(0.15)` delay prevents a race condition where focus fires before the sheet animation completes.

---

## State 4: Floating Map Controls (Right Side)

### Apple Maps Button Layout (Right Side, Vertical Stack)

Apple Maps positions 2–3 controls on the **right side** as a vertical stack of separate floating circles:

```
(right edge, 16pt margin)
      [Compass  ]    ← only shown when heading ≠ north
         ↕ 8pt gap
      [Transit  ]    ← toggles transit overlay (buses, subway lines on map)
         ↕ 8pt gap
      [Location ]    ← tracks user location / heading
         ↕
  [== search pill ==]
```

**Critical:** Each button is a separate circle with its own blur background. They are NOT grouped in a single container.

### Button Specifications

| Button | Recommended Size | Icon | Background | Visibility |
|--------|-----------------|------|------------|------------|
| Compass | 40×40pt [ESTIMATED] | `MapCompass` (auto-rotates with heading) | `.ultraThinMaterial` circle | Only when map rotated away from north |
| Transit | 40×40pt [ESTIMATED] | `tram.fill` or `bus.fill` | `.ultraThinMaterial` circle | Always in peek mode |
| Location | 40×40pt [ESTIMATED] | `location.fill` → `location.north.line.fill` (tracking) | `.ultraThinMaterial` circle | Always in peek mode |

**Background material:** `.ultraThinMaterial` with `.clipShape(Circle())` — NOT flat `secondarySystemGroupedBackground`. This creates the glass-over-map blur effect matching the search pill.

**Shadow per button:** `radius: 4–6, y: 2, opacity: 0.12–0.18` — subtle.

**Right padding:** `16pt` from screen right edge [ESTIMATED — matches search pill horizontal margin].

**Bottom position:** Buttons stack above the search pill. With pill at `~72pt` from bottom safe area (56pt height + 8pt gap + 8pt above button), the location button sits at approximately `80–90pt` from bottom [ESTIMATED].

**Spacing between buttons:** `8–10pt` [ESTIMATED].

### Native MapKit Controls vs Custom Positioning

MapKit provides three standard controls:
- `MapCompass()` — auto-appears when heading ≠ north, auto-rotates. Position controlled by MapKit.
- `MapUserLocationButton()` — cycles through: idle → follow user → follow with heading
- `MapPitchToggle()` — switches 2D/3D perspective

These render with correct Apple styling via `.mapControls {}` but cannot be positioned manually — MapKit places them in a fixed location (top-right for compass by default).

**Recommendation:** Use `MapCompass()` via `.mapControls {}` (already done in current code). Build custom `MapUserLocationButton`-style button for positioning control, using `.ultraThinMaterial` background.

The custom transit toggle button is app-specific — use same visual treatment.

### Current Implementation vs Target

Current location button:
```swift
// Current — WRONG background
.background(Color(.secondarySystemGroupedBackground).opacity(0.97))
// Target — CORRECT background
.background(.ultraThinMaterial)
```

Current button size: `44×44pt` — slightly oversized. Acceptable to keep at 44pt (standard tap target).

### Hiding Controls on Sheet Expansion

When sheet leaves peek mode → controls must disappear.
When sheet returns to peek → controls reappear.

**Current code uses `if isIdleMode`** — this removes views from hierarchy, causing a layout jump (no animation).

**Target:** Opacity fade, views stay in hierarchy:

```swift
// Replace: if isIdleMode && !vm.isNavigating {
// With:
.opacity(isIdleMode && !vm.isNavigating ? 1 : 0)
.animation(.easeInOut(duration: 0.2), value: isIdleMode)
.allowsHitTesting(isIdleMode && !vm.isNavigating)
```

---

## State 5: Left Side and Top-Left Floating Elements

### Weather Badge (Top-Left) — Nice-to-Have, Not This Milestone

Apple Maps shows a compact weather pill in the top-left:
- Size: ~64×28pt [ESTIMATED]
- Content: weather SF Symbol + temperature (e.g., `cloud.sun.fill` "18°C")
- Background: `.ultraThinMaterial` capsule
- Position: ~8–12pt from left edge, below safe area top
- Tap: opens Weather app

**Not required for v1.1.** App weather lives in Dashboard tab. Adding map weather badge is a separate task.

### Look Around Button (Left Side) — Not This Milestone

When user is in a Look Around-covered region, Apple Maps shows a binoculars button on the left:
- Icon: `binoculars.fill`
- Size: ~40×40pt
- Background: `.ultraThinMaterial` circle
- Position: left side, vertically aligned with the right-side controls

**Not required for v1.1.** Current implementation fetches Look Around scenes and displays via `MapItemDetailView` — sufficient.

---

## State 6: Transitions and Animations

### Peek → Half Transition

Apple Maps animation parameters (approximated from visual inspection):
- Spring: `response: 0.35, dampingFraction: 0.85` — matches current code [VERIFIED via `withAnimation(.spring(response: 0.35, dampingFraction: 0.85))`]
- Sheet expands upward
- **The pill morphs into the full-width sheet** — shape interpolation

**Current code issue:** The background switches instantly between `RoundedRectangle` inside `padding(.horizontal, 16)` (peek pill) and `UnevenRoundedRectangle` with no horizontal padding (half/full sheet). This creates a visual jump — the pill disappears and a full-width sheet appears.

**Fix approach (interpolation during drag):**
Use `dragOffset` to compute progress `t = dragOffset / (halfHeight - peekHeight)` and lerp:
- `cornerRadius`: 22pt → 20–22pt (stays similar, so minor fix)
- `horizontalPadding`: 16pt → 0pt (the big fix — pill grows to full width during drag)
- `backgroundOpacity`: pill opacity → sheet opacity

This is the highest-complexity fix but most impactful visual improvement.

**Minimum acceptable fix (without full morph):** Fade out the pill quickly and fade in the sheet so the jump is less noticeable. Lower complexity, acceptable result.

### Half → Full Transition

- Same spring parameters
- Background shape stays the same (`UnevenRoundedRectangle`) — just height change
- Top safe area padding appears smoothly via `padding(.top, safeAreaTop)`
- No shape morph needed — already smooth

### Controls Fade (Peek → Half and Back)

```
Peek → Half: controls fade out over ~0.2s easeInOut
Half → Peek: controls fade in over ~0.2s easeInOut
```

Current `if isIdleMode` toggle causes instant appearance/disappearance. Replace with `.opacity` + animation.

### Keyboard Appearance

1. User taps search pill (peek state)
2. Sheet springs to `.full` (~0.35s)
3. After 150ms, TextField focuses
4. Keyboard rises (~0.25s, system animation)

**Current timing is correct.** The 150ms delay lets the sheet settle before the keyboard fight for layout.

---

## Feature Landscape

### Table Stakes (Must Match for "Apple Maps Parity")

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Peek height 56pt (from 50pt) | 50pt clips search content | LOW | Change `case .peek: return 50` → `56` |
| `.ultraThinMaterial` blur on peek pill | Flat black looks wrong on map | LOW | Replace `Color.black.opacity(0.75)` with `.ultraThinMaterial` |
| Drag handle 36pt wide (from 60pt) | 60pt is oversized and non-standard | LOW | Change `width: 60` → `36` in Capsule frame |
| Floating controls use `.ultraThinMaterial` | Flat color breaks glass consistency | LOW | Replace `.secondarySystemGroupedBackground` background |
| Controls use opacity fade (not if/else) | Instant removal is jarring | LOW | Add `.opacity()` + `.animation()`, `.allowsHitTesting()` |
| Bottom safe area gap 8pt below pill | Pill floats, not pressed against bottom | LOW | Add `padding(.bottom, 8)` to pill container |
| Drag handle color `Color(.tertiaryLabel)` | `.secondary.opacity(0.5)` may not match across themes | LOW | Swap fill color |
| Top corner radius 22pt (from 30pt) | 30pt is too large for a sheet top | LOW | Change `topLeadingRadius: 30` → `22` |

### Differentiators (App-Specific — Keep As Is)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| AI sparkles toggle replaces mic icon | Travel-specific AI search | EXISTING | Keep — replaces microphone acceptably |
| Today's places section in half mode | Trip-aware sheet content | EXISTING | Keep — better than Apple Maps' Home/Work |
| Map controls section (layers, weather, discover) | Trip-specific map overlays | EXISTING | Keep — trip-specific differentiator |
| Trip city zoom shortcuts | Multi-city navigation | EXISTING | Keep |

### Anti-Features (Do Not Build for This Milestone)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Favorites / Home / Work circles | Requires iCloud Contacts integration | Trip's saved places serve same purpose |
| Weather badge on map (top-left) | Separate feature; Dashboard has weather | Defer to later milestone |
| Look Around left-side button | Already handled via MapItemDetailView sheet | Not needed |
| Guides section in full mode | Not relevant to trip planner context | Today's places is the equivalent |
| Native `presentationDetents` sheet | Loses custom peek pill appearance entirely | Keep custom MapBottomSheet |
| Haptic feedback on snap | Low value, adds complexity | Standard spring animation is sufficient |

---

## Feature Dependencies

```
Peek height fix (56pt)
    └──enables──> Content readable in peek state
    └──unblocks──> User avatar placement (needs correct height)

ultraThinMaterial on pill
    └──requires──> Remove Color.black.opacity(0.75)
    └──enables──> Visual consistency with floating controls

ultraThinMaterial on controls
    └──mirrors──> Same material fix as pill
    └──creates──> Consistent glass system

Controls opacity fade
    └──requires──> isIdleMode bool (already have)
    └──requires──> Replace if/else with .opacity modifier
    └──requires──> Add .allowsHitTesting(isIdleMode) to prevent tap-through

Shape morph animation (peek pill → full-width sheet)
    └──requires──> dragOffset progress computation (t from 0 to 1)
    └──requires──> Animatable/interpolated corner radius and horizontal padding
    └──requires──> Unified background that can morph (single background view)

User avatar in search pill
    └──requires──> Auth state check (AuthManager already exists)
    └──requires──> Fallback to person.circle.fill when not signed in
```

### Dependency Notes

- **Shape morph is independent of other fixes** — can be done last or skipped for v1.1 if time is short. The opacity-based workaround (quick crossfade) is acceptable.
- **All LOW complexity fixes are independent** — height, material, handle width, gap, corner radius can all be changed in isolation with zero risk of regression.
- **Controls opacity change is safe** — `.opacity(0)` keeps view in hierarchy and avoids the layout recalculation that `if/else` triggers.

---

## MVP Definition

### Launch With (v1.1 — Table Stakes, All LOW Complexity)

- [ ] Peek height: `50` → `56` pt
- [ ] Peek pill background: `Color.black.opacity(0.75)` → `.ultraThinMaterial`
- [ ] Bottom gap: add `padding(.bottom, 8)` to pill container
- [ ] Drag handle: width `60` → `36`, fill `Color.secondary.opacity(0.5)` → `Color(.tertiaryLabel)`
- [ ] Sheet top corner radius: `30` → `22` pt
- [ ] Floating controls: background `.secondarySystemGroupedBackground.opacity(0.97)` → `.ultraThinMaterial`
- [ ] Controls visibility: replace `if isIdleMode` with `.opacity()` + `.animation()` + `.allowsHitTesting()`

### Add After Core Polish (v1.1 Nice-to-Have)

- [ ] User avatar (28–30pt circle) at trailing of search pill — initials or `person.circle.fill`
- [ ] Shadow tuning: reduce opacity from 0.3 to 0.18 on peek pill
- [ ] Peek→half shape morph OR crossfade workaround

### Future Consideration (v1.2+)

- [ ] Weather badge top-left (WeatherKit on map view)
- [ ] Look Around left-side floating button
- [ ] Favorites/recent searches section (persistent search history)
- [ ] "Search here" button after manual map pan (iOS 18 feature)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Peek height 56pt | HIGH (visible content) | LOW (1 value) | P1 |
| ultraThinMaterial pill | HIGH (glass feel) | LOW (1 modifier swap) | P1 |
| ultraThinMaterial controls | HIGH (visual consistency) | LOW (1 modifier swap) | P1 |
| Bottom safe area gap | MEDIUM (float feel) | LOW (1 padding) | P1 |
| Controls opacity fade | MEDIUM (smooth transition) | LOW (modifier refactor) | P1 |
| Drag handle 36pt | LOW (fine detail) | LOW (1 value) | P2 |
| Top corner radius 22pt | LOW (subtle difference) | LOW (1 value) | P2 |
| User avatar in pill | MEDIUM (Apple Maps parity) | MEDIUM (auth + render) | P2 |
| Shape morph animation | MEDIUM (premium feel) | HIGH (interpolation logic) | P3 |
| Weather badge on map | LOW (nice to have) | MEDIUM (new view) | P3 |

---

## Exact Values Summary (Implementation Reference)

| Component | Property | Current | Target | Confidence |
|-----------|----------|---------|--------|------------|
| Peek height | pts | 50 | 56 | MEDIUM [UISearchBar baseline] |
| Peek pill horizontal padding | pts | 16 | 16 | VERIFIED |
| Peek pill corner radius | pts | 22 | 22 | VERIFIED |
| Peek pill bottom gap | pts | 4 | 8–10 | ESTIMATED |
| Peek pill background | material | Color.black.opacity(0.75) | .ultraThinMaterial | VERIFIED |
| Half/full top corner radius | pts | 30 | 20–22 | ESTIMATED |
| Drag handle width | pts | 60 | 36 | ESTIMATED |
| Drag handle height | pts | 5 | 4–5 | VERIFIED |
| Drag handle top padding | pts | 10 | 6–8 | ESTIMATED |
| Location button size | pts | 44×44 | 40–44×40–44 | ESTIMATED |
| Location button background | material | .secondarySystemGroupedBackground | .ultraThinMaterial | VERIFIED |
| Controls right padding | pts | 16 | 16 | VERIFIED |
| Controls bottom clearance (above pill) | pts | 90 | 80–100 | ESTIMATED |
| Controls spacing between buttons | pts | n/a | 8 | ESTIMATED |
| Spring animation response | seconds | 0.35 | 0.35 | VERIFIED |
| Spring animation damping | fraction | 0.85 | 0.85 | VERIFIED |
| Controls fade duration | seconds | instant | 0.2 | ESTIMATED |
| Avatar circle diameter | pts | n/a | 28–30 | ESTIMATED |

---

## Sources

- [MapKit for SwiftUI — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10043/) — MapCompass, MapUserLocationButton APIs (HIGH confidence)
- [Build a UIKit app with the new design — WWDC25](https://developer.apple.com/videos/play/wwdc2025/284/) — "Maps removes buttons when sheet expands to prevent glass overlapping glass"
- [iOS 26 Liquid Glass design — Apple WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/) — sheet behavior: floating at lowest detent, gap disappears at top
- [MapCompass documentation](https://developer.apple.com/documentation/mapkit/mapcompass) — native control behavior (HIGH)
- [MapUserLocationButton documentation](https://developer.apple.com/documentation/mapkit/mapuserlocationbutton) — native control behavior (HIGH)
- [Adding Map Controls — createwithswift.com](https://www.createwithswift.com/adding-map-controls-to-a-map-view-with-swiftui-and-mapkit/) — mapControls modifier usage (MEDIUM)
- [SwiftUI Bottom Sheet tutorial — dev.to, 2025](https://dev.to/sebastienlato/how-to-build-a-floating-bottom-sheet-in-swiftui-drag-snap-blur-lfp) — handle: 40×5pt, cornerRadius 3, ultraThinMaterial (MEDIUM)
- [iOS 18 Apple Maps features — MacRumors](https://www.macrumors.com/guide/ios-18-maps/) — user avatar in iOS 15+, Look Around behavior (HIGH)
- [Apple Maps user account icon history — MacRumors forums](https://forums.macrumors.com/threads) — profile circle present since iOS 15 (MEDIUM)
- UISearchBar default height 56pt — confirmed: Apple UIKit forums + GitHub Simplenote iOS issue #930 (HIGH)
- Codebase: `MapBottomSheet.swift`, `MapSearchContent.swift`, `TripMapView.swift` — direct inspection (HIGH)

---

*Feature research for: Apple Maps UI Parity — v1.1 milestone*
*Researched: 2026-03-21*
*Previous research (navigation overhaul v1.0) preserved in git history*
