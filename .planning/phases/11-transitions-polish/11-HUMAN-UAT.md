---
status: partial
phase: 11-transitions-polish
source: [11-VERIFICATION.md]
started: 2026-03-21T13:30:00+09:00
updated: 2026-03-21T13:30:00+09:00
---

## Current Test

[awaiting human testing]

## Tests

### 1. Background opacity morph over live map tiles (TRAN-02)
expected: Slow drag from peek to half — blur pill fades out smoothly, opaque sheet fades in. No visual pop or flicker over map tiles (parks, water, buildings).
result: [pending]

### 2. Corner radius smoothness during drag and snap (TRAN-03)
expected: Bottom corners animate from 22pt to 0pt during drag. No visual pop or jump on snap. Smooth both at slow drag speed and velocity fling.
result: [pending]

### 3. Haptic feedback on every detent snap
expected: .light impact haptic fires each time sheet snaps to peek, half, or full. Feels subtle but noticeable.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
