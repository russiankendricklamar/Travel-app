# External Integrations

**Analysis Date:** 2026-03-20

## APIs & External Services

**Flight Data:**
- **AirLabs** (Aviasales) - Real-time flight schedules + live positions
  - Service: `Travel app/Services/AirLabsService.swift`
  - Methods: `/schedules` (real-time), `/routes` (static timetable), `/flights` (live position)
  - Auth: API key stored server-side via Supabase
  - Proxy: SupabaseProxy with action `flights`
  - Cache: 5min for flight data, 1min for live positions
  - Autofills: TripFlight.departureIata, arrivalIata, airlineCode

**Flight & Hotel Search:**
- **Travelpayouts** (Aviasales + Hotellook APIs)
  - Service: `Travel app/Services/TravelpayoutsService.swift`
  - Methods:
    - Flights: Aviasales prices_for_dates API → origin/destination/date → FlightOffer
    - Hotels: Hotellook cache.json → location/checkIn/checkOut → HotelOffer
    - Destinations: cheapDestinations API → seasonal pricing
  - Auth: API token stored server-side
  - Proxy: SupabaseProxy with action `flights` or `hotels`
  - Used by: AITripWizardView (wizard phase 3)

**Weather:**
- **Open-Meteo** - Current weather, daily forecast, hourly forecast, AQI, weather alerts
  - Service: `Travel app/Services/WeatherService.swift`
  - Endpoints: `/forecast?latitude=X&longitude=Y&hourly=temperature,precipitation&daily=&alerts`
  - Auth: No API key required (public free tier)
  - Proxy: SupabaseProxy with action `weather`
  - Cache: 15min per coordinate
  - Models: WeatherInfo, HourlyWeatherInfo, AirQualityInfo, WeatherAPIAlert
  - Used by: DashboardWeatherSection, WeatherDetailView
  - Fallback: UserDefaults cache on error (offline support)

**Currency Exchange:**
- **open.er-api.com** - Real-time currency conversion rates
  - Service: `Travel app/Services/CurrencyService.swift`
  - Endpoint: `/api/latest/{baseCurrency}` → rates
  - Auth: No API key required
  - Proxy: SupabaseProxy with action `currency`
  - Supported currencies: RUB, JPY, USD, CNY, EUR
  - Cache: 5min, auto-refresh every 5min if active
  - Fallback: Hardcoded fallback matrix for offline use
  - Used by: ExpensesView, budget tracking

**Place Information:**
- **Wikipedia API** - Article search + text extraction
  - Service: `Travel app/Services/WikipediaService.swift`
  - Endpoints: `/api.php?action=query&list=search&srsearch={placeName}`
  - Auth: No API key
  - Proxy: SupabaseProxy with action `wikipedia`
  - Output: PlaceInfo (history, tips, source)
  - Used by: PlaceInfoService (fallback after Gemini)

**Country Information:**
- **REST Countries API** - Flag, capital, languages, timezones
  - Service: `Travel app/Services/CountryInfoService.swift`
  - Endpoint: `/v3.1/name/{country}` → CountryData
  - Auth: No API key
  - Proxy: SupabaseProxy with action `countries`
  - Cache: 7 days per country
  - Used by: Trip details, country flags display

**AI Language Models:**
- **Google Gemini 2.5 Flash** - Place info generation, packing suggestions, itinerary creation, AI caching
  - Service: `Travel app/Services/GeminiService.swift`, `Travel app/Services/AIPromptHelper.swift`
  - Model: `gemini-2.5-flash`
  - Methods: Raw prompts → JSON extraction, summarization, generation
  - Auth: API key stored server-side
  - Proxy: SupabaseProxy with action `gemini` (timeout: 60s)
  - Rate limiting: 3 retries on 429, 10s backoff
  - Cache: AICacheManager (7 day TTL, max 200 entries)
  - Used by:
    - PlaceInfoService (place descriptions)
    - RecommendationService (activity suggestions)
    - PackingListAIService (packing list generation)
    - AITripGeneratorService (itinerary creation)
    - FlightAIService (flight tips)
    - AIMapSearchService (location details)

**Email Access (OAuth + Parsing):**
- **Gmail API** - Email search, message retrieval
  - Service: `Travel app/Services/EmailScannerService.swift`
  - OAuth: ASWebAuthenticationSession with `gmail.readonly` scope
  - Token exchange: Supabase Edge Function `email-token-exchange`
  - Scanning: Edge Function `email-scanner` searches by known sender domains (booking.com, aviasales, rzd, aeroflot, etc.)
  - Returns: [EmailPreview] → AI parsing → [ScannedBooking]

- **Yandex Mail (IMAP)** - Email search via IMAP, message retrieval
  - Service: `Travel app/Services/EmailScannerService.swift`
  - OAuth: Custom Yandex OAuth flow (ASWebAuthenticationSession → token exchange)
  - Token exchange: Supabase Edge Function `email-token-exchange`
  - Scanning: Edge Function `email-scanner` IMAP search for travel emails
  - Returns: [EmailPreview] → AI parsing → [ScannedBooking]

**Booking Extraction:**
- **Vision Framework (Local)** - Receipt/ticket OCR
  - Service: `Travel app/Services/BookingScanService.swift`, `Travel app/Services/ReceiptScanService.swift`
  - Models: VNRecognizeTextRequest (language: ru+en, accuracy: .accurate)
  - Input: Photo, camera image, or text paste
  - Output: Raw OCR text → Gemini extraction → ScannedFlight or ScannedBooking
  - Used by: BookingScannerSheet (5 modes: photo, camera, text, email, receipt)

## Data Storage

**Databases:**
- **Supabase PostgreSQL** (Project: lwgcacwslkchspzygvum, eu-north-1 region)
  - Connection: SupabaseClient (URL: `Secrets.supabaseURL`, key: `Secrets.supabaseAnonKey`)
  - Client: supabase-swift v2.0+
  - Tables (with RLS + moddatetime triggers):
    - `profiles` - User metadata (full_name, provider)
    - `trips` - Trip master (name, country, startDate, endDate, budget, currency, flags, isCorporateTrip)
    - `days` - Trip days (trip_id, date, city, timeZone, notes)
    - `places` - Points of interest (day_id, name, category, lat/lon, notes)
    - `events` - Trip events (day_id, title, time, location, notes)
    - `expenses` - Budget tracking (trip_id, amount, category, date, description, receipt_path)
    - `tickets` - Flight/train tickets (trip_id, type, number, date, details)
    - `packing_items` - Packing list (trip_id, item, category, isPacked)
    - `journal_entries` - Travel journal (trip_id, day_id, title, content, photos)
    - `routes` - GPS tracking (trip_id, day_id, points with lat/lon/timestamp)
    - `trip_photos` - Photo gallery (trip_id, imageData, thumbnail, metadata)
    - `bucket_list` - Wish list items (destination, category, completed, photoData)
  - Sync: Bidirectional sync via SyncEngine with 60s debounce

**File Storage:**
- **Supabase Storage** - `trip-photos` bucket
  - Purpose: Trip photos, bucket list photos
  - Path structure: `{user_id}/{photo_uuid}.jpg` and `{user_id}/{photo_uuid}_thumb.jpg`
  - Service: `Travel app/Services/PhotoSyncService.swift`
  - Operations: upload (upsert), download, delete (via cleanup)

**Caching:**
- **UserDefaults** - Preferences, last sync timestamps, travel profile data, weather cache, currency rates
- **Keychain** - Secrets via KeychainHelper (Supabase key, OAuth tokens, API credentials)
- **AICacheManager** - AI response cache (7 day TTL, max 200 entries, per-prompt deduplication)
  - Path: `Travel app/Services/AICacheManager.swift`
- **In-Memory Dictionaries** - Service-level caches (AirLabsService flight cache, WeatherService by location, CurrencyService rates)

## Authentication & Identity

**Auth Provider:**
- **Supabase Auth (Managed)**
  - Implementation: `Travel app/Services/SupabaseAuthService.swift`
  - Methods:
    - Apple Sign In (IdToken flow)
    - Google OAuth (ASWebAuthenticationSession)
    - Yandex OAuth (custom + token exchange via Edge Function)
    - Email/Password (traditional signup/signin)
  - Session: Persisted via Supabase SDK
  - OAuth Callback Scheme: `travelapp://`
  - Token Storage: Handled by Supabase SDK
  - State Management: `Travel app/Services/AuthManager.swift` (@Observable wrapper)

**Profile Service:**
- **ProfileService.swift** - Reads user preferences (interests, diet, pace, chronotype, visited countries, bucket list)
  - Used for AI prompt personalization (AIPromptHelper.profileContext())

## Monitoring & Observability

**Error Tracking:**
- None detected (no Sentry, Crashlytics, etc.)
- Manual error logging via `print()` statements (being phased out in favor of proper logging)

**Logs:**
- **Approach:** Console logging with service-specific prefixes
  - Examples: `[GeminiService]`, `[EmailScanner]`, `[Weather]`, `[AirLabs]`
  - Location: Embedded in service classes, Console output only
- **No persistent logging** - errors displayed to user via UI alerts

**Network Monitoring:**
- **OfflineCacheManager** - NWPathMonitor for network status detection
  - Triggers: UserDefaults cache on offline, retries on online
  - UI Indicator: OfflineBanner (red capsule) in views

## CI/CD & Deployment

**Hosting:**
- App Store (iOS app)
- Supabase Cloud (backend)

**CI Pipeline:**
- None detected (no GitHub Actions, Xcode Cloud configured)
- Manual Xcode build + Archive + App Store Connect upload

**Deployment Configuration:**
- Supabase Edge Functions deployed manually (via Supabase CLI likely)
- Migrations applied manually (via Supabase SQL editor)

## Environment Configuration

**Required env vars (server-side, in Supabase Edge Function Secrets):**
- `SUPABASE_URL` - Supabase project URL (lwgcacwslkchspzygvum.eu-north-1.supabase.co)
- `SUPABASE_ANON_KEY` - Public anonymous key (in Info.plist as $(SUPABASE_ANON_KEY) in Secrets.xcconfig)
- `AIRLABS_API_KEY` - AirLabs API key
- `TRAVELPAYOUTS_TOKEN` - Travelpayouts token
- `GOOGLE_PLACES_API_KEY` - Google Places API key (for optional future use, not active)
- `GEMINI_API_KEY` - Google Gemini API key
- `GOOGLE_CLIENT_ID` - Google OAuth client ID (web client)
- `GOOGLE_CLIENT_SECRET` - Google OAuth client secret
- `YANDEX_CLIENT_ID` - Yandex OAuth client ID
- `YANDEX_CLIENT_SECRET` - Yandex OAuth client secret

**App-side config (Secrets.xcconfig + Keychain):**
- `SUPABASE_URL` - Supabase project URL (build-time)
- `SUPABASE_ANON_KEY` - Public key (build-time)
- `YANDEX_CLIENT_ID` - Passed to Info.plist for Yandex OAuth callback
- `GOOGLE_CLIENT_ID` - Passed to Info.plist for Gmail OAuth callback

**Secrets location:**
- Build-time secrets: `Secrets.xcconfig` (NOT committed, in .gitignore)
- Runtime secrets: Keychain via `Travel app/Services/KeychainHelper.swift`
- OAuth tokens: Supabase SDK session management + Keychain fallback

## Webhooks & Callbacks

**Incoming:**
- OAuth Callback: `travelapp://` custom scheme + `travelapp://auth-callback` (Apple/Google)
- OAuth Callback: `travelapp://yandex-callback` (Yandex)
- Email Token Exchange: Supabase Edge Function (one-way, app → Edge Function → OAuth provider)

**Outgoing:**
- Supabase Realtime subscriptions on tables (auto-sync on insert/update/delete)
- Email scanner → Gmail/Yandex APIs (via Edge Functions) → Email retrieval

## Third-Party SDKs Embedded

- **supabase-swift** v2.0+ - Entire backend, auth, storage, Edge Functions
  - No other major SDKs (Firebase, AWS SDK, etc.) detected

## Integration Testing Points

**Flight Data:**
- AirLabsService: `fetchFlight("SU1")` → FlightData with real times
- Example: `curl SupabaseProxy?service=airlabs&action=schedules&params={"flight_iata":"SU1"}`

**Weather:**
- WeatherService: `fetchWeather(coordinate)` → WeatherInfo
- Example: Moscow current weather, OpenMeteo API

**Currency:**
- CurrencyService: rates auto-refresh, fallback matrix works offline
- Example: RUB→JPY conversion rates

**Email Scanner:**
- EmailScannerService: OAuth → token exchange → email search → AI parsing
- Example: Gmail search "from:booking.com" → ScannedBooking

**Sync:**
- SyncManager: `forceSync()` pushes/pulls from Supabase, 60s debounce
- Conflict resolution: last-write-wins (timestamp-based)

---

*Integration audit: 2026-03-20*
