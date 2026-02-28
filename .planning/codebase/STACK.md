# Technology Stack

**Analysis Date:** 2026-02-28

## Languages

**Primary:**
- Swift 5.0 - Native iOS app development (all app code)

## Runtime

**Environment:**
- iOS 17.0 (minimum deployment target)
- Targets: iPhone and iPad (both orientations supported)

**Device Families:**
- iPhone and iPad (TARGETED_DEVICE_FAMILY = "1,2")

## Frameworks

**Core UI:**
- SwiftUI - Declarative UI framework for all views
- MapKit - Interactive maps for itinerary visualization
- Observation - Modern reactive data binding (@Observable macro)

**System Frameworks:**
- Foundation - Date, UUID, Calendar utilities
- CoreLocation - Location coordinate handling for map pins

**Build System:**
- Xcode (version 26.3+)
- Project Format: Xcode 77 (modern file synchronization format)

## Key Dependencies

**Built-in Only:**
- No external package dependencies (SPM or CocoaPods)
- All functionality implemented with native Apple frameworks

## Configuration

**Development Team:**
- Development Team ID: 9UCR65VBLX
- Code Signing: Automatic

**Build Configurations:**
- Debug - Full optimization disabled, testability enabled, debug symbols included
- Release - Full optimizations (whole module), debug symbols in separate file (dwarf-with-dsym)

**Product:**
- Bundle Identifier: `ru.travel.Travel-app`
- Version: 1.0
- Build Number: 1

**Compiler Settings:**
- Swift version: 5.0
- Approaching concurrency enabled (SWIFT_APPROACHABLE_CONCURRENCY)
- Default actor isolation: MainActor
- Member import visibility: Enabled (upcoming feature)
- Localization: String catalogs with generated symbols

**Assets:**
- Asset catalog with App Icon and Accent Color
- Dynamic color generation enabled

## Platform Requirements

**Development:**
- Xcode 26.3 or later
- Swift 5.0
- macOS 12 or later (for build environment)
- iOS SDK

**Production:**
- Minimum iOS 17.0
- iPhone or iPad device
- No special permissions configured beyond default UIKit requirements

**Compiler Flags:**
- C Language: gnu17
- C++ Standard: gnu++20
- Objective-C ARC enabled
- Objective-C weak references enabled
- User script sandboxing enabled
- Strict Objective-C messaging enabled

---

*Stack analysis: 2026-02-28*
