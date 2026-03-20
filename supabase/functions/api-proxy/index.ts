import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const AIRLABS_KEY = Deno.env.get("AIRLABS_API_KEY");
const TRAVELPAYOUTS_TOKEN = Deno.env.get("TRAVELPAYOUTS_TOKEN");
const WEATHERAPI_KEY = Deno.env.get("WEATHERAPI_KEY");
const GOOGLE_PLACES_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY");
// Visa credentials kept for future use
// const VISA_API_KEY = Deno.env.get("VISA_API_KEY");
// const VISA_SHARED_SECRET = Deno.env.get("VISA_SHARED_SECRET");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const url = new URL(req.url);
  if (req.method === "GET" && url.pathname.endsWith("/photo")) {
    return await handlePhotoProxy(url);
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const { service, action, params } = await req.json();

    if (service === "gemini") return await handleGemini(params);
    if (service === "moex_rates") return await handleMoexRates(params);
    // Legacy route aliases
    if (service === "visa" || service === "visa_batch") return await handleMoexRates(params);
    if (service === "google_places") return await handleGooglePlaces(action, params);
    if (service === "google_directions") return await handleGoogleDirections(params);
    if (service === "google_routes") return await handleGoogleRoutes(params);
    if (service === "google_geocoding") return await handleGoogleGeocoding(params);
    if (service === "google_distance_matrix") return await handleGoogleDistanceMatrix(params);
    if (service === "overpass") return await handleOverpass(params);

    const builtUrl = buildUrl(service, action || "", params || {});
    const upstream = await fetch(builtUrl);
    const data = await upstream.text();

    return new Response(data, {
      status: upstream.status,
      headers: {
        ...corsHeaders,
        "Content-Type": upstream.headers.get("Content-Type") || "application/json",
      },
    });
  } catch (error) {
    return jsonResponse({ error: `Proxy error: ${(error as Error).message}` }, 500);
  }
});

function jsonResponse(body: object, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// MARK: - Gemini AI API

async function handleGemini(params: Record<string, string>) {
  if (!GOOGLE_PLACES_KEY) return jsonResponse({ error: "GOOGLE_PLACES_API_KEY not configured" }, 500);

  const prompt = params.prompt;
  if (!prompt) return jsonResponse({ error: "prompt parameter required" }, 400);

  const model = params.model || "gemini-2.5-flash";
  const temperature = parseFloat(params.temperature || "0.7");
  const maxOutputTokens = parseInt(params.maxOutputTokens || "8192", 10);

  const body = {
    contents: [{ parts: [{ text: prompt }] }],
    generationConfig: { temperature, maxOutputTokens },
  };

  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GOOGLE_PLACES_KEY}`;

  const resp = await fetch(geminiUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  const data = await resp.text();
  return new Response(data, {
    status: resp.status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// MARK: - Overpass API (OpenStreetMap)

async function handleOverpass(params: Record<string, string>) {
  const action = params.action || "nearby_stations";

  if (action === "nearby_stations") {
    const lat = params.lat;
    const lng = params.lng;
    const radius = params.radius || "1500";

    if (!lat || !lng) {
      return jsonResponse({ error: "lat and lng required" }, 400);
    }

    const query = `[out:json][timeout:15];(node["railway"="station"](around:${radius},${lat},${lng});node["railway"="halt"](around:${radius},${lat},${lng});node["station"="subway"](around:${radius},${lat},${lng}););out body;`;

    const resp = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `data=${encodeURIComponent(query)}`,
    });

    const contentType = resp.headers.get("Content-Type") || "";
    if (!contentType.includes("json")) {
      const text = await resp.text();
      return jsonResponse({ error: "Overpass returned non-JSON", preview: text.substring(0, 300) }, 502);
    }

    const data = await resp.json();

    const stations = (data.elements || []).map((el: Record<string, unknown>) => {
      const tags = (el.tags || {}) as Record<string, string>;
      return {
        name: tags.name || tags["name:en"] || tags["name:ja"] || "Unknown",
        name_ja: tags["name:ja"] || tags.name || "",
        name_en: tags["name:en"] || "",
        lat: el.lat,
        lng: el.lon,
        operator: tags.operator || tags.network || "",
        railway: tags.railway || "",
        lines: tags.line || tags["railway:line"] || "",
        osm_id: el.id,
      };
    });

    return jsonResponse({ stations }, 200);
  }

  if (action === "railway_geometry") {
    const lineName = params.line_name;
    if (!lineName) {
      return jsonResponse({ error: "line_name required" }, 400);
    }

    const query = `[out:json][timeout:20];(way["railway"="rail"]["name"~"${lineName}"](35.0,139.0,36.0,140.5);way["railway"="subway"]["name"~"${lineName}"](35.0,139.0,36.0,140.5););out geom;`;

    const resp = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `data=${encodeURIComponent(query)}`,
    });

    const contentType = resp.headers.get("Content-Type") || "";
    if (!contentType.includes("json")) {
      const text = await resp.text();
      return jsonResponse({ error: "Overpass returned non-JSON", preview: text.substring(0, 300) }, 502);
    }

    const data = await resp.json();

    const segments = (data.elements || []).map((el: Record<string, unknown>) => {
      const tags = (el.tags || {}) as Record<string, string>;
      const geometry = (el.geometry || []) as Array<{ lat: number; lon: number }>;
      return {
        name: tags.name || "",
        operator: tags.operator || "",
        coordinates: geometry.map((g) => ({ lat: g.lat, lng: g.lon })),
      };
    });

    return jsonResponse({ segments }, 200);
  }

  return jsonResponse({ error: `Unknown overpass action: ${action}` }, 400);
}

// MARK: - Google Routes API v2

async function handleGoogleRoutes(params: Record<string, string>) {
  if (!GOOGLE_PLACES_KEY) return jsonResponse({ error: "GOOGLE_PLACES_API_KEY not configured" }, 500);

  const originLat = parseFloat(params.origin_lat);
  const originLng = parseFloat(params.origin_lng);
  const destLat = parseFloat(params.dest_lat);
  const destLng = parseFloat(params.dest_lng);

  if (isNaN(originLat) || isNaN(originLng) || isNaN(destLat) || isNaN(destLng)) {
    return jsonResponse({ error: "origin_lat, origin_lng, dest_lat, dest_lng required" }, 400);
  }

  const travelMode = (params.mode || "DRIVE").toUpperCase();
  const language = params.language || "ru";

  const body: Record<string, unknown> = {
    origin: { location: { latLng: { latitude: originLat, longitude: originLng } } },
    destination: { location: { latLng: { latitude: destLat, longitude: destLng } } },
    travelMode,
    languageCode: language,
    regionCode: params.region || "",
    computeAlternativeRoutes: true,
    polylineEncoding: "ENCODED_POLYLINE",
  };

  if (travelMode === "DRIVE") {
    body.routingPreference = "TRAFFIC_AWARE";
    body.routeModifiers = {
      avoidTolls: params.avoid_tolls === "true",
      avoidHighways: params.avoid_highways === "true",
      avoidFerries: params.avoid_ferries === "true",
    };
  }

  if (travelMode === "TRANSIT") {
    body.transitPreferences = { routingPreference: "LESS_WALKING" };
    body.departureTime = params.departure_time || new Date().toISOString();
  }

  const fieldMask = [
    "routes.duration","routes.distanceMeters","routes.polyline.encodedPolyline",
    "routes.legs.duration","routes.legs.distanceMeters","routes.legs.polyline.encodedPolyline",
    "routes.legs.steps.navigationInstruction","routes.legs.steps.localizedValues",
    "routes.legs.steps.distanceMeters","routes.legs.steps.staticDuration",
    "routes.legs.steps.polyline.encodedPolyline","routes.legs.steps.travelMode",
    "routes.legs.steps.transitDetails","routes.travelAdvisory",
    "routes.legs.startLocation","routes.legs.endLocation",
    "routes.staticDuration",
  ].join(",");

  const resp = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": GOOGLE_PLACES_KEY,
      "X-Goog-FieldMask": fieldMask,
    },
    body: JSON.stringify(body),
  });

  const data = await resp.text();
  return new Response(data, { status: resp.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

// MARK: - Google Geocoding API

async function handleGoogleGeocoding(params: Record<string, string>) {
  if (!GOOGLE_PLACES_KEY) return jsonResponse({ error: "GOOGLE_PLACES_API_KEY not configured" }, 500);
  const latlng = params.latlng;
  if (!latlng) return jsonResponse({ error: "latlng parameter required" }, 400);

  const qs = new URLSearchParams({ latlng, language: params.language || "ru", result_type: params.result_type || "street_address|route|locality", key: GOOGLE_PLACES_KEY });
  const resp = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?${qs}`);
  const data = await resp.text();
  return new Response(data, { status: resp.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

// MARK: - Google Distance Matrix API

async function handleGoogleDistanceMatrix(params: Record<string, string>) {
  if (!GOOGLE_PLACES_KEY) return jsonResponse({ error: "GOOGLE_PLACES_API_KEY not configured" }, 500);
  if (!params.origins || !params.destinations) return jsonResponse({ error: "origins and destinations required" }, 400);

  const qs = new URLSearchParams({
    origins: params.origins, destinations: params.destinations,
    language: params.language || "ru", mode: params.mode || "driving",
    departure_time: params.departure_time || "now", key: GOOGLE_PLACES_KEY,
  });

  const resp = await fetch(`https://maps.googleapis.com/maps/api/distancematrix/json?${qs}`);
  const data = await resp.text();
  return new Response(data, { status: resp.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

// MARK: - Google Directions API (Legacy)

async function handleGoogleDirections(params: Record<string, string>) {
  if (!GOOGLE_PLACES_KEY) return jsonResponse({ error: "GOOGLE_PLACES_API_KEY not configured" }, 500);
  if (!params.origin || !params.destination) return jsonResponse({ error: "origin and destination required" }, 400);

  const qs = new URLSearchParams({
    origin: params.origin, destination: params.destination,
    mode: params.mode || "transit", language: params.language || "ru",
    key: GOOGLE_PLACES_KEY, departure_time: params.departure_time || "now", alternatives: "false",
  });

  const resp = await fetch(`https://maps.googleapis.com/maps/api/directions/json?${qs}`);
  const data = await resp.text();
  return new Response(data, { status: resp.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

// MARK: - Google Places Photo Proxy (GET)

async function handlePhotoProxy(url: URL) {
  if (!GOOGLE_PLACES_KEY) return jsonResponse({ error: "GOOGLE_PLACES_API_KEY not configured" }, 500);
  const photoName = url.searchParams.get("name");
  if (!photoName) return jsonResponse({ error: "name parameter required" }, 400);

  const photoUrl = `https://places.googleapis.com/v1/${photoName}/media?maxWidthPx=${url.searchParams.get("maxWidthPx") || "400"}&key=${GOOGLE_PLACES_KEY}`;
  const resp = await fetch(photoUrl, { redirect: "follow" });
  if (!resp.ok) return jsonResponse({ error: `Photo fetch failed: ${resp.status}` }, resp.status);

  const imageData = await resp.arrayBuffer();
  return new Response(imageData, {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": resp.headers.get("Content-Type") || "image/jpeg", "Cache-Control": "public, max-age=86400" },
  });
}

// MARK: - Google Places API (New)

async function handleGooglePlaces(action: string, params: Record<string, string>) {
  if (!GOOGLE_PLACES_KEY) return jsonResponse({ error: "GOOGLE_PLACES_API_KEY not configured" }, 500);

  if (action === "search_text") {
    const fieldMask = ["places.id","places.displayName","places.rating","places.userRatingCount","places.currentOpeningHours","places.regularOpeningHours","places.reviews","places.priceLevel","places.websiteUri","places.internationalPhoneNumber","places.formattedAddress","places.googleMapsUri","places.photos"].join(",");
    const body: Record<string, unknown> = { textQuery: params.query || "", languageCode: params.language || "ru", maxResultCount: 1 };
    if (params.latitude && params.longitude) {
      body.locationBias = { circle: { center: { latitude: parseFloat(params.latitude), longitude: parseFloat(params.longitude) }, radius: 500.0 } };
    }
    const resp = await fetch("https://places.googleapis.com/v1/places:searchText", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Goog-Api-Key": GOOGLE_PLACES_KEY, "X-Goog-FieldMask": fieldMask },
      body: JSON.stringify(body),
    });
    const data = await resp.text();
    return new Response(data, { status: resp.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  if (action === "details") {
    if (!params.place_id) return jsonResponse({ error: "place_id required" }, 400);
    const fieldMask = ["id","displayName","rating","userRatingCount","currentOpeningHours","regularOpeningHours","reviews","priceLevel","websiteUri","internationalPhoneNumber","formattedAddress","googleMapsUri","photos"].join(",");
    const resp = await fetch(`https://places.googleapis.com/v1/places/${params.place_id}`, {
      headers: { "X-Goog-Api-Key": GOOGLE_PLACES_KEY, "X-Goog-FieldMask": fieldMask },
    });
    const data = await resp.text();
    return new Response(data, { status: resp.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  return jsonResponse({ error: `Unknown google_places action: ${action}` }, 400);
}

// MARK: - НКО НКЦ (MOEX) Exchange Rates

// НКО НКЦ (MOEX) exchange rates — free, no API key needed
// Uses MOEX ISS API, CETS board (main market)
// SECID mapping: USD000UTSTOM, EUR_RUB__TOM, CNYRUB_TOM, JPYRUB_TOM
async function handleMoexRates(params: Record<string, string>) {
  const base = params.base || "RUB";
  const targets = (params.targets || "USD,EUR,JPY,CNY").split(",").map(s => s.trim()).filter(Boolean);

  const secidMap: Record<string, string> = {
    USD: "USD000UTSTOM",
    EUR: "EUR_RUB__TOM",
    CNY: "CNYRUB_TOM",
    JPY: "JPYRUB_TOM",
  };

  try {
    const url = "https://iss.moex.com/iss/engines/currency/markets/selt/securities.json" +
      "?iss.meta=off&iss.only=securities,marketdata" +
      "&securities.columns=SECID,BOARDID,FACEVALUE,PREVPRICE" +
      "&marketdata.columns=SECID,BOARDID,LAST";

    const resp = await fetch(url);
    if (!resp.ok) {
      return jsonResponse({ error: `MOEX API ${resp.status}` }, resp.status);
    }

    const data = await resp.json();

    // Build price map from securities (PREVPRICE) and marketdata (LAST)
    // Prefer LAST (live) over PREVPRICE (previous close), CETS board only
    const prevPrices: Record<string, { price: number; faceValue: number }> = {};
    const livePrices: Record<string, number> = {};

    // Parse securities for PREVPRICE + FACEVALUE
    const secRows = data?.securities?.data || [];
    for (const row of secRows) {
      const [secid, boardid, faceValue, prevPrice] = row;
      if (boardid === "CETS" && prevPrice != null && prevPrice > 0) {
        prevPrices[secid] = { price: prevPrice, faceValue: faceValue || 1 };
      }
    }

    // Parse marketdata for LAST (live price during trading hours)
    const mdRows = data?.marketdata?.data || [];
    for (const row of mdRows) {
      const [secid, boardid, last] = row;
      if (boardid === "CETS" && last != null && last > 0) {
        livePrices[secid] = last;
      }
    }

    // Build RUB rates: 1 unit of currency = X RUB
    const rubRates: Record<string, number> = {};
    for (const [currency, secid] of Object.entries(secidMap)) {
      const prev = prevPrices[secid];
      if (!prev) continue;
      const faceValue = prev.faceValue; // JPY = 100, others = 1
      const price = livePrices[secid] || prev.price;
      rubRates[currency] = price / faceValue; // 1 unit = X RUB
    }

    const rates: Record<string, number> = {};

    if (base === "RUB") {
      for (const t of targets) {
        if (t === "RUB") continue;
        if (rubRates[t]) rates[t] = rubRates[t];
      }
    } else {
      const baseToRub = rubRates[base];
      if (!baseToRub) {
        return jsonResponse({ error: `Base currency ${base} not found on MOEX` }, 400);
      }
      for (const t of targets) {
        if (t === base) continue;
        if (t === "RUB") {
          rates["RUB"] = baseToRub;
        } else if (rubRates[t]) {
          rates[t] = rubRates[t] / baseToRub;
        }
      }
    }

    return jsonResponse({
      base,
      rates,
      source: "moex_ncc",
    }, 200);
  } catch (error) {
    return jsonResponse({ error: `MOEX fetch failed: ${(error as Error).message}` }, 500);
  }
}

function buildUrl(service: string, action: string, params: Record<string, string>): string {
  switch (service) {
    case "airlabs": {
      if (!AIRLABS_KEY) throw new Error("AIRLABS_API_KEY not configured");
      return `https://airlabs.co/api/v9/${action}?${new URLSearchParams({ api_key: AIRLABS_KEY, ...params })}`;
    }
    case "travelpayouts": {
      if (!TRAVELPAYOUTS_TOKEN) throw new Error("TRAVELPAYOUTS_TOKEN not configured");
      const tp = new URLSearchParams({ token: TRAVELPAYOUTS_TOKEN, ...params });
      if (action === "flights") return `https://api.travelpayouts.com/aviasales/v3/prices_for_dates?${tp}`;
      if (action === "hotels") return `https://engine.hotellook.com/api/v2/cache.json?${tp}`;
      if (action === "cheap") return `https://api.travelpayouts.com/aviasales/v3/get_latest_prices?${tp}`;
      throw new Error(`Unknown travelpayouts action: ${action}`);
    }
    case "weather": {
      if (!WEATHERAPI_KEY) throw new Error("WEATHERAPI_KEY not configured");
      return `https://api.weatherapi.com/v1/forecast.json?${new URLSearchParams({ key: WEATHERAPI_KEY, ...params })}`;
    }
    case "currency":
      return `https://open.er-api.com/v6/latest/${params.base || "RUB"}`;
    case "wikipedia": {
      const lang = params.language || "en";
      if (action === "search") return `https://${lang}.wikipedia.org/w/api.php?${new URLSearchParams({ action: "query", list: "search", srsearch: params.query || "", srlimit: "1", format: "json" })}`;
      if (action === "summary") return `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(params.title || "")}`;
      throw new Error(`Unknown wikipedia action: ${action}`);
    }
    case "countries":
      return `https://restcountries.com/v3.1/name/${encodeURIComponent(params.name || "")}?fields=name,flag,currencies,languages,capital,region`;
    default:
      throw new Error(`Unknown service: ${service}`);
  }
}
