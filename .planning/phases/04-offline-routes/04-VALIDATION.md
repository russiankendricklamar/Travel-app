---
phase: 4
slug: offline-routes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — iOS SwiftUI project, no test target configured |
| **Config file** | None (manual Xcode setup required per MEMORY.md) |
| **Quick run command** | `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"` |
| **Full suite command** | Build + manual verification on device |
| **Estimated runtime** | ~30 seconds (build only) |

---

## Sampling Rate

- **After every task commit:** Run build command to verify compilation
- **After every plan wave:** Build + manual verification of affected features
- **Before `/gsd:verify-work`:** Full build green + manual test all success criteria
- **Max feedback latency:** 30 seconds (build)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | OFFL-01 | build | `xcodebuild build` | ✅ | ⬜ pending |
| 04-01-02 | 01 | 1 | OFFL-01 | build | `xcodebuild build` | ✅ | ⬜ pending |
| 04-01-03 | 01 | 1 | OFFL-02 | build | `xcodebuild build` | ✅ | ⬜ pending |
| 04-02-01 | 02 | 2 | OFFL-03 | manual | Tap button, observe progress | N/A | ⬜ pending |
| 04-02-02 | 02 | 2 | OFFL-04 | manual | Airplane mode + verify messages | N/A | ⬜ pending |
| 04-02-03 | 02 | 2 | OFFL-02 | manual | Navigate offline, check reroute | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers build verification. No test target exists for unit tests.

*Note: MEMORY.md states "Test target needs manual Xcode setup" — automated unit testing is out of scope for this phase.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pre-cache button triggers N² route requests with progress ring | OFFL-03 | Requires real MKDirections API + visual progress verification | 1. Open day map with 3+ places 2. Tap "Подготовить офлайн" 3. Verify progress ring animates 4. Verify "✓ Маршруты готовы" appears |
| Offline route display matches online appearance | OFFL-02 | Visual comparison requires human judgment | 1. Pre-cache a day 2. Enable airplane mode 3. Select route between cached places 4. Compare appearance with online version |
| Offline no-cache shows correct message + disabled CTA | OFFL-04 | UI state verification on physical device | 1. Enable airplane mode WITHOUT pre-caching 2. Select route between places 3. Verify "Маршрут недоступен офлайн" message 4. Verify pre-cache button disabled |
| Offline navigation skips reroute, shows warning | OFFL-02 | Requires physical movement/GPS simulation | 1. Pre-cache route 2. Start navigation 3. Enable airplane mode 4. Deviate from route 5. Verify warning instead of reroute |
| Cache persists across app restarts | OFFL-01 | SwiftData persistence requires kill+relaunch | 1. Pre-cache day 2. Force-quit app 3. Relaunch 4. Check button shows "✓ Маршруты готовы" |

---

## Validation Sign-Off

- [ ] All tasks have build verify or manual verification instructions
- [ ] Sampling continuity: build check after every code task
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
