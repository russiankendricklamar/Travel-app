---
phase: 3
slug: route-selection
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) |
| **Config file** | Travel appTests/ (test target) |
| **Quick run command** | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -only-testing:TravelAppTests` |
| **Full suite command** | `xcodebuild test -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Build verification (`xcodebuild build`)
- **After every plan wave:** Full build + manual smoke test
- **Before `/gsd:verify-work`:** Full build must succeed
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | ROUTE-01 | build | `xcodebuild build` | ✅ | ⬜ pending |
| 03-01-02 | 01 | 1 | ROUTE-01 | build | `xcodebuild build` | ✅ | ⬜ pending |
| 03-01-03 | 01 | 1 | ROUTE-02 | build | `xcodebuild build` | ✅ | ⬜ pending |
| 03-01-04 | 01 | 1 | ROUTE-03 | manual | visual verification | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework or stubs needed — verification is build-based + manual UI smoke testing.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 2-3 alternative route cards shown | ROUTE-01 | Requires live Google Routes API response | Request route → verify carousel shows multiple cards |
| Transport mode switching updates ETA | ROUTE-02 | Requires live API + visual verification | Tap each mode pill → verify cards update with new ETAs |
| Selecting route updates polyline | ROUTE-03 | Requires MapKit visual rendering | Tap different card → verify map polyline changes |
| Badge assignment (Быстрый/Короткий) | ROUTE-01 | Requires multiple routes with different metrics | Request route with alternatives → verify correct badge |
| Skeleton loading state | ROUTE-01 | Animation requires visual verification | Slow network → verify shimmer cards appear |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
