---
phase: 10
slug: sheet-content
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode Build Verification (xcodebuild) |
| **Config file** | Travel app.xcodeproj |
| **Quick run command** | `xcodebuild build -project "Travel app.xcodeproj" -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -quiet 2>&1 | tail -5` |
| **Full suite command** | `xcodebuild build -project "Travel app.xcodeproj" -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" 2>&1 | tail -20` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick build command
- **After every plan wave:** Run full build command
- **Before `/gsd:verify-work`:** Full build must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | CONT-01,02,03 | build + manual | `xcodebuild build ...` | ✅ | ⬜ pending |
| 10-01-02 | 01 | 1 | CONT-04 | build + manual | `xcodebuild build ...` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework needed — Phase 10 is a UI visibility fix verified by build + manual inspection.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Category chips visible in half mode | CONT-01 | UI layout visibility — no unit test possible | 1. Open app 2. Select trip 3. Verify chips (Музеи, Парки, Магазины, Отели) visible below search bar in half sheet |
| Today section visible in half mode | CONT-02 | UI content rendering | 1. Have places for today 2. Verify "Сегодня · [City]" section visible in half mode |
| Map controls visible in half mode | CONT-03 | UI component visibility | 1. Verify map controls row (Слои, Осадки, Обзор, Все места) visible in half mode |
| Scroll doesn't hijack sheet drag | CONT-04 | Gesture interaction | 1. In half mode, drag sheet down 2. Verify sheet collapses (not scroll) 3. In full mode, scroll content 4. Verify scroll works normally |
| Category chip tap shows results | CONT-01 | Interaction flow | 1. Tap a category chip 2. Verify search results appear 3. Verify chips hide when results show |
| "Показать все" overflow | CONT-02 | Conditional UI | 1. Have >3 places today 2. Verify "Показать все (N)" button appears 3. Tap it 4. Verify sheet expands to full |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
