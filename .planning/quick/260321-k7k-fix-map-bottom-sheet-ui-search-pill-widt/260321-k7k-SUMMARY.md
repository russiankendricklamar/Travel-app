# Quick Task 260321-k7k: Fix Map Bottom Sheet Peek Pill

## Changes

### MapBottomSheet.swift
- Peek background changed from `.ultraThinMaterial` + `.black.opacity(0.35)` overlay → `Color.black` solid fill
- Removed unnecessary `.environment(\.colorScheme, .dark)` (not needed for solid color)
- Shadow preserved for depth

## Build
- Verified: BUILD SUCCEEDED (iPhone 17 Pro Max simulator)
