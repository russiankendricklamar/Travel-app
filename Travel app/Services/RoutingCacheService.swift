import Foundation
import SwiftData
import CoreLocation

@MainActor @Observable
final class RoutingCacheService {
    static let shared = RoutingCacheService()
    private init() {}

    // L1: in-memory, current session only
    private var l1: [String: RouteResult] = [:]

    // MARK: - Cache Key

    func cacheKey(origin: UUID, destination: UUID, mode: TransportMode) -> String {
        "\(origin.uuidString)_\(destination.uuidString)_\(mode.rawValue)"
    }

    // MARK: - L1+L2 Lookup

    func lookup(origin: UUID, dest: UUID, mode: TransportMode, context: ModelContext) -> RouteResult? {
        let key = cacheKey(origin: origin, destination: dest, mode: mode)

        // L1 fast path
        if let hit = l1[key] { return hit }

        // L2: SwiftData query
        let modeRaw = mode.rawValue
        let ttlDate = Date().addingTimeInterval(-CachedRoute.ttl)
        var descriptor = FetchDescriptor<CachedRoute>(
            predicate: #Predicate<CachedRoute> {
                $0.originPlaceID == origin &&
                $0.destinationPlaceID == dest &&
                $0.mode == modeRaw &&
                $0.createdAt > ttlDate
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let cached = try? context.fetch(descriptor).first else { return nil }

        let result = cached.toRouteResult()
        l1[key] = result  // Populate L1 from L2 hit
        return result
    }

    // MARK: - Store (L1 + L2)

    func store(_ result: RouteResult, origin: UUID, dest: UUID, tripID: UUID, context: ModelContext) {
        let key = cacheKey(origin: origin, destination: dest, mode: result.mode)
        l1[key] = result

        // Upsert: delete existing entry for same key, then insert new
        let modeRaw = result.mode.rawValue
        let existing = FetchDescriptor<CachedRoute>(
            predicate: #Predicate<CachedRoute> {
                $0.originPlaceID == origin &&
                $0.destinationPlaceID == dest &&
                $0.mode == modeRaw
            }
        )
        if let old = try? context.fetch(existing) {
            for item in old { context.delete(item) }
        }

        let model = CachedRoute.from(result, originPlaceID: origin, destinationPlaceID: dest, tripID: tripID)
        context.insert(model)
        try? context.save()
    }

    // MARK: - Day Cache Check

    /// Check if all place pairs for a day are cached (for badge display)
    func isDayCached(_ day: TripDay, tripID: UUID, context: ModelContext) -> Bool {
        let placeIDs = day.sortedPlaces.map(\.id)
        guard placeIDs.count >= 2 else { return false }

        let ttlDate = Date().addingTimeInterval(-CachedRoute.ttl)
        let descriptor = FetchDescriptor<CachedRoute>(
            predicate: #Predicate<CachedRoute> {
                $0.tripID == tripID && $0.createdAt > ttlDate
            }
        )
        let cached = (try? context.fetch(descriptor)) ?? []
        let cachedKeys = Set(cached.map { "\($0.originPlaceID)_\($0.destinationPlaceID)_\($0.mode)" })

        // Check: every ordered pair for walking + automobile has a cache entry
        let modes = ["walking", "automobile"]
        for i in 0..<placeIDs.count {
            for j in 0..<placeIDs.count where i != j {
                for mode in modes {
                    let key = "\(placeIDs[i])_\(placeIDs[j])_\(mode)"
                    if !cachedKeys.contains(key) { return false }
                }
            }
        }
        return true
    }

    // MARK: - Invalidation

    func clearL1() { l1.removeAll() }

    func clearAll(context: ModelContext) {
        l1.removeAll()
        do {
            try context.delete(model: CachedRoute.self)
            try context.save()
        } catch {
            // Silent failure — cache clear is best-effort
        }
    }

    /// Delete all cached routes for a specific trip (cascade on trip delete)
    func clearForTrip(_ tripID: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<CachedRoute>(
            predicate: #Predicate<CachedRoute> { $0.tripID == tripID }
        )
        if let routes = try? context.fetch(descriptor) {
            for route in routes { context.delete(route) }
            try? context.save()
        }
    }
}
