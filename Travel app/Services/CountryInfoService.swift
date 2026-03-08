import Foundation
import SwiftData

// MARK: - Country Info

struct CountryInfo: Codable {
    let flagEmoji: String
    let currencyCode: String?
    let currencySymbol: String?
    let language: String?
    let capital: String?
    let region: String?
}

// MARK: - Country Info Service

@MainActor
@Observable
final class CountryInfoService {
    static let shared = CountryInfoService()

    private var cache: [String: CountryInfo] = [:]
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    func fetchInfo(for country: String) async -> CountryInfo? {
        let key = country.lowercased()
        if let cached = cache[key] { return cached }

        guard let encoded = country.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://restcountries.com/v3.1/name/\(encoded)?fields=name,flag,currencies,languages,capital,region") else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return nil
            }

            let items = try JSONDecoder().decode([RestCountryResponse].self, from: data)
            guard let first = items.first else { return nil }

            let currencyEntry = first.currencies?.first
            let info = CountryInfo(
                flagEmoji: first.flag ?? "",
                currencyCode: currencyEntry?.key,
                currencySymbol: currencyEntry?.value.symbol,
                language: first.languages?.values.first,
                capital: first.capital?.first,
                region: first.region
            )
            cache[key] = info
            return info
        } catch {
            return nil
        }
    }

    func fetchAll(for countries: [String]) async -> [String: CountryInfo] {
        var result: [String: CountryInfo] = [:]
        await withTaskGroup(of: (String, CountryInfo?).self) { group in
            for country in countries {
                group.addTask {
                    let info = await self.fetchInfo(for: country)
                    return (country, info)
                }
            }
            for await (country, info) in group {
                if let info { result[country] = info }
            }
        }
        return result
    }

    @MainActor
    func populateTrip(_ trip: Trip, context: ModelContext) async {
        let countries = trip.countries
        guard !countries.isEmpty else { return }

        let infos = await fetchAll(for: countries)
        let flags = countries.compactMap { infos[$0]?.flagEmoji }.filter { !$0.isEmpty }
        trip.countryFlags = flags.joined(separator: " ")
        trip.updatedAt = Date()
        try? context.save()
    }
}

// MARK: - RestCountries API Response

private struct RestCountryResponse: Codable {
    let name: RestCountryName?
    let flag: String?
    let currencies: [String: RestCurrency]?
    let languages: [String: String]?
    let capital: [String]?
    let region: String?
}

private struct RestCountryName: Codable {
    let common: String?
    let official: String?
}

private struct RestCurrency: Codable {
    let name: String?
    let symbol: String?
}
