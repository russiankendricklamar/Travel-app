import Foundation
import CoreLocation

/// AI-powered transit routing for Japan using OpenStreetMap + Gemini.
/// Used as fallback when Google Directions API doesn't support transit in the region.
@MainActor
final class JapanTransitService {
    static let shared = JapanTransitService()
    private init() {}

    /// Cache Overpass results to avoid re-fetching on repeated route requests
    private var stationCache: [String: [NearbyStation]] = [:]

    private func stationCacheKey(_ coord: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coord.latitude, coord.longitude)
    }

    /// Known Tokyo Metro line colors
    private static let lineColors: [String: String] = [
        "銀座線": "#FF9500", "Ginza": "#FF9500",
        "丸ノ内線": "#F62E36", "Marunouchi": "#F62E36",
        "日比谷線": "#B5B5AC", "Hibiya": "#B5B5AC",
        "東西線": "#009BBF", "Tozai": "#009BBF",
        "千代田線": "#00BB85", "Chiyoda": "#00BB85",
        "有楽町線": "#C1A470", "Yurakucho": "#C1A470",
        "半蔵門線": "#8F76D6", "Hanzomon": "#8F76D6",
        "南北線": "#00AC9B", "Namboku": "#00AC9B",
        "副都心線": "#9C5E31", "Fukutoshin": "#9C5E31",
        // Toei
        "浅草線": "#E85298", "Asakusa": "#E85298",
        "三田線": "#0079C2", "Mita": "#0079C2",
        "新宿線": "#6CBB5A", "Shinjuku": "#6CBB5A",
        "大江戸線": "#B6007A", "Oedo": "#B6007A",
        // JR
        "山手線": "#9ACD32", "Yamanote": "#9ACD32",
        "中央線": "#FF4500", "Chuo": "#FF4500",
        "総武線": "#FFD700", "Sobu": "#FFD700",
        "京浜東北線": "#00BFFF", "Keihin-Tohoku": "#00BFFF",
        "埼京線": "#008000", "Saikyo": "#008000",
        "湘南新宿ライン": "#E86B00", "Shonan-Shinjuku": "#E86B00",
    ]

    // MARK: - Public

    func planTransitRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> RouteResult? {
        print("[JapanTransit] ═══════════════════════════════════════")
        print("[JapanTransit] 🚃 Starting AI transit route planning")
        print("[JapanTransit] Origin: \(origin.latitude), \(origin.longitude)")
        print("[JapanTransit] Destination: \(destination.latitude), \(destination.longitude)")

        // Step 1: Find nearby stations
        print("[JapanTransit] ── Step 1: Fetching nearby stations via Overpass API...")
        async let originStations = fetchNearbyStations(coordinate: origin, label: "origin")
        async let destStations = fetchNearbyStations(coordinate: destination, label: "destination")

        let (originList, destList) = await (originStations, destStations)

        print("[JapanTransit] Origin stations found: \(originList.count)")
        for s in originList {
            print("[JapanTransit]   📍 \(s.name) (\(s.nameJa)) [\(s.operator_)] — \(String(format: "%.4f", s.lat)),\(String(format: "%.4f", s.lng))")
        }
        print("[JapanTransit] Destination stations found: \(destList.count)")
        for s in destList {
            print("[JapanTransit]   📍 \(s.name) (\(s.nameJa)) [\(s.operator_)] — \(String(format: "%.4f", s.lat)),\(String(format: "%.4f", s.lng))")
        }

        guard !originList.isEmpty, !destList.isEmpty else {
            print("[JapanTransit] ❌ No stations found near origin (\(originList.count)) or destination (\(destList.count))")
            return nil
        }

        // Step 2: Ask Gemini to plan the route
        print("[JapanTransit] ── Step 2: Sending prompt to Gemini AI...")
        let prompt = buildPrompt(
            origin: origin,
            destination: destination,
            originStations: originList,
            destStations: destList
        )
        print("[JapanTransit] Prompt length: \(prompt.count) chars")

        guard let aiResponse = await GeminiService.shared.rawRequest(prompt: prompt) else {
            print("[JapanTransit] ❌ Gemini returned nil. Error: \(GeminiService.shared.lastError ?? "unknown")")
            return nil
        }

        print("[JapanTransit] ── Step 3: Parsing AI response...")
        print("[JapanTransit] AI response length: \(aiResponse.count) chars")
        print("[JapanTransit] AI response preview: \(String(aiResponse.prefix(500)))")

        // Step 3: Parse AI response into RouteResult
        let result = parseAIResponse(aiResponse)

        if let result {
            print("[JapanTransit] ✅ Route planned successfully!")
            print("[JapanTransit]   Duration: \(RoutingService.formatDuration(result.expectedTravelTime))")
            print("[JapanTransit]   Distance: \(RoutingService.formatDistance(result.distance))")
            print("[JapanTransit]   Steps: \(result.transitSteps.count)")
            for (i, step) in result.transitSteps.enumerated() {
                let icon = step.travelMode == "TRANSIT" ? "🚇" : "🚶"
                print("[JapanTransit]   \(icon) Step \(i+1): \(step.travelMode) — \(step.instruction.prefix(60))")
                if let line = step.transitLineName {
                    print("[JapanTransit]       Line: \(line), Color: \(step.transitLineColor ?? "nil"), Vehicle: \(step.vehicleType ?? "nil")")
                }
            }
            print("[JapanTransit]   Polyline points: \(result.polyline.count)")
        } else {
            print("[JapanTransit] ❌ Failed to parse AI response into RouteResult")
        }
        print("[JapanTransit] ═══════════════════════════════════════")

        return result
    }

    // MARK: - Overpass API — Nearby Stations

    private struct NearbyStation {
        let name: String
        let nameJa: String
        let lat: Double
        let lng: Double
        let operator_: String
        let lines: String
    }

    /// Progressive radius search: tries 1500m → 5000m → 15000m until stations are found.
    /// Results are cached by coordinate to avoid hammering Overpass on repeated requests.
    private func fetchNearbyStations(coordinate: CLLocationCoordinate2D, label: String = "") async -> [NearbyStation] {
        let cacheKey = stationCacheKey(coordinate)
        if let cached = stationCache[cacheKey] {
            print("[JapanTransit] [\(label)] Station cache hit: \(cached.count) stations")
            return cached
        }

        let radii = ["1500", "5000", "15000"]

        for radius in radii {
            let stations = await fetchStationsAtRadius(coordinate: coordinate, radius: radius, label: label)
            if !stations.isEmpty {
                stationCache[cacheKey] = stations
                return stations
            }
            if radius != radii.last {
                print("[JapanTransit] [\(label)] No stations at \(radius)m, expanding radius...")
            }
        }

        print("[JapanTransit] ❌ [\(label)] No stations found at any radius")
        return []
    }

    private func fetchStationsAtRadius(coordinate: CLLocationCoordinate2D, radius: String, label: String) async -> [NearbyStation] {
        // Retry up to 3 times for Overpass 502 errors (Overpass is often overloaded)
        for attempt in 1...3 {
            do {
                print("[JapanTransit] Overpass request [\(label)]: lat=\(coordinate.latitude), lng=\(coordinate.longitude), radius=\(radius)m (attempt \(attempt))")
                let data = try await SupabaseProxy.request(
                    service: "overpass",
                    params: [
                        "action": "nearby_stations",
                        "lat": String(coordinate.latitude),
                        "lng": String(coordinate.longitude),
                        "radius": radius,
                    ]
                )

                let preview = String(data: data.prefix(300), encoding: .utf8) ?? ""
                print("[JapanTransit] Overpass response [\(label)]: \(data.count) bytes — \(preview.prefix(200))")

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let stations = json["stations"] as? [[String: Any]] else {
                    print("[JapanTransit] ❌ Overpass [\(label)]: failed to parse stations from JSON")
                    return []
                }
                print("[JapanTransit] Overpass [\(label)]: \(stations.count) raw stations found at \(radius)m")

                return stations.compactMap { s in
                    guard let name = s["name"] as? String,
                          let lat = s["lat"] as? Double,
                          let lng = s["lng"] as? Double else { return nil }

                    return NearbyStation(
                        name: name,
                        nameJa: s["name_ja"] as? String ?? name,
                        lat: lat,
                        lng: lng,
                        operator_: s["operator"] as? String ?? "",
                        lines: s["lines"] as? String ?? ""
                    )
                }
                .sorted { s1, s2 in
                    let d1 = distance(from: coordinate, to: CLLocationCoordinate2D(latitude: s1.lat, longitude: s1.lng))
                    let d2 = distance(from: coordinate, to: CLLocationCoordinate2D(latitude: s2.lat, longitude: s2.lng))
                    return d1 < d2
                }
                .prefix(8)
                .map { $0 }
            } catch {
                print("[JapanTransit] Overpass error [\(label)] (attempt \(attempt)/3): \(error)")
                if attempt < 3 {
                    let delay = attempt * 3  // 3s, 6s
                    print("[JapanTransit] Retrying in \(delay)s...")
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
        }
        return []
    }

    private func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let loc2 = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return loc1.distance(from: loc2)
    }

    // MARK: - Gemini Prompt

    private func buildPrompt(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        originStations: [NearbyStation],
        destStations: [NearbyStation]
    ) -> String {
        let originStationsStr = originStations.map { s in
            let dist = Int(distance(from: origin, to: CLLocationCoordinate2D(latitude: s.lat, longitude: s.lng)))
            return "  - \(s.name) (\(s.nameJa)) [\(s.operator_)] lat=\(s.lat), lng=\(s.lng) (~\(dist)м)"
        }.joined(separator: "\n")

        let destStationsStr = destStations.map { s in
            let dist = Int(distance(from: destination, to: CLLocationCoordinate2D(latitude: s.lat, longitude: s.lng)))
            return "  - \(s.name) (\(s.nameJa)) [\(s.operator_)] lat=\(s.lat), lng=\(s.lng) (~\(dist)м)"
        }.joined(separator: "\n")

        return """
        Ты — эксперт по общественному транспорту Японии. Спланируй оптимальный маршрут.

        ОТКУДА: \(origin.latitude), \(origin.longitude)
        Ближайшие станции:
        \(originStationsStr)

        КУДА: \(destination.latitude), \(destination.longitude)
        Ближайшие станции:
        \(destStationsStr)

        Ответь ТОЛЬКО JSON (без markdown, без ```):
        {
          "steps": [
            {
              "type": "walk",
              "instruction": "Идите до станции ...",
              "duration_minutes": 5,
              "distance_meters": 400,
              "from": {"name": "Текущее местоположение", "lat": 0.0, "lng": 0.0},
              "to": {"name": "Станция", "lat": 0.0, "lng": 0.0}
            },
            {
              "type": "transit",
              "instruction": "Линия ... до станции ...",
              "duration_minutes": 10,
              "distance_meters": 5000,
              "line_name": "丸ノ内線",
              "line_name_short": "M",
              "line_color": "#F62E36",
              "vehicle_type": "SUBWAY",
              "num_stops": 3,
              "from": {"name": "Станция отправления", "lat": 0.0, "lng": 0.0},
              "to": {"name": "Станция прибытия", "lat": 0.0, "lng": 0.0}
            }
          ],
          "total_duration_minutes": 25,
          "total_distance_meters": 8500
        }

        ПРАВИЛА:
        - Используй реальные координаты станций (lat/lng) из списка выше или свои знания
        - line_color: реальный цвет линии в HEX (#RRGGBB)
        - vehicle_type: SUBWAY, RAIL, BUS, TRAM или WALKING
        - line_name: название на японском, line_name_short: буква/номер линии
        - Инструкции на русском языке
        - Выбирай кратчайший маршрут с минимумом пересадок
        - Учитывай реальное время в пути между станциями
        - Если станция далеко (>1000м), добавь walk-шаг с корректным временем (80м/мин)
        - Для междугородних маршрутов используй Shinkansen/JR линии
        """
    }

    // MARK: - Parse AI Response

    private func parseAIResponse(_ text: String) -> RouteResult? {
        // Clean up markdown code blocks if present
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to find JSON object
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let steps = json["steps"] as? [[String: Any]] else {
            print("[JapanTransit] Failed to parse AI response: \(text.prefix(500))")
            return nil
        }

        let totalDuration = (json["total_duration_minutes"] as? Double ?? 0) * 60
        let totalDistance = json["total_distance_meters"] as? Double ?? 0

        var transitSteps: [TransitStep] = []
        var polylineCoords: [CLLocationCoordinate2D] = []

        for step in steps {
            let type = step["type"] as? String ?? "walk"
            let instruction = step["instruction"] as? String ?? ""
            let durationMin = step["duration_minutes"] as? Double ?? 0
            let distanceM = step["distance_meters"] as? Double ?? 0

            let fromDict = step["from"] as? [String: Any]
            let toDict = step["to"] as? [String: Any]

            let fromLat = fromDict?["lat"] as? Double ?? 0
            let fromLng = fromDict?["lng"] as? Double ?? 0
            let toLat = toDict?["lat"] as? Double ?? 0
            let toLng = toDict?["lng"] as? Double ?? 0
            let departureStop = fromDict?["name"] as? String
            let arrivalStop = toDict?["name"] as? String

            // Build step polyline (straight line between stations)
            var stepPolyline: [CLLocationCoordinate2D] = []
            if fromLat != 0, fromLng != 0 {
                stepPolyline.append(CLLocationCoordinate2D(latitude: fromLat, longitude: fromLng))
            }
            if toLat != 0, toLng != 0 {
                stepPolyline.append(CLLocationCoordinate2D(latitude: toLat, longitude: toLng))
            }

            polylineCoords.append(contentsOf: stepPolyline)

            var lineName: String?
            var lineColor: String?
            var vehicleType: String?

            if type == "transit" {
                lineName = step["line_name_short"] as? String ?? step["line_name"] as? String
                lineColor = step["line_color"] as? String
                vehicleType = step["vehicle_type"] as? String ?? "SUBWAY"

                // Fallback to known colors if AI didn't provide
                if lineColor == nil, let name = step["line_name"] as? String {
                    lineColor = Self.lineColors[name]
                }
            }

            let travelMode = type == "transit" ? "TRANSIT" : "WALKING"

            let numStopsStr = (step["num_stops"] as? Int).map { " (\($0) ост.)" } ?? ""

            transitSteps.append(TransitStep(
                instruction: instruction + numStopsStr,
                distance: distanceM,
                duration: durationMin * 60,
                travelMode: travelMode,
                transitLineName: lineName,
                transitLineColor: lineColor,
                vehicleType: vehicleType,
                polyline: stepPolyline,
                departureStop: departureStop,
                arrivalStop: arrivalStop
            ))
        }

        return RouteResult(
            polyline: polylineCoords,
            distance: totalDistance,
            expectedTravelTime: totalDuration,
            mode: .transit,
            transitSteps: transitSteps
        )
    }
}
