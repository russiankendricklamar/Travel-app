---
phase: 02-navigation-ui
verified: 2026-03-20T09:00:00Z
status: human_needed
score: 11/11 must-haves verified
human_verification:
  - test: "Start navigation from route info sheet — verify full flow on device"
    expected: "Tapping 'НАЧАТЬ НАВИГАЦИЮ' shows floating HUD at top, camera locks to user position with heading rotation, sheet collapses to peek with navigation strip showing direction icon + instruction + ETA + trip context"
    why_human: "Camera heading lock (.userLocation(followsHeading:true)) and live GPS behavior cannot be verified programmatically"
  - test: "Expand navigation sheet to half/full"
    expected: "Step list renders with current step highlighted (pink 4pt accent bar + bold text), 'Завершить навигацию' button at bottom"
    why_human: "Visual rendering of step list and accent bar requires screen inspection"
  - test: "Collapse sheet to peek during navigation"
    expected: "Navigation continues — HUD remains visible, sheetContent stays .navigation, no reset occurs"
    why_human: "Sheet detent interaction with dismiss guard requires real SwiftUI runtime to observe"
  - test: "Pan map manually during navigation"
    expected: "Pink 'Вернуться' capsule button appears above sheet; tapping it re-centers map with heading lock and button disappears"
    why_human: "onMapCameraChange distance calculation requires live location and real map rendering"
  - test: "Stop navigation via HUD X button and via sheet 'Завершить навигацию' button"
    expected: "HUD disappears with slide-up animation, camera returns to .automatic, sheet returns to .routeInfo at .half"
    why_human: "Animation and camera restoration require real SwiftUI runtime"
  - test: "Urgency styling: approach within 50m of next step"
    expected: "HUD icon background turns solid sakuraPink, icon turns white, distance text turns sakuraPink; deactivates when > 65m"
    why_human: "Hysteresis behavior requires live GPS distance updates; cannot simulate in static analysis"
---

# Phase 02: Navigation UI Verification Report

**Phase Goal:** User sees a floating HUD with the next maneuver, can start/stop navigation, and the map follows their position with heading lock
**Verified:** 2026-03-20T09:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | NavigationHUDView renders direction icon, instruction text, and distance for the current step | VERIFIED | NavigationHUDView.swift:20-69 — HStack with 52x52 icon ZStack, VStack with instruction + `RoutingService.formatDistance(vm.distanceToNextStep)`, dismiss button |
| 2 | HUD urgency state activates when distance < 50m with hysteresis (deactivates > 65m) | VERIFIED | MapViewModel.swift:472-473 — `if distance < 50 { self?.isUrgent = true } else if distance > 65 { self?.isUrgent = false }` |
| 3 | MapRecenterButton appears as sakuraPink capsule with location.fill icon and 'Вернуться' label | VERIFIED | MapRecenterButton.swift:11-20 — `Capsule().fill(AppTheme.sakuraPink)` with `location.fill` + `Text("Вернуться")` |
| 4 | NavigationSheetContent shows peek row (icon + instruction + ETA + trip context) and expanded step list | VERIFIED | NavigationSheetContent.swift:25-57 (peek), 61-94 (expanded) — peek has tripContextLabel + etaString; expanded has ForEach over navigationSteps with StepRow |
| 5 | 'НАЧАТЬ НАВИГАЦИЮ' button exists at bottom of MapRouteContent with solid sakuraPink fill | VERIFIED | MapRouteContent.swift:50-69 — `Task { await vm.startNavigation() }`, `.fill(AppTheme.sakuraPink)`, `.disabled(vm.navigationSteps.isEmpty && vm.isCalculatingRoute)` |
| 6 | MapViewModel has isUrgent, isOffNavCenter properties and recenterNavigation() method | VERIFIED | MapViewModel.swift:89-91 (`var isUrgent`, `var isOffNavCenter`), 542-545 (`recenterNavigation()`) |
| 7 | HUD appears at top of screen when vm.isNavigating is true and hides when false | VERIFIED | TripMapView.swift:73-81 — `if vm.isNavigating { VStack { NavigationHUDView(vm: vm) ... } }` with `.animation(.easeInOut, value: vm.isNavigating)` |
| 8 | Recenter button appears when user pans away during navigation (isOffNavCenter) | VERIFIED | TripMapView.swift:85-93 — `if vm.isNavigating && vm.isOffNavCenter { MapRecenterButton { vm.recenterNavigation() } }` |
| 9 | Bottom sheet shows NavigationSheetContent when sheetContent == .navigation | VERIFIED | TripMapView.swift:335-336 — `case .navigation: NavigationSheetContent(vm: vm)` |
| 10 | Swiping sheet to peek during navigation does NOT call dismissDetail() | VERIFIED | TripMapView.swift:172 — `if newDetent == .peek && oldDetent != .peek && !vm.isNavigating` |
| 11 | Manual pan detection sets isOffNavCenter when camera diverges > 50m from user location | VERIFIED | TripMapView.swift:312-319 — `onMapCameraChange` computes `CLLocation.distance`, sets `vm.isOffNavCenter = distance > 50` |

**Score:** 11/11 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Travel app/Views/Map/NavigationHUDView.swift` | Floating maneuver card with direction icon, instruction, distance, dismiss button | VERIFIED | 92 lines, `struct NavigationHUDView: View`, `@Bindable var vm: MapViewModel`, glassmorphism styling, `static func iconForInstruction` |
| `Travel app/Views/Map/MapRecenterButton.swift` | Recenter capsule button for manual pan recovery | VERIFIED | 24 lines, `struct MapRecenterButton: View`, sakuraPink capsule, shadow, `.transition(.scale.combined(with: .opacity))` |
| `Travel app/Views/Map/NavigationSheetContent.swift` | Navigation sheet body with peek and expanded layouts | VERIFIED | 131 lines, `struct NavigationSheetContent: View`, peek/expanded switch, StepRow, stop button |
| `Travel app/Views/Map/MapRouteContent.swift` | Start navigation button added at bottom | VERIFIED | Lines 50-69 — `НАЧАТЬ НАВИГАЦИЮ` button with sakuraPink fill, `Task { await vm.startNavigation() }`, disabled guard |
| `Travel app/Views/Map/MapViewModel.swift` | Navigation UI state properties and camera transitions | VERIFIED | `isUrgent`/`isOffNavCenter` (lines 89-91), `recenterNavigation()` (542-545), `tripContextLabel` (147), `etaString` (158), `case navigation` in enum (13), camera transitions in `startNavigation()` (489-495) and `stopNavigation()` (522-532) |
| `Travel app/Views/Map/TripMapView.swift` | Full navigation UI wiring: HUD, recenter, sheet case, dismiss guard, pan detection | VERIFIED | HUD overlay (73-81), recenter button (85-93), `.navigation` sheet case (335-336), dismiss guard (172), pan detection (312-319) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| NavigationHUDView | MapViewModel | `@Bindable var vm` | WIRED | Accesses `vm.currentStepIndex`, `vm.distanceToNextStep`, `vm.isUrgent`, `vm.stopNavigation()` |
| NavigationSheetContent | MapViewModel | `@Bindable var vm` | WIRED | Accesses `vm.navigationSteps`, `vm.currentStepIndex`, `vm.tripContextLabel`, `vm.etaString`, `vm.sheetDetent`, `vm.stopNavigation()` |
| MapRouteContent | MapViewModel.startNavigation() | `Task { await vm.startNavigation() }` | WIRED | Button label contains `НАЧАТЬ НАВИГАЦИЮ`, action dispatches async start |
| TripMapView ZStack | NavigationHUDView | `if vm.isNavigating { VStack { NavigationHUDView(vm: vm) } }` | WIRED | Conditional shown on `vm.isNavigating` with slide-from-top animation |
| TripMapView ZStack | MapRecenterButton | `if vm.isNavigating && vm.isOffNavCenter { MapRecenterButton }` | WIRED | Double-condition guard, calls `vm.recenterNavigation()` |
| TripMapView sheetBody | NavigationSheetContent | `case .navigation: NavigationSheetContent(vm: vm)` | WIRED | Exhaustive switch, navigation case wired to correct component |
| TripMapView onChange(of: sheetDetent) | dismissDetail guard | `&& !vm.isNavigating` | WIRED | Guard prevents dismiss during active navigation |
| TripMapView onMapCameraChange | vm.isOffNavCenter | `distance > 50` from user location | WIRED | `CLLocation.distance` computed, `vm.isOffNavCenter = distance > 50` set |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| UI-01 | 02-01-PLAN.md | NavigationHUD — floating карточка следующего манёвра с расстоянием и иконкой направления | SATISFIED | NavigationHUDView.swift — full implementation with glassmorphism, direction icon, instruction, distance |
| UI-02 | 02-02-PLAN.md | Навигационный detent (.small/peek) в bottom sheet при активной навигации | SATISFIED | MapViewModel.swift:494-495 `sheetContent = .navigation; sheetDetent = .peek` on startNavigation |
| UI-03 | 02-02-PLAN.md | Контекст поездки в навигации — "День 2 из 7 — Токио" | SATISFIED | `vm.tripContextLabel` computed property (MapViewModel.swift:147-157), displayed in NavigationSheetContent peek (line 38) |
| UI-04 | 02-01-PLAN.md, 02-02-PLAN.md | Glassmorphism стиль для всех новых навигационных компонентов | SATISFIED | NavigationHUDView uses `.ultraThinMaterial` + stroke + shadow; MapRecenterButton uses `Capsule().fill(AppTheme.sakuraPink)` + shadow; NavigationSheetContent uses AppTheme.radiusMedium rounded button |
| NAV-06 | 02-01-PLAN.md | Кнопка "Начать навигацию" в UI маршрута | SATISFIED | MapRouteContent.swift:50-69 — `НАЧАТЬ НАВИГАЦИЮ` button with sakuraPink fill |

All 5 requirement IDs satisfied. No orphaned requirements — REQUIREMENTS.md maps all 5 to Phase 2 and marks them Complete.

### Anti-Patterns Found

None. No TODOs, FIXMEs, placeholders, empty return stubs, or print() statements found in any of the 6 files modified by this phase.

### Human Verification Required

#### 1. Start Navigation Full Flow

**Test:** Open a trip, tap Map tab, tap a place to get a route, tap "НАЧАТЬ НАВИГАЦИЮ"
**Expected:** Floating HUD card appears at top of screen with direction icon, current instruction, and distance. Map camera locks to user position with heading rotation. Bottom sheet collapses to peek showing compact strip: direction icon + instruction + ETA + "День N из M — Город" context label.
**Why human:** Camera heading lock via `.userLocation(followsHeading: true)` and live GPS tracking cannot be verified through static code analysis. Real CoreLocation updates needed.

#### 2. Navigation Sheet Peek Does Not Reset

**Test:** While navigating, drag the bottom sheet down to peek height
**Expected:** Navigation continues — HUD visible, sheetContent stays `.navigation`, no `dismissDetail()` called, trip context still shown
**Why human:** SwiftUI sheet detent gesture behavior and the guard condition (`!vm.isNavigating`) interaction requires real SwiftUI runtime to observe.

#### 3. Manual Pan Recenter Button

**Test:** While navigating, manually pan the map more than 50m away from current location
**Expected:** Pink "Вернуться" capsule appears above the sheet. Tapping it re-centers map with heading lock and the button disappears.
**Why human:** `onMapCameraChange` distance calculation requires live location + real map rendering; cannot simulate in static analysis.

#### 4. Navigation Stop and Return

**Test:** Stop navigation via HUD X button, then separately via "Завершить навигацию" in expanded sheet
**Expected:** Both paths — HUD disappears, camera returns to normal (non-heading-locked), sheet switches to `.routeInfo` at `.half`
**Why human:** Animation sequencing and camera state restoration require SwiftUI runtime execution.

#### 5. Urgency Styling Hysteresis

**Test:** Navigate toward a turn; observe HUD styling as you approach within 50m, then move back beyond 65m
**Expected:** Below 50m: icon background becomes solid sakuraPink, icon turns white, distance text turns sakuraPink. Above 65m: reverts to outlined/secondary style. No flickering at boundary.
**Why human:** Requires live GPS distance progression; hysteresis logic verified in code but runtime behavior must be confirmed.

### Gaps Summary

No gaps found. All 11 observable truths are verified against the actual codebase. All 5 artifacts exist, are substantive (no stubs), and are fully wired. All 5 requirements are satisfied. All 8 key links are confirmed wired.

The remaining items are human verification tasks for runtime/visual behavior that cannot be validated through static code analysis. The automated portion of goal verification is complete.

---

_Verified: 2026-03-20T09:00:00Z_
_Verifier: Claude (gsd-verifier)_
