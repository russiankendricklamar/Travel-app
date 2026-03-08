# Email Scanner Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Parse travel bookings (flights, hotels, trains, car rentals) from Gmail and Yandex.Mail via OAuth + Supabase Edge Functions + Gemini AI extraction.

**Architecture:** Client-side OAuth (ASWebAuthenticationSession) gets auth code → `email-token-exchange` Edge Function exchanges for access_token → `email-scanner` Edge Function fetches matching emails from Gmail REST / Yandex IMAP → client feeds email text to Gemini → parsed ScannedBooking results displayed in BookingScannerSheet.

**Tech Stack:** SwiftUI, Supabase Edge Functions (Deno/TypeScript), Gmail REST API, Yandex IMAP, Gemini AI, ASWebAuthenticationSession

**Design doc:** `docs/plans/2026-03-08-email-scanner-design.md`

---

## Task 1: Data Models

**Files:**
- Create: `Travel app/Travel app/Models/ScannedBooking.swift`

**Step 1: Create ScannedBooking model file**

```swift
import Foundation

// MARK: - Booking Type

enum BookingType: String, Codable, CaseIterable {
    case flight
    case hotel
    case train
    case carRental = "car_rental"
    case bus
    case transfer

    var label: String {
        switch self {
        case .flight: return "Авиарейс"
        case .hotel: return "Отель"
        case .train: return "Поезд"
        case .carRental: return "Авто"
        case .bus: return "Автобус"
        case .transfer: return "Трансфер"
        }
    }

    var icon: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "bed.double.fill"
        case .train: return "tram.fill"
        case .carRental: return "car.fill"
        case .bus: return "bus.fill"
        case .transfer: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Scanned Booking

struct ScannedBooking: Identifiable {
    let id = UUID()
    let type: BookingType
    var title: String
    var subtitle: String?
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

    /// Convert to ScannedFlight for backward compat with existing flight flow
    func toScannedFlight() -> ScannedFlight? {
        guard type == .flight else { return nil }
        return ScannedFlight(
            number: flightNumber ?? title,
            date: date,
            departureIata: departureIata,
            arrivalIata: arrivalIata
        )
    }
}

// MARK: - Email Preview

struct EmailPreview: Identifiable {
    let id: String
    let subject: String
    let from: String
    let date: Date
    let bodyText: String
    var isSelected: Bool = true
}
```

**Step 2: Commit**

```bash
git add "Travel app/Travel app/Models/ScannedBooking.swift"
git commit -m "feat: add ScannedBooking model with BookingType enum and EmailPreview"
```

---

## Task 2: Deploy `email-token-exchange` Edge Function

**Files:**
- Deploy: Supabase Edge Function `email-token-exchange`

**Step 1: Deploy the Edge Function via Supabase MCP**

Use `mcp__plugin_supabase_supabase__deploy_edge_function` with project_id `lwgcacwslkchspzygvum`.

Function name: `email-token-exchange`

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { provider, code, redirect_uri } = await req.json();

    if (!provider || !code || !redirect_uri) {
      return new Response(
        JSON.stringify({ error: "Missing provider, code, or redirect_uri" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    let tokenUrl: string;
    let body: string;

    if (provider === "gmail") {
      const clientId = Deno.env.get("GOOGLE_CLIENT_ID") ?? "";
      const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET") ?? "";
      tokenUrl = "https://oauth2.googleapis.com/token";
      body = new URLSearchParams({
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirect_uri,
        grant_type: "authorization_code",
      }).toString();
    } else if (provider === "yandex") {
      const clientId = Deno.env.get("YANDEX_CLIENT_ID") ?? "";
      const clientSecret = Deno.env.get("YANDEX_CLIENT_SECRET") ?? "";
      tokenUrl = "https://oauth.yandex.ru/token";
      body = new URLSearchParams({
        code,
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: "authorization_code",
      }).toString();
    } else {
      return new Response(
        JSON.stringify({ error: `Unknown provider: ${provider}` }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const tokenResp = await fetch(tokenUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    });

    const tokenData = await tokenResp.json();

    if (!tokenResp.ok) {
      return new Response(
        JSON.stringify({ error: tokenData.error_description || tokenData.error || "Token exchange failed" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ access_token: tokenData.access_token }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
```

verify_jwt: true (requires Supabase anon key)

**Step 2: Set secrets in Supabase Dashboard**

User must manually set in Supabase Dashboard → Edge Functions → Secrets:
- `GOOGLE_CLIENT_ID` — from Google Cloud Console
- `GOOGLE_CLIENT_SECRET` — from Google Cloud Console
- `YANDEX_CLIENT_ID` — existing (same as in app)
- `YANDEX_CLIENT_SECRET` — existing (same as in app)

---

## Task 3: Deploy `email-scanner` Edge Function

**Files:**
- Deploy: Supabase Edge Function `email-scanner`

**Step 1: Deploy the Edge Function via Supabase MCP**

Use `mcp__plugin_supabase_supabase__deploy_edge_function` with project_id `lwgcacwslkchspzygvum`.

Function name: `email-scanner`

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Known travel booking senders
const TRAVEL_SENDERS = [
  "aviasales", "booking.com", "airbnb", "s7", "aeroflot", "rzd",
  "pobeda", "utair", "tutu", "ostrovok", "sutochno", "rentalcars",
  "hotels.com", "agoda", "trip.com", "ozon.travel", "kupibilet",
  "biletix", "onetwotrip", "anywayanyday", "skyscanner",
];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { provider, access_token, max_results = 20, days_back = 90 } = await req.json();

    if (!provider || !access_token) {
      return new Response(
        JSON.stringify({ error: "Missing provider or access_token" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    let emails: any[];

    if (provider === "gmail") {
      emails = await searchGmail(access_token, max_results, days_back);
    } else if (provider === "yandex") {
      emails = await searchYandexIMAP(access_token, max_results, days_back);
    } else {
      return new Response(
        JSON.stringify({ error: `Unknown provider: ${provider}` }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ emails }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});

// MARK: - Gmail REST API

async function searchGmail(
  token: string,
  maxResults: number,
  daysBack: number
): Promise<any[]> {
  const fromQuery = TRAVEL_SENDERS.map((s) => `from:${s}`).join(" OR ");
  const query = `(${fromQuery}) newer_than:${daysBack}d`;

  // 1. Search for message IDs
  const searchUrl = `https://gmail.googleapis.com/gmail/v1/users/me/messages?q=${encodeURIComponent(query)}&maxResults=${maxResults}`;
  const searchResp = await fetch(searchUrl, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!searchResp.ok) {
    const err = await searchResp.text();
    throw new Error(`Gmail search failed: ${searchResp.status} ${err}`);
  }

  const searchData = await searchResp.json();
  const messageIds: string[] = (searchData.messages || []).map((m: any) => m.id);

  if (messageIds.length === 0) return [];

  // 2. Fetch each message in parallel (limit to maxResults)
  const fetches = messageIds.slice(0, maxResults).map(async (id) => {
    const msgUrl = `https://gmail.googleapis.com/gmail/v1/users/me/messages/${id}?format=full`;
    const msgResp = await fetch(msgUrl, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!msgResp.ok) return null;
    return msgResp.json();
  });

  const messages = (await Promise.all(fetches)).filter(Boolean);

  return messages.map((msg: any) => {
    const headers = msg.payload?.headers || [];
    const subject = headers.find((h: any) => h.name.toLowerCase() === "subject")?.value || "";
    const from = headers.find((h: any) => h.name.toLowerCase() === "from")?.value || "";
    const date = headers.find((h: any) => h.name.toLowerCase() === "date")?.value || "";
    const bodyText = extractGmailText(msg.payload);

    return {
      id: msg.id,
      subject,
      from,
      date,
      body_text: bodyText.slice(0, 3000),
    };
  });
}

function extractGmailText(payload: any): string {
  if (!payload) return "";

  // Direct body
  if (payload.mimeType === "text/plain" && payload.body?.data) {
    return atob(payload.body.data.replace(/-/g, "+").replace(/_/g, "/"));
  }

  // Multipart — recurse
  if (payload.parts) {
    // Prefer text/plain
    for (const part of payload.parts) {
      if (part.mimeType === "text/plain" && part.body?.data) {
        return atob(part.body.data.replace(/-/g, "+").replace(/_/g, "/"));
      }
    }
    // Fallback: text/html stripped
    for (const part of payload.parts) {
      if (part.mimeType === "text/html" && part.body?.data) {
        const html = atob(part.body.data.replace(/-/g, "+").replace(/_/g, "/"));
        return html.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
      }
    }
    // Nested multipart
    for (const part of payload.parts) {
      const text = extractGmailText(part);
      if (text) return text;
    }
  }

  return "";
}

// MARK: - Yandex IMAP

async function searchYandexIMAP(
  token: string,
  maxResults: number,
  daysBack: number
): Promise<any[]> {
  // Yandex IMAP requires raw TCP with TLS — use Deno.connect
  const conn = await Deno.connectTls({
    hostname: "imap.yandex.ru",
    port: 993,
  });

  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  async function readResponse(): Promise<string> {
    const buf = new Uint8Array(16384);
    let result = "";
    // Read until we get a tagged response or timeout
    const timeoutMs = 10000;
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
      const n = await conn.read(buf);
      if (n === null) break;
      result += decoder.decode(buf.subarray(0, n));
      // Check if response is complete (tagged line)
      if (/^[A-Z]\d+ (OK|NO|BAD)/m.test(result)) break;
    }
    return result;
  }

  async function sendCommand(tag: string, cmd: string): Promise<string> {
    await conn.write(encoder.encode(`${tag} ${cmd}\r\n`));
    return readResponse();
  }

  try {
    // Read greeting
    await readResponse();

    // Authenticate with XOAUTH2
    const authString = btoa(`user=\x01auth=Bearer ${token}\x01\x01`);
    // Wait, XOAUTH2 needs the email. We need to get it from the token first.
    // For Yandex, we can get user info from the token
    const userInfoResp = await fetch("https://login.yandex.ru/info?format=json", {
      headers: { Authorization: `OAuth ${token}` },
    });
    const userInfo = await userInfoResp.json();
    const email = userInfo.default_email || "";

    if (!email) {
      throw new Error("Could not determine Yandex email from token");
    }

    const xoauth2 = btoa(`user=${email}\x01auth=Bearer ${token}\x01\x01`);
    const authResp = await sendCommand("A1", `AUTHENTICATE XOAUTH2 ${xoauth2}`);
    if (!authResp.includes("A1 OK")) {
      throw new Error("Yandex IMAP auth failed: " + authResp.slice(0, 200));
    }

    // Select INBOX
    await sendCommand("A2", "SELECT INBOX");

    // Search for travel emails
    const sinceDate = new Date();
    sinceDate.setDate(sinceDate.getDate() - daysBack);
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    const sinceStr = `${sinceDate.getDate()}-${months[sinceDate.getMonth()]}-${sinceDate.getFullYear()}`;

    // Build OR search for known senders
    const senderCriteria = TRAVEL_SENDERS.slice(0, 10)
      .map((s) => `FROM "${s}"`)
      .join(" ");
    // IMAP OR syntax: OR (FROM "a") (FROM "b") — nested
    let searchCmd = `SEARCH SINCE ${sinceStr} OR ${TRAVEL_SENDERS.slice(0, 2).map(s => `FROM "${s}"`).join(" OR ")}`;
    // Simplified: just search recent + known senders one by one, collect unique IDs
    const allIds = new Set<string>();
    for (const sender of TRAVEL_SENDERS.slice(0, 10)) {
      const resp = await sendCommand("A3", `SEARCH SINCE ${sinceStr} FROM "${sender}"`);
      const match = resp.match(/\* SEARCH (.+)/);
      if (match) {
        match[1].trim().split(/\s+/).forEach((id) => allIds.add(id));
      }
    }

    const ids = Array.from(allIds).slice(0, maxResults);
    if (ids.length === 0) {
      await sendCommand("A99", "LOGOUT");
      conn.close();
      return [];
    }

    // Fetch each message
    const emails: any[] = [];
    for (const msgId of ids) {
      const fetchResp = await sendCommand("A4", `FETCH ${msgId} (BODY[HEADER.FIELDS (FROM SUBJECT DATE)] BODY[TEXT])`);

      const subjectMatch = fetchResp.match(/Subject:\s*(.+)/i);
      const fromMatch = fetchResp.match(/From:\s*(.+)/i);
      const dateMatch = fetchResp.match(/Date:\s*(.+)/i);

      // Extract text body (between the fetch markers)
      const bodyStart = fetchResp.indexOf("\r\n\r\n");
      let bodyText = bodyStart > -1 ? fetchResp.slice(bodyStart + 4) : "";
      // Clean up IMAP artifacts
      bodyText = bodyText.replace(/\)\r\n[A-Z]\d+ OK.*/s, "").trim();
      // Strip HTML if present
      if (bodyText.includes("<html") || bodyText.includes("<div")) {
        bodyText = bodyText.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
      }

      emails.push({
        id: msgId,
        subject: subjectMatch?.[1]?.trim() || "",
        from: fromMatch?.[1]?.trim() || "",
        date: dateMatch?.[1]?.trim() || "",
        body_text: bodyText.slice(0, 3000),
      });
    }

    await sendCommand("A99", "LOGOUT");
    conn.close();
    return emails;
  } catch (e) {
    try { conn.close(); } catch {}
    throw e;
  }
}
```

verify_jwt: true

---

## Task 4: Secrets.swift — Add Google Client ID accessor

**Files:**
- Modify: `Travel app/Travel app/Config/Secrets.swift`

**Step 1: Add googleClientID to Secrets**

After `yandexClientSecret` section (~line 26), add:

```swift
static var googleClientID: String {
    KeychainHelper.readString(key: "googleClientID") ?? infoPlistValue("GOOGLE_CLIENT_ID")
}

static func setGoogleClientID(_ key: String) {
    KeychainHelper.save(key: "googleClientID", string: key)
}
```

**Step 2: Add GOOGLE_CLIENT_ID to Secrets.xcconfig**

User must add `GOOGLE_CLIENT_ID = {value}` after obtaining it from Google Cloud Console.

**Step 3: Commit**

```bash
git add "Travel app/Travel app/Config/Secrets.swift"
git commit -m "feat: add Google Client ID accessor to Secrets"
```

---

## Task 5: EmailScannerService — OAuth + Edge Function calls + AI parsing

**Files:**
- Create: `Travel app/Travel app/Services/EmailScannerService.swift`

**Step 1: Create EmailScannerService**

```swift
import Foundation
import AuthenticationServices
import SwiftUI

// MARK: - Email Scanner Service

@MainActor
@Observable
final class EmailScannerService {
    static let shared = EmailScannerService()
    private let contextProvider = EmailAuthContextProvider()
    private init() {}

    enum Provider: String, CaseIterable {
        case gmail, yandex

        var label: String {
            switch self {
            case .gmail: return "Gmail"
            case .yandex: return "Яндекс"
            }
        }

        var icon: String {
            switch self {
            case .gmail: return "envelope.fill"
            case .yandex: return "envelope.fill"
            }
        }

        var color: Color {
            switch self {
            case .gmail: return .red
            case .yandex: return .yellow
            }
        }
    }

    enum ScanState: Equatable {
        case idle
        case authorizing
        case searching
        case selectEmails
        case parsing
        case results
        case error(String)

        static func == (lhs: ScanState, rhs: ScanState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.authorizing, .authorizing),
                 (.searching, .searching), (.selectEmails, .selectEmails),
                 (.parsing, .parsing), (.results, .results):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    var state: ScanState = .idle
    var foundEmails: [EmailPreview] = []
    var scannedBookings: [ScannedBooking] = []
    var searchProgress: Int = 0

    private static let oauthCallbackScheme = "travelapp"
    private static let tokenExchangeURL = "\(Secrets.supabaseURL)/functions/v1/email-token-exchange"
    private static let emailScannerURL = "\(Secrets.supabaseURL)/functions/v1/email-scanner"

    // MARK: - Full Flow

    func scan(provider: Provider) async {
        state = .authorizing

        do {
            // 1. OAuth → auth code
            let authCode = try await authorize(provider: provider)

            // 2. Exchange code → access token
            let accessToken = try await exchangeToken(
                provider: provider,
                code: authCode
            )

            // 3. Fetch emails from mailbox
            state = .searching
            foundEmails = try await fetchEmails(
                provider: provider,
                token: accessToken
            )

            if foundEmails.isEmpty {
                state = .error("Письма с бронированиями не найдены")
                return
            }

            state = .selectEmails
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func parseSelectedEmails() async {
        let selected = foundEmails.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        state = .parsing

        do {
            scannedBookings = try await parseEmails(selected)
            if scannedBookings.isEmpty {
                state = .error("Не удалось распознать бронирования")
            } else {
                state = .results
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
        foundEmails = []
        scannedBookings = []
        searchProgress = 0
    }

    // MARK: - OAuth

    private func authorize(provider: Provider) async throws -> String {
        let authURL: URL
        let callbackScheme = Self.oauthCallbackScheme

        switch provider {
        case .gmail:
            let clientID = Secrets.googleClientID
            guard !clientID.isEmpty else {
                throw EmailScanError.missingClientID
            }
            let redirectURI = "\(callbackScheme)://gmail-callback"
            let scope = "https://www.googleapis.com/auth/gmail.readonly"
            authURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=\(scope)&access_type=offline&prompt=consent")!

        case .yandex:
            let clientID = Secrets.yandexClientID
            guard !clientID.isEmpty else {
                throw EmailScanError.missingClientID
            }
            let redirectURI = "\(callbackScheme)://yandex-mail-callback"
            authURL = URL(string: "https://oauth.yandex.ru/authorize?response_type=code&client_id=\(clientID)&redirect_uri=\(redirectURI)&scope=mail:imap_full&force_confirm=yes")!
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: EmailScanError.authFailed)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self.contextProvider
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        // Extract code from callback URL
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw EmailScanError.authFailed
        }

        return code
    }

    // MARK: - Token Exchange

    private func exchangeToken(provider: Provider, code: String) async throws -> String {
        guard let url = URL(string: Self.tokenExchangeURL) else {
            throw EmailScanError.badURL
        }

        let redirectURI: String
        switch provider {
        case .gmail: redirectURI = "\(Self.oauthCallbackScheme)://gmail-callback"
        case .yandex: redirectURI = "\(Self.oauthCallbackScheme)://yandex-mail-callback"
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15

        let body: [String: String] = [
            "provider": provider.rawValue,
            "code": code,
            "redirect_uri": redirectURI,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = errorBody?["error"] as? String ?? "Token exchange failed"
            throw EmailScanError.tokenExchangeFailed(msg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw EmailScanError.tokenExchangeFailed("No access_token in response")
        }

        return accessToken
    }

    // MARK: - Fetch Emails

    private func fetchEmails(provider: Provider, token: String) async throws -> [EmailPreview] {
        guard let url = URL(string: Self.emailScannerURL) else {
            throw EmailScanError.badURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        let body: [String: Any] = [
            "provider": provider.rawValue,
            "access_token": token,
            "max_results": 20,
            "days_back": 90,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw EmailScanError.fetchFailed(code)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let emailsArray = json["emails"] as? [[String: Any]] else {
            return []
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]

        // Also handle RFC 2822 dates from email headers
        let rfcFormatter = DateFormatter()
        rfcFormatter.locale = Locale(identifier: "en_US_POSIX")
        rfcFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

        return emailsArray.compactMap { email in
            guard let id = email["id"] as? String,
                  let subject = email["subject"] as? String,
                  let bodyText = email["body_text"] as? String else {
                return nil
            }

            let from = email["from"] as? String ?? ""
            let dateStr = email["date"] as? String ?? ""
            let date = dateFormatter.date(from: dateStr)
                ?? rfcFormatter.date(from: dateStr)
                ?? Date()

            return EmailPreview(
                id: id,
                subject: subject,
                from: from,
                date: date,
                bodyText: bodyText
            )
        }
    }

    // MARK: - AI Parsing

    private func parseEmails(_ emails: [EmailPreview]) async throws -> [ScannedBooking] {
        var allBookings: [ScannedBooking] = []

        for email in emails {
            let combinedText = "Тема: \(email.subject)\nОт: \(email.from)\n\n\(email.bodyText)"
            let bookings = try await parseBookingText(combinedText)
            allBookings.append(contentsOf: bookings)
        }

        return allBookings
    }

    private func parseBookingText(_ text: String) async throws -> [ScannedBooking] {
        let prompt = """
        Извлеки ВСЕ бронирования из письма. Только JSON массив:
        [{"type":"flight|hotel|train|car_rental|bus|transfer",
          "title":"SU260", "subtitle":"SVO → NRT",
          "date":"2026-04-15T10:30", "endDate":"2026-04-20T12:00",
          "confirmationCode":"ABC123", "price":15000, "currency":"RUB",
          "departureIata":"SVO", "arrivalIata":"NRT", "flightNumber":"SU260",
          "hotelName":"Novotel", "address":"ул. Ленина 5",
          "trainNumber":"020А", "seatInfo":"Вагон 5, место 23"}]

        Только заполненные поля. Если бронирований нет — [].

        Текст письма:
        \(text.prefix(4000))
        """

        guard let raw = await GeminiService.shared.rawRequest(prompt: prompt) else {
            throw EmailScanError.aiUnavailable
        }

        return parseBookingJSON(raw)
    }

    private func parseBookingJSON(_ raw: String) -> [ScannedBooking] {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "["),
              let end = cleaned.lastIndex(of: "]") else {
            return []
        }

        let jsonString = String(cleaned[start...end])
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")

        return array.compactMap { dict -> ScannedBooking? in
            guard let typeStr = dict["type"] as? String,
                  let type = BookingType(rawValue: typeStr),
                  let title = dict["title"] as? String else {
                return nil
            }

            func parseDate(_ key: String) -> Date? {
                guard let str = dict[key] as? String, !str.isEmpty else { return nil }
                return isoFormatter.date(from: str) ?? fallbackFormatter.date(from: str)
            }

            return ScannedBooking(
                type: type,
                title: title,
                subtitle: dict["subtitle"] as? String,
                date: parseDate("date"),
                endDate: parseDate("endDate"),
                confirmationCode: dict["confirmationCode"] as? String,
                price: dict["price"] as? Double,
                currency: dict["currency"] as? String,
                departureIata: (dict["departureIata"] as? String)?.uppercased(),
                arrivalIata: (dict["arrivalIata"] as? String)?.uppercased(),
                flightNumber: (dict["flightNumber"] as? String)?.uppercased(),
                hotelName: dict["hotelName"] as? String,
                address: dict["address"] as? String,
                trainNumber: dict["trainNumber"] as? String,
                seatInfo: dict["seatInfo"] as? String
            )
        }
    }

    // MARK: - Errors

    enum EmailScanError: LocalizedError {
        case missingClientID
        case authFailed
        case badURL
        case tokenExchangeFailed(String)
        case fetchFailed(Int)
        case aiUnavailable

        var errorDescription: String? {
            switch self {
            case .missingClientID: return "Client ID не настроен. Проверьте настройки"
            case .authFailed: return "Не удалось авторизоваться"
            case .badURL: return "Некорректный URL"
            case .tokenExchangeFailed(let msg): return "Ошибка авторизации: \(msg)"
            case .fetchFailed(let code): return "Ошибка загрузки писем: HTTP \(code)"
            case .aiUnavailable: return "AI-провайдер недоступен"
            }
        }
    }
}

// MARK: - ASWebAuthenticationSession context

private class EmailAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
```

**Step 2: Commit**

```bash
git add "Travel app/Travel app/Services/EmailScannerService.swift"
git commit -m "feat: add EmailScannerService — OAuth + Edge Function calls + AI parsing"
```

---

## Task 6: Update BookingScannerSheet — Add email mode

**Files:**
- Modify: `Travel app/Travel app/Views/Dashboard/BookingScannerSheet.swift`

**Step 1: Add `.email` to InputMode enum**

In the `InputMode` enum (~line 502), add `.email` case:

```swift
private enum InputMode: CaseIterable {
    case photo, camera, pdf, text, email

    var label: String {
        switch self {
        // ... existing cases ...
        case .email: return "ПОЧТА"
        }
    }

    var icon: String {
        switch self {
        // ... existing cases ...
        case .email: return "envelope.fill"
        }
    }
}
```

**Step 2: Add onBookingsAdded callback**

Add optional callback to BookingScannerSheet struct:

```swift
struct BookingScannerSheet: View {
    let onFlightsAdded: ([ScannedFlight]) -> Void
    var onBookingsAdded: (([ScannedBooking]) -> Void)? = nil
    // ...
}
```

**Step 3: Add email UI state and views**

Add `@State private var emailService = EmailScannerService.shared` property.

In the `switch state` / `switch inputMode` body, add `.email` case rendering `emailSection`.

Build `emailSection` with 4 sub-states matching `EmailScannerService.ScanState`:
- `.idle` → provider selection (two glass cards: Gmail / Yandex)
- `.authorizing` / `.searching` → ProgressView with status text
- `.selectEmails` → checkbox list of found emails + "РАСПОЗНАТЬ (N)" button
- `.parsing` → ProgressView "Распознаю бронирования..."
- `.results` → booking cards with type icons + "ДОБАВИТЬ" button
- `.error` → error message + "ПОПРОБОВАТЬ СНОВА" button

**Step 4: Add result handling**

"ДОБАВИТЬ" button splits results:
- `.flight` bookings → convert via `toScannedFlight()` → call `onFlightsAdded`
- Other bookings → call `onBookingsAdded`

**Step 5: Commit**

```bash
git add "Travel app/Travel app/Views/Dashboard/BookingScannerSheet.swift"
git commit -m "feat: add email scanning mode to BookingScannerSheet"
```

---

## Task 7: Integration + Final commit

**Files:**
- Verify build compiles
- Update `Secrets.xcconfig` placeholder for GOOGLE_CLIENT_ID

**Step 1: Add placeholder to Secrets.xcconfig**

```
GOOGLE_CLIENT_ID =
```

(User fills in after creating Google Cloud OAuth client)

**Step 2: Verify Xcode build**

Build the project targeting iPhone 16 Pro Max simulator.

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete email scanner integration — Gmail + Yandex mail parsing"
```

---

## Required Manual Steps (User)

1. **Google Cloud Console:**
   - Go to console.cloud.google.com → APIs & Services
   - Enable Gmail API
   - Create OAuth 2.0 Client ID (iOS type)
   - Set bundle ID and `travelapp://gmail-callback` redirect
   - Copy Client ID → `Secrets.xcconfig` → `GOOGLE_CLIENT_ID = {value}`
   - Copy Client Secret → Supabase Dashboard → Edge Function Secrets → `GOOGLE_CLIENT_SECRET`

2. **Supabase Dashboard → Edge Function Secrets:**
   - `GOOGLE_CLIENT_ID` — same as xcconfig
   - `GOOGLE_CLIENT_SECRET` — from Google Cloud Console
   - `YANDEX_CLIENT_ID` — existing value
   - `YANDEX_CLIENT_SECRET` — existing value

3. **Yandex OAuth app:**
   - Verify `mail:imap_full` scope is enabled in Yandex OAuth app settings
   - Add `travelapp://yandex-mail-callback` as redirect URI
