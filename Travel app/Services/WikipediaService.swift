import Foundation

struct WikipediaService {

    // MARK: - Models

    struct SearchResult: Decodable {
        let query: SearchQuery?
    }

    struct SearchQuery: Decodable {
        let search: [SearchItem]?
    }

    struct SearchItem: Decodable {
        let title: String
        let pageid: Int
    }

    struct PageSummary: Decodable {
        let title: String
        let extract: String?
        let description: String?
    }

    // MARK: - Public

    /// Search Wikipedia for a place and return the article extract.
    /// Tries Russian Wikipedia first, then English.
    static func fetchExtract(for query: String) async -> (text: String, language: String)? {
        // Try Russian first
        if let result = await searchAndExtract(query: query, language: "ru") {
            return (result, "ru")
        }
        // Fallback to English
        if let result = await searchAndExtract(query: query, language: "en") {
            return (result, "en")
        }
        return nil
    }

    // MARK: - Private

    private static func searchAndExtract(query: String, language: String) async -> String? {
        guard let title = await searchTitle(query: query, language: language) else {
            return nil
        }
        return await fetchSummary(title: title, language: language)
    }

    private static func searchTitle(query: String, language: String) async -> String? {
        do {
            let data = try await SupabaseProxy.request(service: "wikipedia", action: "search", params: ["language": language, "query": query])
            let result = try JSONDecoder().decode(SearchResult.self, from: data)
            return result.query?.search?.first?.title
        } catch {
            return nil
        }
    }

    private static func fetchSummary(title: String, language: String) async -> String? {
        do {
            let data = try await SupabaseProxy.request(service: "wikipedia", action: "summary", params: ["language": language, "title": title])
            let summary = try JSONDecoder().decode(PageSummary.self, from: data)
            let extract = summary.extract ?? ""
            guard !extract.isEmpty else { return nil }
            return extract
        } catch {
            return nil
        }
    }
}
