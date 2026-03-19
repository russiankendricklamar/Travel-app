import Foundation

/// Единый прокси для всех внешних API через Supabase Edge Function.
/// Ключи хранятся на сервере — клиент не содержит API-ключей.
enum SupabaseProxy {
    private static let proxyURL = "\(Secrets.supabaseURL)/functions/v1/api-proxy"

    static func request(
        service: String,
        action: String = "",
        params: [String: String] = [:]
    ) async throws -> Data {
        guard let url = URL(string: proxyURL) else {
            throw ProxyError.badURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.timeoutInterval = service == "gemini" ? 60 : 30

        let body: [String: Any] = [
            "service": service,
            "action": action,
            "params": params
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? ""
            print("[SupabaseProxy] HTTP \(code) for \(service)/\(action): \(preview)")
            throw ProxyError.httpError(code)
        }

        return data
    }

    enum ProxyError: LocalizedError {
        case badURL
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .badURL: return "Некорректный URL прокси"
            case .httpError(let code): return "Ошибка прокси: HTTP \(code)"
            }
        }
    }
}
