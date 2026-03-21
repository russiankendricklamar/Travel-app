---
phase: 9
slug: floating-controls
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode Build (SwiftUI preview + manual visual) |
| **Config file** | Travel app.xcodeproj |
| **Quick run command** | `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -quiet` |
| **Full suite command** | `xcodebuild build -scheme "Travel app" -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick build command
- **After every plan wave:** Run full build
- **Before `/gsd:verify-work`:** Full build must be green + manual visual checks
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | CTRL-01 | build+grep | `grep -c 'FloatingControlsOverlay' Travel\ app/Views/Map/FloatingControlsOverlay.swift` | ❌ W0 | ⬜ pending |
| 09-01-02 | 01 | 1 | CTRL-02 | build+grep | `grep 'ultraThinMaterial' Travel\ app/Views/Map/FloatingControlsOverlay.swift` | ❌ W0 | ⬜ pending |
| 09-01-03 | 01 | 1 | CTRL-03 | build+grep | `grep 'MapCompass.*scope' Travel\ app/Views/Map/FloatingControlsOverlay.swift` | ❌ W0 | ⬜ pending |
| 09-01-04 | 01 | 1 | CTRL-04 | build+grep | `grep 'showsTraffic\|bus.fill' Travel\ app/Views/Map/FloatingControlsOverlay.swift` | ❌ W0 | ⬜ pending |
| 09-01-05 | 01 | 1 | CTRL-05 | build+grep | `grep 'elevation.*realistic\|view.3d' Travel\ app/Views/Map/FloatingControlsOverlay.swift` | ❌ W0 | ⬜ pending |
| 09-01-06 | 01 | 1 | CTRL-06 | build+grep | `grep 'location.*center\|setCameraPosition' Travel\ app/Views/Map/TripMapView.swift` | ✅ | ⬜ pending |
| 09-01-07 | 01 | 1 | CTRL-07 | manual | Visual: fade on sheet raise above peek | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `FloatingControlsOverlay.swift` — new file created with stub structure
- [ ] Existing infrastructure covers build verification

*No additional test framework needed — Xcode build verification is sufficient for SwiftUI view changes.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Buttons fade when sheet raises above peek | CTRL-07 | Visual animation timing cannot be automated | 1. Open map tab 2. Verify buttons visible at peek 3. Drag sheet up 4. Verify buttons fade out 5. Drop sheet back to peek 6. Verify buttons fade back in |
| Compass auto-hides when north-facing | CTRL-03 | MapKit compass behavior is runtime-visual | 1. Rotate map away from north 2. Verify compass appears 3. Rotate back to north 4. Verify compass hides + container shrinks |
| Location button centers on GPS | CTRL-06 | Requires GPS simulation | 1. Pan map away from current location 2. Tap location button 3. Verify map centers on simulated GPS position |
| Transit toggle changes map style | CTRL-04 | Visual mapStyle change | 1. Tap transit button 2. Verify traffic overlay appears 3. Tap again 4. Verify traffic overlay disappears |
| 3D elevation toggle | CTRL-05 | Visual elevation rendering | 1. Tap elevation button 2. Verify terrain becomes 3D 3. Tap again 4. Verify returns to flat |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
