import Foundation
import Supabase

@Observable
final class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey
        )
    }

    var currentUserID: UUID? {
        client.auth.currentUser?.id
    }
}
