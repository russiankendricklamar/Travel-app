---
phase: 11
slug: transitions-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode Build + SwiftUI Preview + Physical Device |
| **Config file** | Travel app.xcodeproj |
| **Quick run command** | `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"` |
| **Full suite command** | `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" 2>&1 \| tail -5` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Build verification (compile check)
- **After every plan wave:** Full build + preview inspection
- **Before `/gsd:verify-work`:** Full build must succeed + physical device verification
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | TRAN-01 | build | `xcodebuild build` | ✅ | ⬜ pending |
| 11-01-02 | 01 | 1 | TRAN-02 | build+visual | `xcodebuild build` | ✅ | ⬜ pending |
| 11-01-03 | 01 | 1 | TRAN-03 | build+visual | `xcodebuild build` | ✅ | ⬜ pending |
| 11-01-04 | 01 | 1 | TRAN-04 | build+visual | `xcodebuild build` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. No new test framework needed — this is a visual/animation polish phase verified by build success + physical device inspection.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Spring animation smoothness (60fps) | TRAN-01 | Animation quality requires visual/haptic assessment | Run on physical iPhone, drag sheet between peek/half/full, verify no jank or frame drops |
| Background morph blur→opaque | TRAN-02 | Blur material rendering differs sim vs device | On device: drag from peek to half, verify smooth opacity transition of pill blur to sheet background |
| Corner radius morph all→top-only | TRAN-03 | Corner radius interpolation visual quality | On device: drag sheet up, verify bottom corners smoothly animate from 22pt to 0pt |
| Keyboard expand flow timing | TRAN-04 | Keyboard timing + content shift requires interaction test | Tap search bar in peek mode, verify: sheet expands to full → 150ms pause → keyboard appears, content stays in place |
| Haptic feedback intensity | TRAN-01 | Haptics only felt on physical device | Snap sheet to each detent, verify .light impact feels appropriate |

---

## Validation Sign-Off

- [ ] All tasks have build verification
- [ ] Sampling continuity: build check after every commit
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] Physical device verification for all TRAN requirements
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
