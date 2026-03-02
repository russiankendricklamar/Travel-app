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
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let urlString = "https://\(language).wikipedia.org/w/api.php?action=query&list=search&srsearch=\(encoded)&srlimit=1&format=json"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let result = try JSONDecoder().decode(SearchResult.self, from: data)
            return result.query?.search?.first?.title
        } catch {
            return nil
        }
    }

    private static func fetchSummary(title: String, language: String) async -> String? {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        let urlString = "https://\(language).wikipedia.org/api/rest_v1/page/summary/\(encoded)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let summary = try JSONDecoder().decode(PageSummary.self, from: data)
            let extract = summary.extract ?? ""
            guard !extract.isEmpty else { return nil }
            return extract
        } catch {
            return nil
        }
    }
}
