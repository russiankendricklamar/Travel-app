# External Integrations

**Analysis Date:** 2026-02-28

## APIs & External Services

**None Configured**
- No external APIs integrated
- No third-party services configured
- Application is fully self-contained

## Data Storage

**Databases:**
- Not used - No persistent data storage
- Data is in-memory only, loaded from sample data on app launch

**File Storage:**
- Local filesystem only
- Device local storage: Not implemented
- All data resets on app restart

**Caching:**
- None - In-memory cache via SwiftUI state only

## Authentication & Identity

**Auth Provider:**
- Not applicable - No authentication system
- App is single-user, no login required
- No user accounts or sessions

## Monitoring & Observability

**Error Tracking:**
- None configured
- No error logging service integrated

**Logs:**
- Console logging: Not implemented
- No structured logging framework in use
- Debug output: Minimal, using standard Swift debugger

## CI/CD & Deployment

**Hosting:**
- iOS App Store deployment (standard iOS app)
- Distribution: App Store, TestFlight, or direct device install

**CI Pipeline:**
- None configured
- Manual build and deploy via Xcode

**Build Signing:**
- Automatic code signing enabled
- Development team provisioning: 9UCR65VBLX

## Environment Configuration

**Required env vars:**
- None - Application requires no environment variables

**Secrets location:**
- Not applicable - No API keys, tokens, or secrets needed

**Info.plist Configuration:**
- Auto-generated (GENERATE_INFOPLIST_FILE = YES)
- UI scene manifest generation enabled
- UI status bar style: Default
- Supports indirect input events
- Custom launch screen generation enabled

## Webhooks & Callbacks

**Incoming:**
- None - App receives no external webhooks

**Outgoing:**
- None - App sends no data to external services

## Location Services

**MapKit Integration:**
- Map display with hardcoded locations
- No real-time location tracking
- No geocoding service calls
- All coordinates manually specified in `SampleData.swift`:
  - Tokyo region: ~35.6762°N, 139.6503°E
  - Kyoto region: ~35.0°N, 135.7°E
  - Osaka region: ~34.6°N, 135.5°E

**Location Permissions:**
- Not required - No actual location access needed
- Map pins use static coordinates only

## Data Synchronization

**Cloud Sync:**
- Not implemented
- No CloudKit integration
- No iCloud backup

**Inter-device Sync:**
- Not supported
- Data is device-local only
- No account system

## Accessibility Services

**VoiceOver:**
- Standard UIAccessibility (automatic from SwiftUI components)
- No custom accessibility configuration

**Internationalization:**
- String catalogs enabled (LOCALIZATION_PREFERS_STRING_CATALOGS = YES)
- Current language: Russian (UI strings are in Russian)
- Localization: Not fully implemented, hardcoded strings in Russian

---

*Integration audit: 2026-02-28*
