# Feature Landscape

**Domain:** iOS Travel App — Map Navigation Overhaul
**Researched:** 2026-03-20
**Scope:** MapKit-based navigation for a travel-focused iOS app (not a standalone nav app)

---

## Table Stakes

Features users expect in any serious navigation-capable travel app. Missing any of these and the map feels broken or incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Route display (polyline on map) | Every map app shows a route line | Low | Already exists via MapRouteContent.swift |
| Multi-modal routing (walk/drive/transit/cycle) | Apple Maps has had this since 2013 | Medium | TransportMode enum exists; Google Routes API already wired |
| ETA + distance per mode | Users make transport decisions by time cost | Low | ModeETAPreview struct exists; fetchETAPreviews() in RoutingService |
| Bottom sheet with detents (peek/half/full) | Apple Maps set this standard; any deviation feels wrong on iOS | Medium | MapBottomSheet.swift already implements 3-detent custom sheet |
| Floating search bar over map | Standard since iOS 16 Maps redesign | Low | MapFloatingSearchPill.swift already implemented |
| Place detail card (name, address, hours, rating) | Users tap pins to get context | Medium | MapPlaceDetailContent.swift exists; Google Places detail wired |
| Turn-by-turn step list | Users must know upcoming turns before starting | Low | MKRouteStep text available; needs UI panel |
| Current location tracking (blue dot + heading) | Required for any navigation use | Low | LocationManager.shared.currentLocation exists |
| Route recalculation on deviation | If you miss a turn, app must recover | High | Not yet implemented; requires position-to-route distance checking |
| Voice guidance (spoken turn instructions) | Without voice, navigation requires eyes on screen — unsafe | Medium | AVSpeechSynthesizer; not yet implemented |
| "Start navigation" mode with map auto-panning | Map must follow user in nav mode | High | Not yet implemented |
| Alternative route display (2-3 options) | Google/Apple both show alternatives; single route feels naive | Medium | MKDirections supports alternatives; not exposed in UI yet |

---

## Differentiators

Features that give this app an edge specifically because it is a travel planner, not a general-purpose nav app. General nav apps cannot offer these.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Navigate to itinerary places directly | One-tap routing from the trip's saved places — no searching | Low | selectedPlace already drives calculateDirectionRoute(); tighten UX |
| Today's places highlighted on map | Travelers need to know "which places am I visiting today?" | Low | visiblePlaces already filters by today's cityName |
| Day-by-day route visualization (color per day) | Overview of the full trip's path — unique to planners | Medium | routeColor(for:) exists; TripDay route overlays present |
| Flight/train arc overlays | Show long-haul legs on the same map as walking routes | Medium | flightArcs + trainRoutes loading in MapViewModel |
| Cached route offline playback | In a foreign country without data, the trip's pre-planned routes still work | High | Requires pre-cache step; Apple prohibits live tile caching but route JSON can be stored |
| Trip context in navigation UI | Show "Day 2 of 7 — Tokyo" during navigation, not just an address | Low | Trip model available throughout; surface in nav overlay |
| Weather-aware route suggestion | "It's raining — take the metro instead of walking" | High | WeatherService + RoutingService both exist; needs orchestration layer |
| AI place search scoped to trip region | Search for "best ramen" and results center on current trip city | Low-Medium | AIMapSearchService.shared.search() already takes city + coordinate |
| Precipitation radar overlay | See rain coming during outdoor navigation | Medium | showPrecipitation toggle + RadarOverlayView.swift already exist |
| Multi-city trip overview map | Show all cities of the trip on one map with routing between them | Medium | geocodeCountryCamera() + allPlaces exist; needs inter-city route layer |

---

## Anti-Features

Deliberately excluded. Building these would waste time, introduce complexity, or conflict with constraints.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Custom map tile rendering (Mapbox/MapLibre) | Breaks glassmorphism integration, adds SDK dependency, Apple's ToS prohibits caching their tiles anyway | Stick with MapKit; use MKMapSnapshotter for offline snapshots (already in place) |
| Truck/motorcycle/e-scooter routing | No MKDirections support; Google Routes API adds cost per call for specialty modes | Walking + auto + transit + cycling covers 99% of traveler needs |
| Toll-avoidance / highway avoidance | MKDirections does not expose these preferences; Google Routes supports it but adds UI complexity | Let Apple Maps handle this via openAppleMapsTransit() fallback |
| Real-time crowd density heatmaps | Requires third-party data subscription (Google Popular Times, Foursquare); not MapKit native | Show place ratings + opening hours — sufficient signal for travelers |
| Community hazard reporting (Waze-style) | Requires server-side crowd infrastructure; no synergy with trip planning | Not a commuter app; travelers don't report potholes |
| AR walking navigation overlay | Explicitly out of scope per PROJECT.md; separate future milestone | Ship core nav first; AR is its own track |
| Embedded CarPlay navigation | Complex entitlement + UI separate from the app; minimal traveler need | Hand off to Apple Maps for CarPlay via openMaps() |
| Live traffic layer | MapKit applies traffic tinting automatically; adding a separate toggle confuses users | Trust MapKit's default traffic rendering |
| Speed camera / speed limit alerts | Not a driving-safety app; travelers mostly walk/transit | Out of scope by user intent |
| Subscriptions gating navigation | Kills trust; navigation is a core utility in a travel app | Navigation must be always-free as part of the core app |

---

## Feature Dependencies

```
Current location (LocationManager) → Route calculation from current position
                                   → Auto-pan in navigation mode
                                   → Route deviation detection

Route calculation (RoutingService) → Turn-by-turn step list
                                   → Voice guidance (step announcements)
                                   → Route recalculation on deviation

Turn-by-turn step list → Voice guidance (reads the same step instructions)
                       → Navigation mode overlay UI

Navigation mode overlay → Auto-panning (camera follows user)
                        → Route deviation detection (triggers recalculation)
                        → Live Activity / Dynamic Island (mirrors nav state)

Cached routes (pre-download) → Offline navigation
                             → Requires route calculation BEFORE going offline

Place detail (Google Places) → Place cards in bottom sheet
                             → "Navigate here" CTA on place detail

Weather + Routing → Weather-aware mode suggestion (deferred; Phase 3+)
```

---

## MVP Recommendation

The overhaul milestone should ship these in order of user-facing impact:

**Phase 1 — Route UX completion (low-hanging fruit):**
1. Alternative routes panel (2-3 options with ETA chips) — MKDirections already supports it
2. Turn-by-turn step list in bottom sheet (full detent) — MKRouteStep text already available
3. Transport mode ETA bar (show all 4 modes at once) — etaPreviews already loaded

**Phase 2 — Active navigation:**
4. Navigation mode: map auto-pan + heading lock + next-turn banner
5. Voice guidance via AVSpeechSynthesizer (reads next step on approach)
6. Route deviation detection + automatic recalculation

**Phase 3 — Travel-specific differentiators:**
7. Pre-cache routes for offline use (store route JSON per trip day)
8. Day route overview mode (color-coded per day, all at once)
9. Trip context overlay during navigation (day number, city name)

**Defer to later milestones:**
- Weather-aware transport suggestion: needs dedicated orchestration service
- Multi-city inter-city routing: low traveler demand vs complexity
- Live Activity navigation: already partially implemented, tie in after Phase 2

---

## Confidence Notes

| Claim | Confidence | Source |
|-------|------------|--------|
| MKDirections returns multiple alternative routes | HIGH | Apple Developer Documentation (MKDirections) |
| AVSpeechSynthesizer SSML support on iOS 16+ | HIGH | Apple Developer Docs (AVSpeechUtterance SSML) |
| Apple Maps ToS prohibits caching tiles for offline | HIGH | Apple Developer Forums (confirmed multiple threads) |
| MKMapSnapshotter approach for offline is legal | HIGH | Already in production in this app (OfflineCacheManager) |
| Google Maps 67% market share, Apple Maps 25% | MEDIUM | WebSearch (Scrap.io, 2025) |
| Weather-aware routing as differentiator | MEDIUM | Inferred from existing WeatherService + RoutingService; no direct precedent found in WebSearch |
| MapKit automatic traffic rendering (no manual layer needed) | HIGH | MapKit documentation + App Store observation |

---

## Sources

- [Apple Developer: MKDirections](https://developer.apple.com/documentation/mapkit/mkdirections)
- [Apple Developer: MapKit](https://developer.apple.com/documentation/mapkit/)
- [WWDC 2025 — Go further with MapKit](https://dev.to/arshtechpro/wwdc-2025-go-further-with-mapkit-mapkit-javascript-a5l)
- [Routing With MapKit and Core Location — Kodeco](https://www.kodeco.com/10028489-routing-with-mapkit-and-core-location)
- [Google Maps vs Apple Maps vs Waze 2026 — Pocket-lint](https://www.pocket-lint.com/google-maps-vs-apple-maps-vs-waze/)
- [Apple Maps vs Google Maps 2026 — Holafly](https://esim.holafly.com/reviews/google-maps-vs-apple-maps/)
- [Best Offline Maps 2025 — Simology](https://simology.io/blog/best-offline-maps-travel-2025-google-vs-apple-vs-mapsme)
- [Travel Planning App Features 2025 — Shivlab](https://shivlab.com/blog/top-features-for-travel-planning-app/)
- [Apple Developer Forums: MapKit offline limitations](https://developer.apple.com/forums/thread/20648)
- [Apple Developer Forums: Turn-by-turn with MapKit](https://developer.apple.com/forums/thread/674566)
