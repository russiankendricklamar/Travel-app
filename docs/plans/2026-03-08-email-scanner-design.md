# Email Scanner — Design Document

**Date:** 2026-03-08
**Session:** 26
**Status:** Approved

## Overview

Parse travel bookings (flights, hotels, trains, car rentals) from Gmail and Yandex.Mail via OAuth + Supabase Edge Function + Gemini AI. New "ПОЧТА" mode in existing BookingScannerSheet.

## Architecture

```
User taps "ПОЧТА" → OAuth (gmail.readonly / mail:imap_full)
    → auth code sent to Edge Function `email-token-exchange`
    → access_token returned to client
    → token sent to Edge Function `email-scanner`
    → Edge Function searches Gmail REST / Yandex IMAP
    → email texts returned to client
    → client sends texts to Gemini via BookingScanService
    → ScannedBooking[] displayed → user selects → added to trip
```

## 1. Data Models

### ScannedBooking (new)

```swift
enum BookingType: String, Codable {
    case flight, hotel, train, carRental, bus, transfer
}

struct ScannedBooking: Identifiable {
    let id = UUID()
    let type: BookingType
    var title: String           // "SU260" / "Novotel Moscow" / "РЖД 020А"
    var subtitle: String?       // "SVO → NRT" / "2 ночи"
    var date: Date?
    var endDate: Date?
    var confirmationCode: String?
    var price: Double?
    var currency: String?
    // Flight-specific
    var departureIata: String?
    var arrivalIata: String?
    var flightNumber: String?
    // Hotel-specific
    var hotelName: String?
    var address: String?
    // Train-specific
    var trainNumber: String?
    var seatInfo: String?
}
```

ScannedFlight remains for backward compatibility. ScannedBooking with type == .flight converts to ScannedFlight.

## 2. Edge Functions

### `email-token-exchange`

Exchanges OAuth auth code for access_token server-side (keeps client_secret on server).

**Request:**
```json
{
  "provider": "gmail" | "yandex",
  "code": "auth_code_from_oauth",
  "redirect_uri": "travelapp://gmail-callback"
}
```

**Response:**
```json
{ "access_token": "ya29.xxx..." }
```

**Server-side secrets:** `GOOGLE_CLIENT_SECRET`, `YANDEX_CLIENT_SECRET`

### `email-scanner`

Searches mailbox for travel booking emails.

**Request:**
```json
{
  "provider": "gmail" | "yandex",
  "access_token": "ya29.xxx...",
  "max_results": 20,
  "days_back": 90
}
```

**Response:**
```json
{
  "emails": [
    {
      "id": "msg_123",
      "subject": "Подтверждение бронирования SU260",
      "from": "no-reply@aviasales.ru",
      "date": "2026-03-01T10:00:00Z",
      "body_text": "Ваш рейс SU260..."
    }
  ]
}
```

**Gmail implementation:** REST API
- Search: `GET /gmail/v1/users/me/messages?q=from:(aviasales OR booking.com OR airbnb OR s7 OR aeroflot OR rzd OR pobeda OR utair OR tutu OR ostrovok OR sutochno OR rentalcars) newer_than:90d`
- Fetch: `GET /gmail/v1/users/me/messages/{id}?format=full` → extract text/plain

**Yandex implementation:** IMAP
- Connect to `imap.yandex.ru:993` with XOAUTH2
- `SEARCH FROM "aviasales" OR FROM "booking.com" ... SINCE {date}`
- `FETCH {id} BODY[TEXT]`

**Security:** Token is one-time use, not stored. Email content not logged.

## 3. Client Service — EmailScannerService

```swift
@MainActor @Observable
final class EmailScannerService {
    enum Provider: String, CaseIterable { case gmail, yandex }

    enum ScanState {
        case idle
        case authorizing
        case searching
        case selectEmails([EmailPreview])
        case parsing
        case results([ScannedBooking])
        case error(String)
    }

    var state: ScanState = .idle

    func authorize(provider: Provider) async throws -> String
    func fetchEmails(provider: Provider, token: String) async throws -> [EmailPreview]
    func parseEmails(_ emails: [EmailPreview]) async throws -> [ScannedBooking]
}
```

**OAuth flows (ASWebAuthenticationSession):**
- Gmail: `accounts.google.com/o/oauth2/v2/auth?scope=gmail.readonly&client_id={ID}&redirect_uri=travelapp://gmail-callback&response_type=code`
- Yandex: `oauth.yandex.ru/authorize?scope=mail:imap_full&client_id={ID}&redirect_uri=travelapp://yandex-callback&response_type=code`

Auth code exchanged via `email-token-exchange` Edge Function.

**AI prompt (expanded):**
```
Извлеки все бронирования из текста. JSON:
[{"type":"flight|hotel|train|car_rental|bus|transfer",
  "title":"SU260", "subtitle":"SVO → NRT",
  "date":"2026-04-15T10:30", "endDate":"...",
  "confirmationCode":"ABC123", "price":15000, "currency":"RUB",
  "departureIata":"SVO", "arrivalIata":"NRT", "flightNumber":"SU260",
  "hotelName":"...", "address":"...",
  "trainNumber":"020А", "seatInfo":"Вагон 5, место 23"}]
Только заполненные поля. Если бронирований нет — [].
```

## 4. UI — BookingScannerSheet

### New InputMode: `.email`
- Icon: `envelope.fill`, label: "ПОЧТА"
- 5th tab in existing mode picker

### Flow (4 steps):

**Step 1 — Provider selection:** Two glass cards (Gmail / Yandex). Tap → OAuth.

**Step 2 — Searching:** ProgressView + counter. Edge Function working.

**Step 3 — Email selection:** Checkbox list of found emails (subject + sender + date). "РАСПОЗНАТЬ (N)" button.

**Step 4 — Results:** ScannedBooking cards with type icons (airplane/bed/tram/car). "ДОБАВИТЬ" button.

### Callbacks:
- `onFlightsAdded` — existing, for .flight bookings → ScannedFlight conversion
- `onBookingsAdded` — new optional, for hotel/train/car → creates TripEvent

## 5. New Files

| File | Purpose |
|------|---------|
| `Services/EmailScannerService.swift` | OAuth + Edge Function calls + AI parsing |
| `Models/ScannedBooking.swift` | BookingType enum + ScannedBooking struct + EmailPreview |
| Edge Function `email-token-exchange` | OAuth code → token exchange |
| Edge Function `email-scanner` | Gmail REST / Yandex IMAP search |

## 6. Modified Files

| File | Changes |
|------|---------|
| `BookingScannerSheet.swift` | Add .email InputMode, email flow UI |
| `BookingScanService.swift` | Expanded AI prompt for all booking types |
| `Secrets.swift` | Google Client ID accessor (from xcconfig) |
| `Secrets.xcconfig` | GOOGLE_CLIENT_ID value |

## 7. Required Manual Steps

- Google Cloud Console: enable Gmail API, add iOS client ID with `travelapp://` redirect
- Supabase Dashboard: set `GOOGLE_CLIENT_SECRET` and `YANDEX_CLIENT_SECRET` in Edge Function secrets
