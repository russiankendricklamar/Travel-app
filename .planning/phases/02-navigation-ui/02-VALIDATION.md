---
phase: 2
slug: navigation-ui
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode Build (swiftc) + manual device testing |
| **Config file** | Travel app.xcodeproj |
| **Quick run command** | `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" 2>&1 \| tail -5` |
| **Full suite command** | `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" 2>&1 \| tail -20` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick build command
- **After every plan wave:** Run full build + manual UI smoke test
- **Before `/gsd:verify-work`:** Full build green + all manual verifications passed
- **Max feedback latency:** 30 seconds (build)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | UI-01 | build + manual | `grep "NavigationHUDView" Travel\ app/Views/Map/NavigationHUDView.swift` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | UI-02 | build + manual | `grep "maneuverIcon\|instructionText\|distanceRemaining" Travel\ app/Views/Map/NavigationHUDView.swift` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | UI-03 | build + manual | `grep "MapCameraPosition\|headingLock\|followUser" Travel\ app/Views/Map/TripMapView.swift` | ✅ | ⬜ pending |
| 02-02-01 | 02 | 1 | UI-04 | build + manual | `grep "NavigationSheetContent\|navigationDetent" Travel\ app/Views/Map/` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 1 | NAV-06 | build + manual | `grep "День.*из.*—" Travel\ app/Views/Map/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Travel app/Views/Map/NavigationHUDView.swift` — new file for HUD overlay
- [ ] `Travel app/Views/Map/NavigationSheetContent.swift` — new file for navigation sheet mode
- [ ] Build must compile clean before execution begins

*No test framework to install — verification is build success + manual UI testing on device.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| HUD shows next maneuver with SF Symbol icon | UI-01, UI-02 | Visual overlay positioning requires device | 1. Start navigation on a route 2. Verify HUD appears below Dynamic Island 3. Verify icon + text + distance shown |
| HUD urgency color at <50m | UI-02 | GPS proximity behavior | 1. Walk toward next step endpoint 2. At <50m verify accent color change |
| Map camera follows with heading lock | UI-03 | MapKit camera behavior | 1. Start navigation 2. Walk/drive 3. Verify map rotates with heading |
| Bottom sheet collapses to navigation detent | UI-04 | Sheet interaction | 1. Start navigation 2. Verify sheet collapses 3. Expand to see full step list |
| Trip context label visible | NAV-06 | Visual layout | 1. Start navigation 2. Verify "День X из Y — City" in sheet |
| Start/Stop navigation flow | UI-01 | User interaction flow | 1. Tap "НАЧАТЬ НАВИГАЦИЮ" 2. Verify navigation starts 3. Tap X or "Завершить" 4. Verify return to route info |

*All phase behaviors require manual device verification — this is a UI-heavy phase with no automated test target configured.*

---

## Validation Sign-Off

- [x] All tasks have automated verify (build) or Wave 0 dependencies
- [x] Sampling continuity: build check after every task
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
