# Technology Stack

**Analysis Date:** 2026-03-20

## Languages

**Primary:**
- Swift 5.9+ - iOS app implementation, all business logic and UI
- SwiftUI - Modern declarative UI framework

**Secondary:**
- Python 3 - Build/documentation scripts (docs/generate_pitch.py)

## Runtime

**Environment:**
- iOS 18+ (deployment target)
- iPhone 17 Pro Max simulator / physical iPhone device
- Xcode 16+

**Package Manager:**
- SPM (Swift Package Manager) - Primary dependency management
- CocoaPods - Not used
- Carthage - Not used

**Dependencies (SPM):**
- `supabase/supabase-swift` v2.0+ - Backend, auth, database, storage

## Frameworks

**Core:**
- SwiftUI - UI framework
- SwiftData - Local database (replaced CoreData), persistent model storage
- MapKit - Maps, geolocation, routing, coordinate handling
- CoreLocation - GPS tracking, location services
- Vision - OCR (text recognition from booking images/receipts)
- ARKit - Augmented reality navigation
- ActivityKit - Live Activities + Dynamic Island widgets

**Authentication:**
- AuthenticationServices - Apple Sign In, ASWebAuthenticationSession OAuth
- Supabase Auth - Email/password, Apple IdToken, Google OAuth, Yandex OAuth

**Notifications:**
- UserNotifications - Push notifications, local scheduling, geofence notifications
- Live Activities - Flight tracking in Dynamic Island

**Data & Storage:**
- Supabase PostgreSQL - Remote database (trips, days, places, expenses, tickets, packing, journal, routes, photos, bucket list)
- Supabase Storage - File uploads (trip photos, bucket list photos in `trip-photos` bucket)
- UserDefaults - Preferences, cache, sync timestamps
- Keychain - Secrets via KeychainHelper (API keys, tokens, auth credentials)

**Networking:**
- URLSession - HTTP requests with custom timeouts (30s default, 60s for Gemini)
- Supabase Edge Functions - Server-side API proxies (api-proxy, email-token-exchange, email-scanner, gemini-proxy)

**Testing:**
- XCTest - Unit testing framework (test target exists, setup is manual)

**Build/Dev:**
- Xcode Project File - `.xcodeproj` structure
- Asset Catalogs - Colors, icons, app branding
- Localizable.xcstrings - Russian UI localization
- Entitlements - App capabilities (push, background location, ARKit, camera)

## Key Dependencies

**Critical:**
- `supabase-swift` v2.0+ - Complete backend stack (auth, Postgres sync, file storage, Edge Functions)
  - Provides: SupabaseClient initialization, auth flows, table subscriptions, storage upload/download, Edge Function invocation
  - Location: `Travel app/Services/SupabaseManager.swift`, `Travel app/Services/SupabaseAuthService.swift`

**Infrastructure:**
- CoreLocation - GPS, geocoding, coordinate math
  - Purpose: Location tracking, city/place coordinate resolution, geofencing
  - Location: `Travel app/Services/LocationManager.swift`, `Travel app/Services/WeatherService.swift`

- Vision.framework - Text recognition from images
  - Purpose: OCR in booking scanner (receipts, flight tickets)
  - Location: `Travel app/Services/BookingScanService.swift`, `Travel app/Services/ReceiptScanService.swift`

- ARKit + RealityKit - Augmented reality navigation
  - Purpose: AR navigation overlay on camera feed
  - Location: `Travel app/Services/ARNavigationManager.swift`

- MapKit - Maps, route rendering, Haversine distance calculation
  - Purpose: Trip map display, route optimization, place discovery nearby
  - Location: `Travel app/Views/Map/TripMapView.swift`, `Travel app/Services/RoutingService.swift`

- ActivityKit - Live Activities
  - Purpose: Flight tracking widget in Dynamic Island
  - Location: `Travel app/Services/LiveActivityManager.swift`

## Configuration

**Environment:**
- `.env` files - NOT used; Supabase secrets configured server-side
- `Secrets.swift` - Central secret management via Keychain
- `Secrets.xcconfig` - Build config for Supabase URL/key, OAuth client IDs
  - YANDEX_CLIENT_ID, YANDEX_CLIENT_SECRET - OAuth providers
  - GOOGLE_CLIENT_ID - Google OAuth (web client for iOS)
  - Note: This file is in `.gitignore` and never committed; AI keys removed (delegated to Edge Functions)

**App Configuration:**
- `Info.plist` - Permissions strings (camera, location), UIBackgroundModes (location)
- `WidgetInfo.plist` - Widget extension configuration
- Entitlements - App Groups (if cross-target sharing), background modes

**Build Settings:**
- Target: "Travel app" (main app)
- Build Target: iOS (arm64 for physical device, x86_64/arm64 for simulator)
- Marketing Version: Specified in project settings
- Code Signing: Auto/manual provisioning profiles required

## Platform Requirements

**Development:**
- Xcode 16 with iOS 18+ SDK
- Swift 5.9+ compiler
- Minimum deployment: iOS 18
- Physical iPhone device recommended for full features (GPS, camera, geofence, Live Activities)
- M1/M2 Mac for optimal simulator performance

**Production:**
- iOS App Store distribution
- Supabase backend (free tier or paid project, project ID: lwgcacwslkchspzygvum)
- Edge Functions enabled (for API proxies)
- Storage bucket: `trip-photos`
- PostgreSQL RLS policies configured

**Runtime Permissions Required:**
- Camera (NSCameraUsageDescription) - AR navigation, booking/receipt OCR
- Location Always & When In Use (NSLocationAlwaysAndWhenInUseUsageDescription) - Geofencing + live tracking
- Photo Library access - Photo picker for trip memories

**Network Configuration:**
- Proxy URL: `{SUPABASE_URL}/functions/v1/api-proxy` - All third-party APIs routed through Edge Function
- OAuth Callback Scheme: `travelapp://` (custom URL scheme for OAuth redirects)
- No direct API keys in app binary (all delegated to Supabase Edge Functions)

---

*Stack analysis: 2026-03-20*
