import Foundation
import Supabase

/// Generic push/pull engine for Supabase sync
final class SyncEngine {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Push (upsert)

    func push<T: Encodable>(table: String, records: [T]) async throws {
        guard !records.isEmpty else { return }
        try await client
            .from(table)
            .upsert(records, onConflict: "id")
            .execute()
    }

    // MARK: - Pull (fetch updated rows)

    func pull<T: Decodable>(
        table: String,
        since: Date,
        userID: UUID
    ) async throws -> [T] {
        let sinceString = SyncDateFormatter.string(from: since)
        let response: [T] = try await client
            .from(table)
            .select()
            .gt("updated_at", value: sinceString)
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        return response
    }

    // MARK: - Pull all (for first sync)

    func pullAll<T: Decodable>(
        table: String,
        userID: UUID
    ) async throws -> [T] {
        let response: [T] = try await client
            .from(table)
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
        return response
    }
}
