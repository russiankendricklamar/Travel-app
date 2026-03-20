---
phase: 1
slug: navigation-engine
status: draft
nyquist_compliant: false
wave_0_complete: false
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

- **After every task commit:** Build verification (`xcodebuild build`)
- **After every plan wave:** Full build + manual GPS test on physical device
- **Before `/gsd:verify-work`:** Full build must succeed; physical device navigation test
- **Max feedback latency:** 60 seconds (build time)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | NAV-01 | manual | Physical device GPS tracking | N/A | ⬜ pending |
| 01-01-02 | 01 | 1 | NAV-03 | manual | Physical device off-route detection | N/A | ⬜ pending |
| 01-01-03 | 01 | 1 | NAV-04 | unit | Debounce timer logic verification | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | NAV-02 | manual | Physical device voice playback | N/A | ⬜ pending |
| 01-02-02 | 02 | 1 | NAV-05 | manual | Background GPS with screen locked | N/A | ⬜ pending |
| 01-01-04 | 01 | 1 | ROUTE-04 | build | `grep "MKRouteStep" NavigationEngine.swift` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Test target setup in Xcode (manual step — not automatable)
- [ ] Verify `UIBackgroundModes: [location]` in Info.plist (manual Xcode step)

*Note: NavigationEngine and VoiceService are heavily dependent on CLLocationManager and AVSpeechSynthesizer — both require physical device for meaningful testing. Unit tests limited to debounce logic and state machine transitions.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| GPS tracking in background | NAV-05 | CLLocationManager requires physical device | Lock screen during active navigation, verify GPS updates continue |
| Voice announcements at distance thresholds | NAV-02 | AVSpeechSynthesizer + GPS distance requires real movement | Walk along a route, verify voice at 500m/200m/arrival |
| Music resumes after voice | NAV-02 | Audio session interaction requires physical device | Play music → start navigation → verify music ducks and resumes |
| Off-route detection | NAV-03 | Requires physically deviating from route | Walk off-route >30m, verify reroute triggers |
| Background GPS continuity | NAV-05 | Simulator does not replicate iOS background behavior | Navigate with screen locked for 5+ min |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
