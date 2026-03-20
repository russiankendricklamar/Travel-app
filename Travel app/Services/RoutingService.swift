import Foundation
import MapKit
import SwiftUI
import SwiftData

enum TransportMode: String, CaseIterable, Identifiable {
    case walking, automobile, transit, cycling

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .automobile: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "bus.fill"
        case .cycling: return "bicycle"
        }
    }

    var label: String {
        switch self {
        case .automobile: return "Авто"
        case .walking: return "Пешком"
        case .transit: return "ОТ"
        case .cycling: return "Вело"
        }
    }

    var color: Color {
        switch self {
        case .automobile: return AppTheme.oceanBlue
        case .walking: return AppTheme.bambooGreen
        case .transit: return AppTheme.templeGold
        case .cycling: return AppTheme.indigoPurple
        }
    }

    /// Routes API travel mode string
    var routesAPIMode: String {
        switch self {
        case .automobile: return "DRIVE"
        case .walking: return "WALK"
        case .transit: return "TRANSIT"
        case .cycling: return "BICYCLE"
        }
    }
}

struct RouteResult {
    let polyline: [CLLocationCoordinate2D]
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let mode: TransportMode
    let transitSteps: [TransitStep]
    let trafficDuration: TimeInterval?
    let originAddress: String?
    let navigationSteps: [NavigationStep]

    init(
        polyline: [CLLocationCoordinate2D],
        distance: CLLocationDistance,
        expectedTravelTime: TimeInterval,
        mode: TransportMode,
        transitSteps: [TransitStep] = [],
        trafficDuration: TimeInterval? = nil,
        originAddress: String? = nil,
        navigationSteps: [NavigationStep] = []
    ) {
        self.polyline = polyline
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.mode = mode
        self.transitSteps = transitSteps
        self.trafficDuration = trafficDuration
        self.originAddress = originAddress
        self.navigationSteps = navigationSteps
    }
}

/// Preview ETA for a transport mode (without full route polyline)
struct ModeETAPreview {
    let mode: TransportMode
    let duration: TimeInterval
    let distance: CLLocationDistance
}

struct TransitStep {
    let instruction: String
    let distance: CLLocationDistance
    let duration: TimeInterval
    let travelMode: String
    let transitLineName: String?
    let transitLineColor: String?
    let vehicleType: String?
    let polyline: [CLLocationCoordinate2D]
    let departureStop: String?
    let arrivalStop: String?

    init(
        instruction: String,
        distance: CLLocationDistance,
        duration: TimeInterval,
        travelMode: String,
        transitLineName: String? = nil,
        transitLineColor: String? = nil,
        vehicleType: String? = nil,
        polyline: [CLLocationCoordinate2D] = [],
        departureStop: String? = nil,
        arrivalStop: String? = nil
    ) {
        self.instruction = instruction
        self.distance = distance
        self.duration = duration
        self.travelMode = travelMode
        self.transitLineName = transitLineName
        self.transitLineColor = transitLineColor
        self.vehicleType = vehicleType
        self.polyline = polyline
        self.departureStop = departureStop
        self.arrivalStop = arrivalStop
    }
}

@Observable
final class RoutingService {
    static let shared = RoutingService()
    private init() {}

    private var cache: [String: RouteResult] = [:]
    /// Tracks in-flight route calculations to prevent duplicate parallel requests
    private var inFlightKeys: Set<String> = []

    var lastError: String?
    var transitUnavailableRegion = false

    /// ETA preview for all modes (loaded in parallel)
    var etaPreviews: [TransportMode: ModeETAPreview] = [:]

    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TransportMode
    ) async -> [RouteResult] {
        lastError = nil
        transitUnavailableRegion = false

        let cacheKey = "\(String(format: "%.5f,%.5f", origin.latitude, origin.longitude))_\(String(format: "%.5f,%.5f", destination.latitude, destination.longitude))_\(mode.rawValue)"
        if let cached = cache[cacheKey] { return [cached] }

        // Prevent duplicate in-flight requests for the same route
        guard !inFlightKeys.contains(cacheKey) else {
            print("[RoutingService] ⏳ Request already in-flight for \(mode.rawValue), skipping duplicate")
            return []
        }
        inFlightKeys.insert(cacheKey)
        defer { inFlightKeys.remove(cacheKey) }

        // Transit: use legacy Directions API (better Japan-like region detection)
        // Falls back to AI-powered routing for regions without Google transit data
        if mode == .transit {
            print("[RoutingService] 🚌 Transit route requested")
            print("[RoutingService] Trying Google Directions API first...")
            let googleResult = await calculateGoogleTransitRoute(from: origin, to: destination, cacheKey: cacheKey)
            if let googleResult {
                print("[RoutingService] ✅ Google Directions returned a transit route")
                return [googleResult]
            }
            print("[RoutingService] ❌ Google Directions failed. transitUnavailableRegion=\(transitUnavailableRegion), lastError=\(lastError ?? "nil")")

            // If transit unavailable in region → try AI-powered routing (ODPT + Gemini)
            if transitUnavailableRegion {
                print("[RoutingService] 🤖 Falling back to JapanTransitService (AI + Overpass)...")
                let aiResult = await JapanTransitService.shared.planTransitRoute(from: origin, to: destination)
                if let aiResult {
                    print("[RoutingService] ✅ AI transit route found! Duration=\(Self.formatDuration(aiResult.expectedTravelTime)), Steps=\(aiResult.transitSteps.count)")
                    transitUnavailableRegion = false
                    lastError = nil
                    cache[cacheKey] = aiResult
                    return [aiResult]
                }
                print("[RoutingService] ❌ AI transit route also failed")
            }

            return []
        }

        // Drive / Walk / Bicycle: use Routes API v2 (traffic-aware, real cycling)
        return await calculateRoutesAPIRoute(from: origin, to: destination, mode: mode, cacheKey: cacheKey)
    }

    // MARK: - Place-UUID Overload (Offline Cache Support)

    /// Place-UUID based route calculation with offline cache support.
    /// Online: fetches from API and stores result in cache.
    /// Offline: returns cached route if available, empty array otherwise.
    func calculateRoute(
        fromPlace origin: Place,
        toPlace destination: Place,
        mode: TransportMode,
        tripID: UUID,
        context: ModelContext
    ) async -> [RouteResult] {
        // Online: always use API (cache is for offline only)
        if await OfflineCacheManager.shared.isOnline {
            let results = await calculateRoute(
                from: origin.coordinate,
                to: destination.coordinate,
                mode: mode
            )
            // Store first result for future offline use
            if let first = results.first {
                await RoutingCacheService.shared.store(
                    first, origin: origin.id, dest: destination.id,
                    tripID: tripID, context: context
                )
            }
            return results
        }

        // Offline: L1+L2 cache lookup
        if let cached = await RoutingCacheService.shared.lookup(
            origin: origin.id, dest: destination.id,
            mode: mode, context: context
        ) {
            return [cached]
        }

        // Offline + no cache
        lastError = "Маршрут недоступен офлайн. Подготовьте маршруты заранее при наличии сети."
        return []
    }

    // MARK: - Routes API v2 (Drive / Walk / Bicycle)

    private func calculateRoutesAPIRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TransportMode,
        cacheKey: String
    ) async -> [RouteResult] {
        print("[RoutingService] 🗺️ Routes API request: mode=\(mode.routesAPIMode), origin=\(String(format: "%.5f,%.5f", origin.latitude, origin.longitude)), dest=\(String(format: "%.5f,%.5f", destination.latitude, destination.longitude))")
        do {
            let data = try await SupabaseProxy.request(
                service: "google_routes",
                params: [
                    "origin_lat": String(origin.latitude),
                    "origin_lng": String(origin.longitude),
                    "dest_lat": String(destination.latitude),
                    "dest_lng": String(destination.longitude),
                    "mode": mode.routesAPIMode,
                    "language": "ru",
                ]
            )

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let routes = json["routes"] as? [[String: Any]],
                  !routes.isEmpty else {
                let preview = String(data: data.prefix(500), encoding: .utf8) ?? ""
                print("[RoutingService] Routes API empty for \(mode.rawValue): \(preview)")
                lastError = "Маршрут не найден"
                return []
            }

            let results = Array(routes.prefix(3).map { parseRoutesAPIResponse($0, mode: mode) })
            print("[RoutingService] ✅ Routes API success: mode=\(mode.rawValue), \(results.count) routes, first: duration=\(Self.formatDuration(results[0].expectedTravelTime)), distance=\(Self.formatDistance(results[0].distance)), polyline=\(results[0].polyline.count) pts")
            cache[cacheKey] = results[0]  // cache fastest only
            return results
        } catch {
            print("[RoutingService] ❌ Routes API error for \(mode.rawValue): \(error)")
            lastError = "Ошибка маршрута: \(error.localizedDescription)"
            return []
        }
    }

    private func parseRoutesAPIResponse(_ route: [String: Any], mode: TransportMode) -> RouteResult {
        // Overall polyline
        let encodedPolyline = (route["polyline"] as? [String: Any])?["encodedPolyline"] as? String ?? ""
        let polylineCoords = Self.decodeGooglePolyline(encodedPolyline)

        // Duration: "3600s" format
        let durationStr = route["duration"] as? String ?? "0s"
        let duration = Self.parseGoogleDuration(durationStr)

        // Distance in meters
        let distanceMeters = route["distanceMeters"] as? Double
            ?? (route["distanceMeters"] as? Int).map { Double($0) }
            ?? 0

        // Traffic-aware duration for driving
        var trafficDuration: TimeInterval?
        if mode == .automobile {
            if let staticDur = route["staticDuration"] as? String {
                let staticSeconds = Self.parseGoogleDuration(staticDur)
                if abs(staticSeconds - duration) > 60 {
                    trafficDuration = duration
                }
            }
        }

        return RouteResult(
            polyline: polylineCoords,
            distance: distanceMeters,
            expectedTravelTime: duration,
            mode: mode,
            trafficDuration: trafficDuration
        )
    }

    /// Parse duration string like "3600s" → TimeInterval
    static func parseGoogleDuration(_ str: String) -> TimeInterval {
        let cleaned = str.replacingOccurrences(of: "s", with: "")
        return TimeInterval(cleaned) ?? 0
    }

    // MARK: - Google Directions (Transit)

    private func calculateGoogleTransitRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        cacheKey: String
    ) async -> RouteResult? {
        do {
            let originStr = "\(origin.latitude),\(origin.longitude)"
            let destStr = "\(destination.latitude),\(destination.longitude)"

            let data = try await SupabaseProxy.request(
                service: "google_directions",
                params: [
                    "origin": originStr,
                    "destination": destStr,
                    "mode": "transit",
                    "language": "ru",
                ]
            )

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else {
                lastError = "Неверный ответ Google Directions"
                return nil
            }

            guard status == "OK",
                  let routes = json["routes"] as? [[String: Any]],
                  let route = routes.first else {
                if status == "ZERO_RESULTS" {
                    if let available = json["available_travel_modes"] as? [String],
                       !available.contains("TRANSIT") {
                        transitUnavailableRegion = true
                        lastError = "Транзит недоступен в этом регионе"
                    } else {
                        lastError = "Маршрут ОТ не найден"
                    }
                } else {
                    lastError = "Google Directions: \(status)"
                }
                return nil
            }

            let result = parseGoogleDirectionsRoute(route)
            cache[cacheKey] = result
            return result
        } catch {
            print("[RoutingService] Google Directions error: \(error)")
            lastError = "Ошибка маршрута ОТ: \(error.localizedDescription)"
            return nil
        }
    }

    private func parseGoogleDirectionsRoute(_ route: [String: Any]) -> RouteResult {
        let overviewPolyline = (route["overview_polyline"] as? [String: Any])?["points"] as? String ?? ""
        let polylineCoords = Self.decodeGooglePolyline(overviewPolyline)

        let legs = route["legs"] as? [[String: Any]] ?? []
        var totalDistance: Double = 0
        var totalDuration: Double = 0
        var transitSteps: [TransitStep] = []

        for leg in legs {
            totalDistance += (leg["distance"] as? [String: Any])?["value"] as? Double ?? 0
            totalDuration += (leg["duration"] as? [String: Any])?["value"] as? Double ?? 0

            let steps = leg["steps"] as? [[String: Any]] ?? []
            for step in steps {
                let instruction = (step["html_instructions"] as? String ?? "")
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                let stepDistance = (step["distance"] as? [String: Any])?["value"] as? Double ?? 0
                let stepDuration = (step["duration"] as? [String: Any])?["value"] as? Double ?? 0
                let travelMode = step["travel_mode"] as? String ?? "WALKING"

                let stepPolyline = (step["polyline"] as? [String: Any])?["points"] as? String ?? ""
                let stepCoords = Self.decodeGooglePolyline(stepPolyline)

                var lineName: String?
                var lineColor: String?
                var vehicleType: String?
                var departureStop: String?
                var arrivalStop: String?

                if let transitDetails = step["transit_details"] as? [String: Any] {
                    if let line = transitDetails["line"] as? [String: Any] {
                        lineName = line["short_name"] as? String ?? line["name"] as? String
                        lineColor = line["color"] as? String
                        if let vehicle = line["vehicle"] as? [String: Any] {
                            vehicleType = vehicle["type"] as? String
                        }
                    }
                    departureStop = (transitDetails["departure_stop"] as? [String: Any])?["name"] as? String
                    arrivalStop = (transitDetails["arrival_stop"] as? [String: Any])?["name"] as? String
                }

                transitSteps.append(TransitStep(
                    instruction: instruction,
                    distance: stepDistance,
                    duration: stepDuration,
                    travelMode: travelMode,
                    transitLineName: lineName,
                    transitLineColor: lineColor,
                    vehicleType: vehicleType,
                    polyline: stepCoords,
                    departureStop: departureStop,
                    arrivalStop: arrivalStop
                ))
            }
        }

        return RouteResult(
            polyline: polylineCoords,
            distance: totalDistance,
            expectedTravelTime: totalDuration,
            mode: .transit,
            transitSteps: transitSteps
        )
    }

    // MARK: - Reverse Geocoding

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> String? {
        do {
            let data = try await SupabaseProxy.request(
                service: "google_geocoding",
                params: [
                    "latlng": "\(coordinate.latitude),\(coordinate.longitude)",
                    "language": "ru",
                    "result_type": "street_address|route|locality",
                ]
            )

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String,
                  status == "OK",
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let address = first["formatted_address"] as? String else {
                return nil
            }

            return address
        } catch {
            return nil
        }
    }

    // MARK: - ETA Preview (Distance Matrix)

    func fetchETAPreviews(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async {
        print("[RoutingService] ⏱️ Fetching ETA previews for all modes...")
        etaPreviews = [:]
        let originStr = "\(origin.latitude),\(origin.longitude)"
        let destStr = "\(destination.latitude),\(destination.longitude)"

        // Fetch all modes in parallel via Distance Matrix
        let modes: [(TransportMode, String)] = [
            (.automobile, "driving"),
            (.walking, "walking"),
            (.cycling, "bicycling"),
            (.transit, "transit"),
        ]

        await withTaskGroup(of: (TransportMode, ModeETAPreview?).self) { group in
            for (mode, apiMode) in modes {
                group.addTask {
                    do {
                        let data = try await SupabaseProxy.request(
                            service: "google_distance_matrix",
                            params: [
                                "origins": originStr,
                                "destinations": destStr,
                                "mode": apiMode,
                                "language": "ru",
                            ]
                        )

                        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let rows = json["rows"] as? [[String: Any]],
                              let row = rows.first,
                              let elements = row["elements"] as? [[String: Any]],
                              let element = elements.first,
                              let status = element["status"] as? String,
                              status == "OK",
                              let duration = (element["duration"] as? [String: Any])?["value"] as? Double,
                              let distance = (element["distance"] as? [String: Any])?["value"] as? Double else {
                            return (mode, nil)
                        }

                        return (mode, ModeETAPreview(mode: mode, duration: duration, distance: distance))
                    } catch {
                        return (mode, nil)
                    }
                }
            }

            for await (mode, preview) in group {
                if let preview {
                    etaPreviews[mode] = preview
                    print("[RoutingService] ⏱️ ETA \(mode.rawValue): \(Self.formatDuration(preview.duration)), \(Self.formatDistance(preview.distance))")
                } else {
                    print("[RoutingService] ⏱️ ETA \(mode.rawValue): unavailable")
                }
            }
        }
        print("[RoutingService] ⏱️ ETA previews complete: \(etaPreviews.count)/4 modes")
    }

    // MARK: - Polyline Decoder

    /// Decode Google's encoded polyline format
    static func decodeGooglePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        guard !encoded.isEmpty else { return [] }
        var coords: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex
        var lat: Int32 = 0
        var lng: Int32 = 0

        while index < encoded.endIndex {
            var shift: Int32 = 0
            var result: Int32 = 0
            var byte: Int32

            repeat {
                byte = Int32(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20

            let dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lat += dLat

            shift = 0
            result = 0

            repeat {
                guard index < encoded.endIndex else { break }
                byte = Int32(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20

            let dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lng += dLng

            coords.append(CLLocationCoordinate2D(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            ))
        }

        return coords
    }

    // MARK: - Formatting

    static func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f км", meters / 1000)
        }
        return "\(Int(meters)) м"
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours) ч \(minutes) мин" : "\(hours) ч"
        }
        return "\(totalMinutes) мин"
    }

    static func openAppleMapsTransit(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        destinationName: String
    ) {
        let source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        source.name = "Старт"
        let dest = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        dest.name = destinationName
        MKMapItem.openMaps(
            with: [source, dest],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit]
        )
    }

    func clearCache() {
        cache.removeAll()
        etaPreviews.removeAll()
    }

    // MARK: - Turn-by-turn Navigation Steps

    /// Fetch turn-by-turn navigation steps via MKDirections (free, offline-capable).
    /// For transit mode, converts existing TransitStep array instead.
    func fetchNavigationSteps(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TransportMode,
        existingTransitSteps: [TransitStep] = []
    ) async -> [NavigationStep] {
        // Transit: convert existing TransitStep to NavigationStep
        if mode == .transit {
            return existingTransitSteps.map { step in
                NavigationStep(
                    instruction: step.instruction,
                    distance: step.distance,
                    polyline: step.polyline,
                    isTransit: true
                )
            }
        }

        // Walk / Drive / Bike: use MKDirections
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = mode.mkTransportType

        let directions = MKDirections(request: request)
        guard let response = try? await directions.calculate(),
              let route = response.routes.first else {
            print("[RoutingService] MKDirections step fetch failed for \(mode.rawValue)")
            return []
        }

        return route.steps
            .filter { !$0.instructions.isEmpty }
            .map { step in
                NavigationStep(
                    instruction: step.instructions,
                    distance: step.distance,
                    polyline: step.polyline.coordinates,
                    isTransit: false
                )
            }
    }
}
