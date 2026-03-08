import Foundation

struct CachedAIResponse: Codable {
    let response: String
    let tripID: UUID?
    let createdAt: Date
}

@MainActor
@Observable
final class AICacheManager {
    static let shared = AICacheManager()
    private init() {
        loadFromDisk()
        evictStaleEntries()
    }

    private var cache: [String: CachedAIResponse] = [:]
    private let storageKey = "aiCacheManager_v1"
    private let maxEntries = 200
    private let ttlSeconds: TimeInterval = 7 * 24 * 3600 // 7 days

    func get(key: String) -> String? {
        guard let entry = cache[key] else { return nil }
        if Date().timeIntervalSince(entry.createdAt) > ttlSeconds {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.response
    }

    func set(key: String, response: String, tripID: UUID?) {
        cache[key] = CachedAIResponse(response: response, tripID: tripID, createdAt: Date())
        enforceMaxEntries()
        saveToDisk()
    }

    func clearForTrip(_ tripID: UUID) {
        cache = cache.filter { $0.value.tripID != tripID }
        saveToDisk()
    }

    func cachedPlaceNames(for tripID: UUID) -> [String] {
        cache.filter { $0.value.tripID == tripID && $0.key.hasPrefix("ai:recommend:") }
            .map { $0.key }
    }

    func clearAll() {
        cache.removeAll()
        saveToDisk()
    }

    // MARK: - Eviction

    private func evictStaleEntries() {
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.createdAt) <= ttlSeconds }
    }

    private func enforceMaxEntries() {
        guard cache.count > maxEntries else { return }
        let sorted = cache.sorted { $0.value.createdAt < $1.value.createdAt }
        let toRemove = sorted.prefix(cache.count - maxEntries)
        for entry in toRemove {
            cache.removeValue(forKey: entry.key)
        }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: CachedAIResponse].self, from: data) else { return }
        cache = decoded
    }
}
