import Foundation
import MapKit
import CoreLocation

// MARK: - NavigationStep

/// A single turn-by-turn navigation instruction.
/// Created from MKRouteStep (walk/drive/bike) or TransitStep (transit).
struct NavigationStep {
    let instruction: String
    let distance: CLLocationDistance
    let polyline: [CLLocationCoordinate2D]
    let isTransit: Bool
}

// MARK: - MKPolyline Extension

extension MKPolyline {
    /// Extract coordinate array from an MKPolyline
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - TransportMode Extension

extension TransportMode {
    /// Map app transport mode to MKDirections transport type.
    /// Cycling uses .walking because MKDirections has no cycling type.
    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .walking: return .walking
        case .automobile: return .automobile
        case .transit: return .transit
        case .cycling: return .walking
        }
    }
}
