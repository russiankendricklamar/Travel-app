---
phase: 8
slug: search-bar-handle
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode Build Verification (xcodebuild) |
| **Config file** | Travel app.xcodeproj |
| **Quick run command** | `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -quiet` |
| **Full suite command** | `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -quiet` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick build command
- **After every plan wave:** Run full build command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | HNDL-01..03 | build+visual | `xcodebuild build` | ✅ | ⬜ pending |
| 08-01-02 | 01 | 1 | SRCH-01..05 | build+visual | `xcodebuild build` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements — xcodebuild is already configured.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Search bar 17pt icon + font proportions | SRCH-01 | Visual proportion check | Side-by-side with Apple Maps |
| RoundedRectangle(10) vs Capsule shape | SRCH-03 | Visual shape check | Verify field corners are 10pt radius, not fully rounded |
| Placeholder color white.opacity(0.5) | SRCH-01 | Visual color check | Verify placeholder is lighter than .secondary |
| Cancel button slide-in animation | SRCH-05 | Animation quality check | Focus field, verify "Отмена" slides in from right |
| Clear button replaces sparkles | SRCH-01 | Interaction check | Type text, verify xmark appears and sparkles hidden |
| Sticky header in full mode | SRCH-03 | Scroll behavior check | Expand to full, scroll content, verify handle+search stick |
| Haptic on peek tap | SRCH-04 | Physical device only | Tap peek pill, feel light impact |
| 0.5pt stroke on expanded capsule | SRCH-03 | Visual check | Expand to half, verify thin white border on search field |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
