import Foundation
import MapKit
import SwiftUI
import UIKit

enum TransportMode: String, CaseIterable, Identifiable {
    case automobile, walking, transit, cycling

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

    var mkTransportType: MKDirectionsTransportType? {
        switch self {
        case .automobile: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        case .cycling: return nil
        }
    }
}

struct RouteResult {
    let polyline: [CLLocationCoordinate2D]
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let mode: TransportMode
}

@Observable
final class RoutingService {
    static let shared = RoutingService()
    private init() {}

    private var cache: [String: RouteResult] = [:]

    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TransportMode
    ) async -> RouteResult? {
        guard let transportType = mode.mkTransportType else { return nil }

        let cacheKey = "\(String(format: "%.5f,%.5f", origin.latitude, origin.longitude))_\(String(format: "%.5f,%.5f", destination.latitude, destination.longitude))_\(mode.rawValue)"
        if let cached = cache[cacheKey] { return cached }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { return nil }

            let polyline = route.polyline
            var coords = [CLLocationCoordinate2D](
                repeating: CLLocationCoordinate2D(),
                count: polyline.pointCount
            )
            polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))

            let result = RouteResult(
                polyline: coords,
                distance: route.distance,
                expectedTravelTime: route.expectedTravelTime,
                mode: mode
            )

            cache[cacheKey] = result
            return result
        } catch {
            return nil
        }
    }

    @MainActor
    static func openCyclingInAppleMaps(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        destinationName: String? = nil
    ) {
        let saddr = "\(origin.latitude),\(origin.longitude)"
        let daddr = "\(destination.latitude),\(destination.longitude)"
        guard let url = URL(string: "maps://?saddr=\(saddr)&daddr=\(daddr)&dirflg=cy") else { return }
        UIApplication.shared.open(url)
    }

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

    func clearCache() {
        cache.removeAll()
    }
}
