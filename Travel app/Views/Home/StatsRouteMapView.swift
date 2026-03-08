import SwiftUI
import MapKit
import CoreLocation

struct StatsRouteMapView: View {
    let trips: [Trip]
    @State private var showFullMap = false

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
            ForEach(trainRoutes) { route in
                MapPolyline(coordinates: [route.start, route.end])
                    .stroke(AppTheme.sakuraPink.opacity(0.8), lineWidth: 2)
            }
            ForEach(busRoutes) { route in
                MapPolyline(coordinates: [route.start, route.end])
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
                trainRoutes: trainRoutes,
                busRoutes: busRoutes,
                airportAnnotations: airportAnnotations
            )
        }
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
                let arcPoints = flightArcPoints(from: depCoord, to: arrCoord)
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

    private var trainRoutes: [TransportRoute] {
        transportRoutes(for: .train)
    }

    private var busRoutes: [TransportRoute] {
        transportRoutes(for: .bus)
    }

    private func transportRoutes(for category: EventCategory) -> [TransportRoute] {
        var routes: [TransportRoute] = []
        for trip in trips {
            for day in trip.days {
                for event in day.events where event.category == category {
                    guard let startCoord = event.primaryCoordinate,
                          let endCoord = event.arrivalCoordinate else { continue }
                    routes.append(TransportRoute(start: startCoord, end: endCoord))
                }
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

    // MARK: - Bezier Arc

    private func flightArcPoints(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        segments: Int = 60
    ) -> [CLLocationCoordinate2D] {
        let dLat = end.latitude - start.latitude
        let dLon = end.longitude - start.longitude
        let dist = sqrt(dLat * dLat + dLon * dLon)
        guard dist > 0 else { return [start, end] }

        let midLat = (start.latitude + end.latitude) / 2
        let midLon = (start.longitude + end.longitude) / 2

        let perpLat = -dLon / dist
        let perpLon = dLat / dist

        let sign: Double = perpLat >= 0 ? 1 : -1
        let height = dist * 0.15

        let ctrlLat = midLat + sign * perpLat * height
        let ctrlLon = midLon + sign * perpLon * height

        return (0...segments).map { i in
            let t = Double(i) / Double(segments)
            let lat = (1 - t) * (1 - t) * start.latitude + 2 * (1 - t) * t * ctrlLat + t * t * end.latitude
            let lon = (1 - t) * (1 - t) * start.longitude + 2 * (1 - t) * t * ctrlLon + t * t * end.longitude
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}

// MARK: - Full Screen Map

private struct StatsFullMapView: View {
    let trips: [Trip]
    let flightRoutes: [FlightRoute]
    let trainRoutes: [TransportRoute]
    let busRoutes: [TransportRoute]
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
                            MapPolyline(coordinates: [route.start, route.end])
                                .stroke(AppTheme.sakuraPink.opacity(0.8), lineWidth: 2)
                        }
                    }

                    if filter == .all || filter == .buses {
                        ForEach(busRoutes) { route in
                            MapPolyline(coordinates: [route.start, route.end])
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

struct TransportRoute: Identifiable {
    let id = UUID()
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
}

struct AirportAnnotation: Identifiable {
    let id = UUID()
    let iata: String
    let coordinate: CLLocationCoordinate2D
}
