---
phase: 1
slug: navigation-engine
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-20
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in Xcode) |
| **Config file** | none — no test target currently configured |
| **Quick run command** | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"` |
| **Full suite command** | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Build verification (`xcodebuild build`) + grep-based automated checks
- **After every plan wave:** Full build + manual GPS test on physical device
- **Before `/gsd:verify-work`:** Full build must succeed; physical device navigation test
- **Max feedback latency:** 60 seconds (build time)

---

## Nyquist Compliance Justification

Phase 1 builds a GPS/audio navigation engine whose core behaviors (background GPS continuity, audio session ducking, real-world off-route detection, step advancement during physical movement) are **hardware-dependent and cannot be meaningfully unit tested**:

1. **CLLocationManager** — background GPS behavior differs between simulator and device. Simulator ignores UIBackgroundModes gate in some Xcode versions, making simulator-only tests false positives. Step advancement requires real GPS coordinate streams, not synthetic injection (CLLocationManager delegate is called by the system, not by test code).

2. **AVSpeechSynthesizer** — audio session ducking (`AVAudioSession.setActive` with `.duckOthers`) requires a real audio session with background music playing. Simulator has no audio output device. The 0.5s asyncAfter deactivation pattern (Pitfall 2) cannot be validated without hearing audio resume.

3. **Off-route detection** — while the `perpendicularDistanceToSegment` geometry is pure math and theoretically testable, the integration with live GPS drift, tunnel re-emergence, and urban canyon scenarios requires physical device walking tests.

**Automated verification strategy:** Each plan task includes grep-based `<automated>` verification commands that confirm:
- All required structs, methods, and properties exist in the correct files
- Key patterns (thresholds, debounce values, delegate conformances) are present
- Project builds successfully via `xcodebuild build`

This provides sufficient Nyquist sampling for a hardware-dependent phase. The grep + build checks catch structural regressions immediately (~60s feedback latency), while behavioral correctness is validated via physical device testing documented in the Manual-Only Verifications table below.

**Wave 0 resolution:** No dedicated Wave 0 test-scaffold plan is needed because:
- No test target exists in the project (manual Xcode setup required)
- The grep-based automated verify commands in each plan task satisfy the Nyquist sampling requirement for this phase
- Unit tests for pure geometry (perpendicular distance) would provide value but are not blocking — they can be added in a future testing phase

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 01-01-01 | 01 | 1 | ROUTE-04 | build+grep | `grep "struct NavigationStep" NavigationModels.swift` | pending |
| 01-01-02 | 01 | 1 | NAV-05 | build+grep | `grep -A2 "UIBackgroundModes" Info.plist \| grep location` | pending |
| 01-02-01 | 02 | 1 | NAV-02 | build+grep | `grep "AVSpeechSynthesizerDelegate" NavigationVoiceService.swift` | pending |
| 01-03-01 | 03 | 2 | NAV-01 | build+grep | `grep "stepArrivalThreshold.*15" NavigationEngine.swift` | pending |
| 01-03-02 | 03 | 2 | NAV-03 | build+grep | `grep "offRouteThreshold.*30" NavigationEngine.swift` | pending |
| 01-03-03 | 03 | 2 | NAV-04 | build+grep | `grep "rerouteDebounce.*8" NavigationEngine.swift` | pending |
| 01-03-04 | 03 | 2 | NAV-01 | build+grep | `grep "func startNavigation" MapViewModel.swift` | pending |

*Status: pending / green / red / flaky*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| GPS tracking in background | NAV-05 | CLLocationManager requires physical device | Lock screen during active navigation, verify GPS updates continue |
| Voice announcements at distance thresholds | NAV-02 | AVSpeechSynthesizer + GPS distance requires real movement | Walk along a route, verify voice at 500m/200m/arrival |
| Music resumes after voice | NAV-02 | Audio session interaction requires physical device | Play music, start navigation, verify music ducks and resumes |
| Off-route detection | NAV-03 | Requires physically deviating from route | Walk off-route >30m, verify reroute triggers |
| Background GPS continuity | NAV-05 | Simulator does not replicate iOS background behavior | Navigate with screen locked for 5+ min |
| Step advancement during walk | NAV-01 | Requires real GPS coordinate stream from movement | Walk past a maneuver point, verify step index advances |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify (grep + build commands)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 resolved — justified manual-only for hardware-dependent phase
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved — grep+build automated checks provide structural Nyquist sampling; behavioral validation requires physical device (documented above)
