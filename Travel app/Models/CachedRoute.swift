import Foundation
import SwiftData
import CoreLocation

// MARK: - Codable DTOs for non-Codable types

struct CoordDTO: Codable {
    let lat: Double
    let lng: Double
}

struct NavigationStepDTO: Codable {
    let instruction: String
    let distance: Double
    let polyline: [CoordDTO]
    let isTransit: Bool
}

struct TransitStepDTO: Codable {
    let instruction: String
    let distance: Double
    let duration: Double
    let travelMode: String
    let transitLineName: String?
    let transitLineColor: String?
    let vehicleType: String?
    let polyline: [CoordDTO]
    let departureStop: String?
    let arrivalStop: String?
}

// MARK: - CachedRoute Model

@Model
final class CachedRoute {
    @Attribute(.unique) var id: UUID
    var originPlaceID: UUID
    var destinationPlaceID: UUID
    var mode: String               // TransportMode.rawValue
    var createdAt: Date
    var polylineData: Data         // JSON-encoded [CoordDTO]
    var navigationStepsData: Data  // JSON-encoded [NavigationStepDTO]
    var transitStepsData: Data     // JSON-encoded [TransitStepDTO]
    var distanceMeters: Double
    var expectedTravelTimeSeconds: Double
    var trafficDurationSeconds: Double?  // optional, driving only
    var tripID: UUID               // for cascade delete on trip removal

    init(
        id: UUID = UUID(),
        originPlaceID: UUID,
        destinationPlaceID: UUID,
        mode: String,
        createdAt: Date = Date(),
        polylineData: Data,
        navigationStepsData: Data,
        transitStepsData: Data = Data(),
        distanceMeters: Double,
        expectedTravelTimeSeconds: Double,
        trafficDurationSeconds: Double? = nil,
        tripID: UUID
    ) {
        self.id = id
        self.originPlaceID = originPlaceID
        self.destinationPlaceID = destinationPlaceID
        self.mode = mode
        self.createdAt = createdAt
        self.polylineData = polylineData
        self.navigationStepsData = navigationStepsData
        self.transitStepsData = transitStepsData
        self.distanceMeters = distanceMeters
        self.expectedTravelTimeSeconds = expectedTravelTimeSeconds
        self.trafficDurationSeconds = trafficDurationSeconds
        self.tripID = tripID
    }
}

// MARK: - Encoding/Decoding Helpers

extension CachedRoute {
    static let ttl: TimeInterval = 7 * 24 * 3600  // 7 days

    static func encodePolyline(_ coords: [CLLocationCoordinate2D]) -> Data {
        let dtos = coords.map { CoordDTO(lat: $0.latitude, lng: $0.longitude) }
        return (try? JSONEncoder().encode(dtos)) ?? Data()
    }

    static func decodePolyline(_ data: Data) -> [CLLocationCoordinate2D] {
        guard let dtos = try? JSONDecoder().decode([CoordDTO].self, from: data) else { return [] }
        return dtos.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    static func encodeNavigationSteps(_ steps: [NavigationStep]) -> Data {
        let dtos = steps.map { step in
            NavigationStepDTO(
                instruction: step.instruction,
                distance: step.distance,
                polyline: step.polyline.map { CoordDTO(lat: $0.latitude, lng: $0.longitude) },
                isTransit: step.isTransit
            )
        }
        return (try? JSONEncoder().encode(dtos)) ?? Data()
    }

    static func decodeNavigationSteps(_ data: Data) -> [NavigationStep] {
        guard let dtos = try? JSONDecoder().decode([NavigationStepDTO].self, from: data) else { return [] }
        return dtos.map { dto in
            NavigationStep(
                instruction: dto.instruction,
                distance: dto.distance,
                polyline: dto.polyline.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) },
                isTransit: dto.isTransit
            )
        }
    }

    static func encodeTransitSteps(_ steps: [TransitStep]) -> Data {
        let dtos = steps.map { step in
            TransitStepDTO(
                instruction: step.instruction,
                distance: step.distance,
                duration: step.duration,
                travelMode: step.travelMode,
                transitLineName: step.transitLineName,
                transitLineColor: step.transitLineColor,
                vehicleType: step.vehicleType,
                polyline: step.polyline.map { CoordDTO(lat: $0.latitude, lng: $0.longitude) },
                departureStop: step.departureStop,
                arrivalStop: step.arrivalStop
            )
        }
        return (try? JSONEncoder().encode(dtos)) ?? Data()
    }

    static func decodeTransitSteps(_ data: Data) -> [TransitStep] {
        guard let dtos = try? JSONDecoder().decode([TransitStepDTO].self, from: data) else { return [] }
        return dtos.map { dto in
            TransitStep(
                instruction: dto.instruction,
                distance: dto.distance,
                duration: dto.duration,
                travelMode: dto.travelMode,
                transitLineName: dto.transitLineName,
                transitLineColor: dto.transitLineColor,
                vehicleType: dto.vehicleType,
                polyline: dto.polyline.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) },
                departureStop: dto.departureStop,
                arrivalStop: dto.arrivalStop
            )
        }
    }

    func toRouteResult() -> RouteResult {
        let polyline = CachedRoute.decodePolyline(polylineData)
        let navSteps = CachedRoute.decodeNavigationSteps(navigationStepsData)
        let transitSteps = CachedRoute.decodeTransitSteps(transitStepsData)
        return RouteResult(
            polyline: polyline,
            distance: distanceMeters,
            expectedTravelTime: expectedTravelTimeSeconds,
            mode: TransportMode(rawValue: mode) ?? .walking,
            transitSteps: transitSteps,
            trafficDuration: trafficDurationSeconds,
            navigationSteps: navSteps
        )
    }

    static func from(
        _ result: RouteResult,
        originPlaceID: UUID,
        destinationPlaceID: UUID,
        tripID: UUID
    ) -> CachedRoute {
        CachedRoute(
            originPlaceID: originPlaceID,
            destinationPlaceID: destinationPlaceID,
            mode: result.mode.rawValue,
            polylineData: encodePolyline(result.polyline),
            navigationStepsData: encodeNavigationSteps(result.navigationSteps),
            transitStepsData: encodeTransitSteps(result.transitSteps),
            distanceMeters: result.distance,
            expectedTravelTimeSeconds: result.expectedTravelTime,
            trafficDurationSeconds: result.trafficDuration,
            tripID: tripID
        )
    }
}
