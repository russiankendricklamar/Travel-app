---
phase: 7
slug: sheet-geometry
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 7 — Validation Strategy

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
| 07-01-01 | 01 | 1 | GEOM-01 | build | `xcodebuild build` | ✅ | ⬜ pending |
| 07-01-02 | 01 | 1 | GEOM-02 | build+visual | `xcodebuild build` | ✅ | ⬜ pending |
| 07-01-03 | 01 | 1 | GEOM-03 | build | `xcodebuild build` | ✅ | ⬜ pending |
| 07-01-04 | 01 | 1 | GEOM-04 | build | `xcodebuild build` | ✅ | ⬜ pending |
| 07-01-05 | 01 | 1 | GEOM-05 | build | `xcodebuild build` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements — xcodebuild is already configured.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Peek pill blur over light map tiles | GEOM-02 | `.ultraThinMaterial` rendering only verifiable on physical device | Navigate to park/beach area, verify pill remains dark and map shows through |
| Half mode 40% height proportion | GEOM-04 | Visual proportion check | Expand to half, verify sheet covers ~40% of screen |
| Full mode under status bar | GEOM-05 | Visual layout check | Expand to full, verify content starts below status bar safe area |
| Shape morph peek→half | GEOM-02→04 | Animation smoothness only verifiable visually | Drag from peek to half, verify no shape snap at transition |
| Shadow rendering quality | GEOM-02 | Visual quality check | Verify peek pill shadow visible on dark map, not overpowering |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
