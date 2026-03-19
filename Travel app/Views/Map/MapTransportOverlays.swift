import Foundation
import MapKit
import SwiftUI

// MARK: - Flight Arc Data

struct FlightArc: Identifiable {
    let id = UUID()
    let points: [CLLocationCoordinate2D]
    let depCoord: CLLocationCoordinate2D
    let arrCoord: CLLocationCoordinate2D
    let depIata: String
    let arrIata: String
    let midpoint: CLLocationCoordinate2D
    let bearing: Double
    let flightNumber: String
}

struct FlightAirportPin: Identifiable {
    let id = UUID()
    let iata: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Train Route Data

struct TrainRoute: Identifiable {
    let id = UUID()
    let polyline: [CLLocationCoordinate2D]
    let midpoint: CLLocationCoordinate2D
    let title: String
    let distance: CLLocationDistance?
    let duration: TimeInterval?
    var isRealTrack: Bool = false
    var isShinkansen: Bool = false

    var routeColor: Color {
        isShinkansen ? AppTheme.oceanBlue : AppTheme.bambooGreen
    }
}

// MARK: - Loading Logic

enum TransportOverlayLoader {

    static func loadFlightArcs(for trip: Trip) async -> [FlightArc] {
        guard !trip.flights.isEmpty, AirLabsService.shared.hasApiKey else { return [] }

        var arcs: [FlightArc] = []

        for flight in trip.flights {
            guard let data = await AirLabsService.shared.fetchFlight(number: flight.number, date: flight.date),
                  let depCoord = FlightData.coordinate(forIata: data.departureIata),
                  let arrCoord = FlightData.coordinate(forIata: data.arrivalIata) else { continue }

            let points = greatCirclePoints(from: depCoord, to: arrCoord)
            let midIdx = points.count / 2
            let midpoint = points[midIdx]
            let before = points[max(midIdx - 5, 0)]
            let after = points[min(midIdx + 5, points.count - 1)]
            let bearing = screenBearing(from: before, to: after)

            arcs.append(FlightArc(
                points: points,
                depCoord: depCoord,
                arrCoord: arrCoord,
                depIata: data.departureIata,
                arrIata: data.arrivalIata,
                midpoint: midpoint,
                bearing: bearing,
                flightNumber: data.flightIata
            ))
        }

        return arcs
    }

    static func loadTrainRoutes(for trip: Trip) async -> [TrainRoute] {
        let trainEvents = trip.days.flatMap(\.events).filter { $0.category.isRail }
        guard !trainEvents.isEmpty else { return [] }

        let railwayService = JapanRailwayGeoService.shared
        railwayService.loadIfNeeded()

        var routes: [TrainRoute] = []

        for event in trainEvents {
            guard let start = event.primaryCoordinate,
                  let end = event.arrivalCoordinate else { continue }

            let isShinkansenEvent = event.category == .shinkansen

            // 1) For shinkansen events — try shinkansen-specific search first
            if isShinkansenEvent {
                if let result = railwayService.findShinkansenRoute(from: start, to: end) {
                    let midIdx = result.coordinates.count / 2
                    let totalDist = railDistanceMeters(result.coordinates)
                    routes.append(TrainRoute(
                        polyline: result.coordinates,
                        midpoint: result.coordinates[midIdx],
                        title: "\(event.title) (\(result.lineName))",
                        distance: totalDist,
                        duration: nil,
                        isRealTrack: true,
                        isShinkansen: true
                    ))
                    continue
                }
            }

            // 2) Try MLIT real railway geometry (Shinkansen + JR)
            if let railCoords = railwayService.findRoute(from: start, to: end, lineName: event.title),
               railCoords.count >= 2 {
                let midIdx = railCoords.count / 2
                let totalDist = railDistanceMeters(railCoords)
                // Auto-detect: check if the matched segments are shinkansen
                let detectedShinkansen = isShinkansenEvent || railwayService.isRouteShinkansen(from: start, to: end, lineName: event.title)
                routes.append(TrainRoute(
                    polyline: railCoords,
                    midpoint: railCoords[midIdx],
                    title: event.title,
                    distance: totalDist,
                    duration: nil,
                    isRealTrack: true,
                    isShinkansen: detectedShinkansen
                ))
                continue
            }

            // 3) Try Shinkansen-specific search (fallback for regular train events near shinkansen lines)
            if let result = railwayService.findShinkansenRoute(from: start, to: end) {
                let midIdx = result.coordinates.count / 2
                let totalDist = railDistanceMeters(result.coordinates)
                routes.append(TrainRoute(
                    polyline: result.coordinates,
                    midpoint: result.coordinates[midIdx],
                    title: "\(event.title) (\(result.lineName))",
                    distance: totalDist,
                    duration: nil,
                    isRealTrack: true,
                    isShinkansen: true
                ))
                continue
            }

            // 4) Fallback: MKDirections (for non-Japan or missing data)
            var resolved = false
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
                    mkRoute.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: mkRoute.polyline.pointCount))

                    let midIdx = coords.count / 2
                    routes.append(TrainRoute(
                        polyline: coords,
                        midpoint: coords[midIdx],
                        title: event.title,
                        distance: mkRoute.distance,
                        duration: mkRoute.expectedTravelTime,
                        isShinkansen: isShinkansenEvent
                    ))
                    resolved = true
                    break
                }
            }

            if !resolved {
                routes.append(TrainRoute(
                    polyline: [start, end],
                    midpoint: CLLocationCoordinate2D(
                        latitude: (start.latitude + end.latitude) / 2,
                        longitude: (start.longitude + end.longitude) / 2
                    ),
                    title: event.title,
                    distance: nil,
                    duration: nil,
                    isShinkansen: isShinkansenEvent
                ))
            }
        }

        return routes
    }

    private static func railDistanceMeters(_ coords: [CLLocationCoordinate2D]) -> Double {
        guard coords.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 1..<coords.count {
            let a = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let b = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            total += a.distance(from: b)
        }
        return total
    }

    static func flightAirportAnnotations(from arcs: [FlightArc]) -> [FlightAirportPin] {
        var seen = Set<String>()
        var pins: [FlightAirportPin] = []
        for arc in arcs {
            for (iata, coord) in [(arc.depIata, arc.depCoord), (arc.arrIata, arc.arrCoord)] {
                guard !seen.contains(iata) else { continue }
                seen.insert(iata)
                pins.append(FlightAirportPin(iata: iata, coordinate: coord))
            }
        }
        return pins
    }

    // MARK: - Great Circle Math

    static func greatCirclePoints(
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

    static func screenBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let dLat = to.latitude - from.latitude
        let dLon = to.longitude - from.longitude
        let midLatRad = ((from.latitude + to.latitude) / 2) * .pi / 180
        let visualDLon = dLon * cos(midLatRad)
        return atan2(visualDLon, dLat) * 180 / .pi
    }
}
