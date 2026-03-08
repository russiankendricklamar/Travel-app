# AI Trip Generator — Design Doc

**Date:** 2026-03-08
**Status:** Approved
**Author:** EG + Claude

## Summary

AI-powered trip creation wizard. User provides destination (or asks AI to suggest), dates, budget, and travel style. AI generates a full itinerary with day-by-day places, real flight prices (Travelpayouts), and hotel options. User previews, edits, then saves.

## Entry Point

Two buttons on HomeView:
- "Создать вручную" — existing CreateTripSheet
- "Создать с AI" — new AITripWizardView (fullScreenCover)

## Wizard Steps (4 steps)

### Step 1: Destination
- Text field with MKLocalSearchCompleter autocomplete
- "Подскажи мне" button — AI suggests 3-5 destinations based on:
  - User profile (AIPromptHelper.profileContext)
  - Best season for selected dates
  - Cheap flights from Travelpayouts API
- Cards with country flag, brief description, estimated cost
- Also has "Откуда" field (default: MOW, stored in settings)

### Step 2: Dates
- DatePicker: start date — end date
- AI hint: season recommendation for chosen destination

### Step 3: Budget
- Slider + text input in user's currency
- Quick chips: "Эконом" / "Средний" / "Без ограничений"

### Step 4: Style
- Multi-select chips: Активный, Расслабленный, Культурный, Гастро, Приключения, Шоппинг
- "СГЕНЕРИРОВАТЬ ПОЕЗДКУ" button

## Generation Flow

1. AI prompt (Gemini) generates JSON:
   ```json
   {
     "days": [
       {
         "city": "Istanbul",
         "places": [
           {"name": "...", "category": "...", "lat": 0, "lng": 0, "timeToSpend": "2h", "description": "..."}
         ]
       }
     ],
     "suggestedFlights": [
       {"from": "MOW", "to": "IST", "date": "2026-03-12"},
       {"from": "IST", "to": "MOW", "date": "2026-03-22"}
     ],
     "cities": ["Istanbul", "Cappadocia"]
   }
   ```

2. Parallel Travelpayouts requests:
   - `searchFlights(from:to:date:)` for each suggested flight
   - `searchHotels(city:checkIn:checkOut:)` for each city

3. Combined into `AIGeneratedTrip`:
   - days with places
   - flight offers with real prices
   - hotel offers with real prices
   - total estimated cost

## Preview Screen (AITripPreviewView)

- Header: destination + duration + total cost
- Day cards: scrollable list, each day shows city + places (swipe to delete place)
- Flights section: cards with price, airline, departure/arrival, [Выбрать] button
- Hotels section: grouped by city, name + stars + price/night, [Выбрать] button
- Budget indicator: total vs user's budget (warning if over)
- Bottom: [СОЗДАТЬ ПОЕЗДКУ] + [ПЕРЕГЕНЕРИРОВАТЬ]

## Save Flow

"СОЗДАТЬ ПОЕЗДКУ" converts AIGeneratedTrip to SwiftData models:
- Trip (name, country, dates, budget)
- TripDay[] (one per day, with cityName)
- Place[] (attached to respective TripDay)
- TripFlight[] (from selected flight offers)
- Selected hotel info stored as notes/metadata on TripDay

## New Files

```
Services/
  TravelpayoutsService.swift        — Flights + Hotels API client
  AITripGeneratorService.swift      — Orchestrator: AI + Travelpayouts → AIGeneratedTrip

Views/AITripWizard/
  AITripWizardView.swift            — 4-step wizard container (TabView)
  WizardStepDestination.swift       — Step 1: where + "suggest me"
  WizardStepDates.swift             — Step 2: dates + season hint
  WizardStepBudget.swift            — Step 3: budget
  WizardStepStyle.swift             — Step 4: style + generate button
  AITripPreviewView.swift           — Preview with days/flights/hotels
  AITripLoadingView.swift           — Loading animation
```

## Modified Files

```
Views/Home/HomeView.swift           — Add "Создать с AI" button
Secrets.swift                       — Add travelpayoutsToken (Keychain)
Views/Settings/SettingsView.swift   — Travelpayouts API key field
```

## Travelpayouts API

### Flights (Prices API — cached, fast)
```
GET https://api.travelpayouts.com/aviasales/v3/prices_for_dates
  ?origin=MOW&destination=IST&departure_at=2026-03-12
  &token={API_KEY}&currency=rub&sorting=price
```

### Hotels (Hotellook API)
```
GET https://engine.hotellook.com/api/v2/cache.json
  ?location=Istanbul&checkIn=2026-03-12&checkOut=2026-03-15
  &currency=rub&limit=5
```

Both APIs free with partner key. Rate limit ~200 req/hour.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| AI fails | Toast + retry button, wizard input preserved |
| No flights found | Days/places shown, "Билеты не найдены" + Aviasales deep link fallback |
| No hotels found | "Отели не найдены" + Hotellook deep link fallback |
| No profile filled | AI still suggests based on season + cheap flights, hint to fill profile |
| Budget too low | Warning badge on total, AI adapts suggestions to budget |
| Offline | Wizard unavailable, show OfflineBanner + suggest manual creation |

## AI Prompt Strategy

- Personalization via AIPromptHelper.profileContext() (interests, diet, pace, visited countries)
- Budget-aware: AI adapts place density and category to budget level
- Season-aware: AI considers weather and tourist season
- Style-aware: maps selected styles to place categories
- Russian language output
- JSON structured output for reliable parsing

## Monetization

Travelpayouts affiliate commission:
- Flights: ~1.2-2.6% per booking
- Hotels: ~3-5% per booking
- Revenue stream independent of subscription
