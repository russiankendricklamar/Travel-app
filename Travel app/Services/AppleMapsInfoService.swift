import Foundation
import MapKit
import CoreLocation

struct AppleMapsPlaceInfo {
    let mapItem: MKMapItem
    let phoneNumber: String?
    let website: URL?
    let localAddress: String?
    let englishAddress: String?
}

@Observable
final class AppleMapsInfoService {
    static let shared = AppleMapsInfoService()
    private init() {}

    private var cache: [String: AppleMapsPlaceInfo] = [:]

    func fetchInfo(name: String, coordinate: CLLocationCoordinate2D) async -> AppleMapsPlaceInfo? {
        let cacheKey = "\(name)_\(String(format: "%.5f", coordinate.latitude))_\(String(format: "%.5f", coordinate.longitude))"
        if let cached = cache[cacheKey] { return cached }

        let mapItem = await searchMapItem(name: name, coordinate: coordinate)
        guard let item = mapItem else { return nil }

        let addresses = await fetchAddresses(coordinate: coordinate)

        let info = AppleMapsPlaceInfo(
            mapItem: item,
            phoneNumber: item.phoneNumber,
            website: item.url,
            localAddress: addresses.local,
            englishAddress: addresses.english
        )

        cache[cacheKey] = info
        return info
    }

    private func searchMapItem(name: String, coordinate: CLLocationCoordinate2D) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        request.resultTypes = .pointOfInterest

        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        if let response = try? await MKLocalSearch(request: request).start() {
            let match = response.mapItems
                .filter { ($0.placemark.location?.distance(from: target) ?? .infinity) < 300 }
                .min { ($0.placemark.location?.distance(from: target) ?? .infinity) < ($1.placemark.location?.distance(from: target) ?? .infinity) }
            if let match { return match }
        }

        // Fallback: address search
        let fallback = MKLocalSearch.Request()
        fallback.naturalLanguageQuery = name
        fallback.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        fallback.resultTypes = .address

        return try? await MKLocalSearch(request: fallback).start().mapItems.first
    }

    private func fetchAddresses(coordinate: CLLocationCoordinate2D) async -> (local: String?, english: String?) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        async let localPlacemarks = CLGeocoder().reverseGeocodeLocation(location)
        async let englishPlacemarks = CLGeocoder().reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: "en")
        )

        let localAddr = formatPlacemark((try? await localPlacemarks)?.first)
        let englishAddr = formatPlacemark((try? await englishPlacemarks)?.first)

        return (local: localAddr, english: englishAddr)
    }

    private func formatPlacemark(_ pm: CLPlacemark?) -> String? {
        guard let pm else { return nil }
        var parts: [String] = []
        if let street = pm.thoroughfare {
            if let number = pm.subThoroughfare {
                parts.append("\(street), \(number)")
            } else {
                parts.append(street)
            }
        }
        if let subLocality = pm.subLocality { parts.append(subLocality) }
        if let city = pm.locality { parts.append(city) }
        if let area = pm.administrativeArea, !parts.contains(area) { parts.append(area) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    func clearCache() {
        cache.removeAll()
    }
}
