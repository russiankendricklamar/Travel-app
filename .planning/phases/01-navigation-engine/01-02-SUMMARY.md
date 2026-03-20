---
phase: 01-navigation-engine
plan: 02
subsystem: navigation
tags: [voice, avfoundation, audio-session, tts]
dependency_graph:
  requires: []
  provides: [NavigationVoiceService]
  affects: [NavigationEngine (01-03)]
tech_stack:
  added: []
  patterns: [AVSpeechSynthesizerDelegate, AVAudioSession duck/unduck lifecycle]
key_files:
  created:
    - Travel app/Services/NavigationVoiceService.swift
  modified: []
decisions:
  - "Used .interruptSpokenAudioAndMixWithOthers alongside .duckOthers per research recommendation to handle concurrent audio correctly"
  - "Locale language code identifier used (not full locale) for voice matching — closer to AVSpeechSynthesisVoice language format"
metrics:
  duration: 3min
  completed: "2026-03-20"
  tasks_completed: 1
  files_created: 1
  files_modified: 0
---

# Phase 01 Plan 02: NavigationVoiceService Summary

AVSpeechSynthesizer wrapper with distance-triggered announcements at 500m/200m/15m and correct audio session duck/unduck lifecycle (0.5s delayed deactivation to fix error 560030580).

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create NavigationVoiceService with distance triggers and audio session lifecycle | 78d2958 | Travel app/Services/NavigationVoiceService.swift |

## What Was Built

`NavigationVoiceService.swift` — a standalone `NSObject` subclass conforming to `AVSpeechSynthesizerDelegate`:

- Single `AVSpeechSynthesizer` instance (no memory churn per Pitfall 11)
- `checkDistanceTrigger(_:stepInstruction:)` — called each GPS tick; fires at ≤500m, ≤200m, ≤15m thresholds
- `announcedDistances: Set<String>` keyed on `"{instruction}-{threshold}"` prevents repeat announcements
- `announceStep(instruction:distanceRemaining:)` — immediate announcement for step advancement or reroute
- `resetForStep(_:)` / `resetAll()` — housekeeping for step advances and navigation end
- `speak(_:)` — cancels queued speech with `.word` boundary, activates AVAudioSession with `.duckOthers`, then synthesizes
- `speechSynthesizer(_:didFinish:)` delegate — 0.5s `asyncAfter` deactivation with `.notifyOthersOnDeactivation` (Pitfall 2 fix)
- Russian announcement strings: "Через N метров, {instruction}" at 200m; "Через X километров, {instruction}" at 500m+; bare instruction at arrival
- Locale voice with `ru-RU` fallback

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `Travel app/Services/NavigationVoiceService.swift` exists
- [x] Commit 78d2958 exists
- [x] Build succeeded: `** BUILD SUCCEEDED **`
- [x] All grep checks pass: class declaration, AVSpeechSynthesizerDelegate, notifyOthersOnDeactivation, asyncAfter 0.5, triggerDistances [500, 200, 15]
