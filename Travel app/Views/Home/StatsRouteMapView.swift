import SwiftUI
import MapKit
import CoreLocation

struct StatsRouteMapView: View {
    let trips: [Trip]
    @State private var showFullMap = false
    @State private var resolvedTrainRoutes: [ResolvedTransportRoute] = []
    @State private var resolvedBusRoutes: [ResolvedTransportRoute] = []

    var body: some View {
        Map {
            ForEach(flightRoutes) { route in
                MapPolyline(coordinates: route.arcPoints)
                    .stroke(AppTheme.oceanBlue.opacity(0.8), lineWidth: 2)
            }
            ForEach(airportAnnotations) { airport in
                Annotation("", coordinate: airport.coordinate, anchor: .center) {
                    Circle()
                        .fill(AppTheme.oceanBlue)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1))
                }
            }
            ForEach(resolvedTrainRoutes) { route in
                MapPolyline(coordinates: route.polyline)
                    .stroke(AppTheme.sakuraPink.opacity(0.8), lineWidth: 2)
            }
            ForEach(resolvedBusRoutes) { route in
                MapPolyline(coordinates: route.polyline)
                    .stroke(AppTheme.templeGold.opacity(0.8), lineWidth: 2)
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .padding(8)
        }
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .onTapGesture { showFullMap = true }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .sheet(isPresented: $showFullMap) {
            StatsFullMapView(
                trips: trips,
                flightRoutes: flightRoutes,
                trainRoutes: resolvedTrainRoutes,
                busRoutes: resolvedBusRoutes,
                airportAnnotations: airportAnnotations
            )
        }
        .task { await loadTransportRoutes() }
    }

    // MARK: - Async Route Loading

    private func loadTransportRoutes() async {
        let trainEndpoints = transportEndpoints(for: .train)
        let busEndpoints = transportEndpoints(for: .bus)

        async let trains = resolveRoutes(trainEndpoints)
        async let buses = resolveRoutes(busEndpoints)

        resolvedTrainRoutes = await trains
        resolvedBusRoutes = await buses
    }

    private func transportEndpoints(for category: EventCategory) -> [(CLLocationCoordinate2D, CLLocationCoordinate2D)] {
        var endpoints: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []
        for trip in trips {
            for day in trip.days {
                for event in day.events where event.category == category {
                    guard let startCoord = event.primaryCoordinate,
                          let endCoord = event.arrivalCoordinate else { continue }
                    endpoints.append((startCoord, endCoord))
                }
            }
        }
        return endpoints
    }

    private func resolveRoutes(_ endpoints: [(CLLocationCoordinate2D, CLLocationCoordinate2D)]) async -> [ResolvedTransportRoute] {
        var routes: [ResolvedTransportRoute] = []
        for (start, end) in endpoints {
            let polyline = await calculateRoutePolyline(from: start, to: end)
            routes.append(ResolvedTransportRoute(start: start, end: end, polyline: polyline))
        }
        return routes
    }

    // MARK: - Flight Routes

    private var flightRoutes: [FlightRoute] {
        var routes: [FlightRoute] = []
        var seen = Set<String>()
        for trip in trips {
            for flight in trip.flights {
                let depIata = flight.departureIata ?? ""
                let arrIata = flight.arrivalIata ?? ""
                guard let depCoord = FlightData.coordinate(forIata: depIata),
                      let arrCoord = FlightData.coordinate(forIata: arrIata) else { continue }
                let key = "\(depIata)-\(arrIata)"
                let reverseKey = "\(arrIata)-\(depIata)"
                if seen.contains(key) || seen.contains(reverseKey) { continue }
                seen.insert(key)
                let arcPoints = greatCirclePoints(from: depCoord, to: arrCoord)
                routes.append(FlightRoute(
                    depIata: depIata,
                    arrIata: arrIata,
                    depCoord: depCoord,
                    arrCoord: arrCoord,
                    arcPoints: arcPoints
                ))
            }
        }
        return routes
    }

    private var airportAnnotations: [AirportAnnotation] {
        var seen = Set<String>()
        var annotations: [AirportAnnotation] = []
        for trip in trips {
            for flight in trip.flights {
                for iata in [flight.departureIata, flight.arrivalIata].compactMap({ $0 }) {
                    guard !seen.contains(iata),
                          let coord = FlightData.coordinate(forIata: iata) else { continue }
                    seen.insert(iata)
                    annotations.append(AirportAnnotation(iata: iata, coordinate: coord))
                }
            }
        }
        return annotations
    }

    // MARK: - Great Circle Arc

    private func greatCirclePoints(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        segments: Int = 60
    ) -> [CLLocationCoordinate2D] {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180

        let d = acos(
            sin(lat1) * sin(lat2) +
            cos(lat1) * cos(lat2) * cos(lon2 - lon1)
        )
        guard d > 1e-10 else { return [start, end] }

        return (0...segments).map { i in
            let t = Double(i) / Double(segments)
            let a = sin((1 - t) * d) / sin(d)
            let b = sin(t * d) / sin(d)

            let x = a * cos(lat1) * cos(lon1) + b * cos(lat2) * cos(lon2)
            let y = a * cos(lat1) * sin(lon1) + b * cos(lat2) * sin(lon2)
            let z = a * sin(lat1) + b * sin(lat2)

            let lat = atan2(z, sqrt(x * x + y * y)) * 180 / .pi
            let lon = atan2(y, x) * 180 / .pi
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}

// MARK: - Full Screen Map

private struct StatsFullMapView: View {
    let trips: [Trip]
    let flightRoutes: [FlightRoute]
    let trainRoutes: [ResolvedTransportRoute]
    let busRoutes: [ResolvedTransportRoute]
    let airportAnnotations: [AirportAnnotation]
    @Environment(\.dismiss) private var dismiss
    @State private var filter: RouteFilter = .all

    enum RouteFilter: String, CaseIterable {
        case all = "Все"
        case flights = "Перелёты"
        case trains = "Поезда"
        case buses = "Автобусы"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $filter) {
                    ForEach(RouteFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppTheme.sakuraPink)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.vertical, AppTheme.spacingS)

                Map {
                    if filter == .all || filter == .flights {
                        ForEach(flightRoutes) { route in
                            MapPolyline(coordinates: route.arcPoints)
                                .stroke(AppTheme.oceanBlue.opacity(0.8), lineWidth: 2)
                        }
                        ForEach(airportAnnotations) { airport in
                            Annotation("", coordinate: airport.coordinate, anchor: .center) {
                                VStack(spacing: 2) {
                                    Circle()
                                        .fill(AppTheme.oceanBlue)
                                        .frame(width: 10, height: 10)
                                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                    Text(airport.iata)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(AppTheme.oceanBlue.opacity(0.8))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    if filter == .all || filter == .trains {
                        ForEach(trainRoutes) { route in
                            MapPolyline(coordinates: route.polyline)
                                .stroke(AppTheme.sakuraPink.opacity(0.8), lineWidth: 2)
                        }
                    }

                    if filter == .all || filter == .buses {
                        ForEach(busRoutes) { route in
                            MapPolyline(coordinates: route.polyline)
                                .stroke(AppTheme.templeGold.opacity(0.8), lineWidth: 2)
                        }
                    }
                }
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("КАРТА МАРШРУТОВ")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ГОТОВО") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
        }
    }
}

// MARK: - Data Models

struct FlightRoute: Identifiable {
    let id = UUID()
    let depIata: String
    let arrIata: String
    let depCoord: CLLocationCoordinate2D
    let arrCoord: CLLocationCoordinate2D
    let arcPoints: [CLLocationCoordinate2D]
}

struct ResolvedTransportRoute: Identifiable {
    let id = UUID()
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let polyline: [CLLocationCoordinate2D]
}

struct AirportAnnotation: Identifiable {
    let id = UUID()
    let iata: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Route Calculation Helper

/// Shared helper: tries .transit → .automobile → straight line
func calculateRoutePolyline(
    from start: CLLocationCoordinate2D,
    to end: CLLocationCoordinate2D
) async -> [CLLocationCoordinate2D] {
    for transportType: MKDirectionsTransportType in [.transit, .automobile] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = transportType

        if let response = try? await MKDirections(request: request).calculate(),
           let mkRoute = response.routes.first {
            var coords = [CLLocationCoordinate2D](
                repeating: CLLocationCoordinate2D(),
                count: mkRoute.polyline.pointCount
            )
            mkRoute.polyline.getCoordinates(
                &coords,
                range: NSRange(location: 0, length: mkRoute.polyline.pointCount)
            )
            return coords
        }
    }
    return [start, end]
}
