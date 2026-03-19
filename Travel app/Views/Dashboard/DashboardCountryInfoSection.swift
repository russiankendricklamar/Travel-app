import SwiftUI

struct DashboardCountryInfoSection: View {
    let trip: Trip
    @State private var countryInfos: [String: CountryInfo] = [:]
    @State private var isLoading = false

    var body: some View {
        Group {
            if !countryInfos.isEmpty {
                VStack(spacing: AppTheme.spacingS) {
                    sectionHeader

                    ForEach(trip.countries, id: \.self) { country in
                        if let info = countryInfos[country] {
                            countryRow(country: country, info: info)
                        }
                    }
                }
                .padding(AppTheme.spacingM)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                        .strokeBorder(
                            LinearGradient(
                                colors: [AppTheme.sakuraPink.opacity(0.3), AppTheme.sakuraPink.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
            } else if isLoading {
                VStack(spacing: AppTheme.spacingS) {
                    ProgressView()
                    Text("Загрузка информации...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            }
        }
        .task {
            guard countryInfos.isEmpty else { return }
            isLoading = true
            countryInfos = await CountryInfoService.shared.fetchAll(for: trip.countries)
            isLoading = false
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppTheme.sakuraPink)
                .frame(width: 3, height: 12)
            Text("О СТРАНЕ")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(AppTheme.sakuraPink)
            Spacer()
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.5))
        }
    }

    // MARK: - Country Row

    private func countryRow(country: String, info: CountryInfo) -> some View {
        VStack(spacing: 8) {
            // Flag + country name
            HStack(spacing: 10) {
                Text(info.flagEmoji)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 2) {
                    Text(country)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    if let region = info.region {
                        Text(region)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }

            // Info grid
            HStack(spacing: 0) {
                if let capital = info.capital {
                    infoItem(icon: "building.2.fill", label: "СТОЛИЦА", value: capital)
                }
                if let language = info.language {
                    infoItem(icon: "character.bubble.fill", label: "ЯЗЫК", value: language)
                }
                if let code = info.currencyCode {
                    let display = info.currencySymbol.map { "\($0) \(code)" } ?? code
                    infoItem(icon: "banknote.fill", label: "ВАЛЮТА", value: display)
                }
            }
        }
        .padding(AppTheme.spacingS)
        .background(AppTheme.sakuraPink.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }

    private func infoItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 7, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: - Array Unique Helper

extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
