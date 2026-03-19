import SwiftUI
import CoreLocation

struct CityComparisonView: View {
    let cities: [(String, CLLocationCoordinate2D)]

    @Environment(\.dismiss) private var dismiss

    @State private var cityData: [String: WeatherService.WeatherDetailData] = [:]
    @State private var isLoading = true

    private var weather: WeatherService { WeatherService.shared }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                if isLoading {
                    VStack(spacing: AppTheme.spacingS) {
                        ProgressView()
                        Text("Загрузка погоды для сравнения...")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(spacing: AppTheme.spacingM) {
                        temperatureComparison
                        conditionsComparison
                        detailsComparison
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.top, AppTheme.spacingS)
                }
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("СРАВНЕНИЕ")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(AppTheme.oceanBlue)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await loadAllCities()
            }
        }
    }

    // MARK: - Temperature

    private var temperatureComparison: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "ТЕМПЕРАТУРА", color: AppTheme.templeGold)

            HStack(spacing: 0) {
                ForEach(cities, id: \.0) { city, _ in
                    let data = cityData[city]
                    VStack(spacing: 6) {
                        Text(city)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let current = data?.current {
                            Image(systemName: current.sfSymbol)
                                .font(.system(size: 32))
                                .symbolRenderingMode(.multicolor)

                            Text("\(Int(current.temperature))°")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            Text(current.conditionLocalized)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            if let feels = current.apparentTemperature {
                                Text("Ощущ. \(Int(feels))°")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                        } else {
                            ProgressView()
                                .padding(.vertical, 20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacingM)

                    if city != cities.last?.0 {
                        Divider().opacity(0.15)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingS)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Conditions

    private var conditionsComparison: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "УСЛОВИЯ", color: AppTheme.oceanBlue)

            VStack(spacing: 0) {
                comparisonRow(icon: "humidity.fill", label: "Влажность") { data in
                    if let h = data?.current?.humidity { return "\(h)%" }
                    return "—"
                }
                Divider().opacity(0.08).padding(.horizontal, AppTheme.spacingM)
                comparisonRow(icon: "wind", label: "Ветер") { data in
                    if let w = data?.current?.windSpeed { return "\(Int(w)) км/ч" }
                    return "—"
                }
                Divider().opacity(0.08).padding(.horizontal, AppTheme.spacingM)
                comparisonRow(icon: "drop.fill", label: "Осадки") { data in
                    if let p = data?.todayForecast?.precipitationProbability, p > 0 { return "\(p)%" }
                    return "0%"
                }
                Divider().opacity(0.08).padding(.horizontal, AppTheme.spacingM)
                comparisonRow(icon: "sun.max.fill", label: "УФ") { data in
                    if let uv = data?.todayForecast?.uvIndexMax { return "\(Int(uv))" }
                    return "—"
                }
                Divider().opacity(0.08).padding(.horizontal, AppTheme.spacingM)
                comparisonRow(icon: "gauge.medium", label: "Давление") { data in
                    if let p = data?.current?.pressureMb { return "\(Int(p)) мб" }
                    return "—"
                }
                Divider().opacity(0.08).padding(.horizontal, AppTheme.spacingM)
                comparisonRow(icon: "eye.fill", label: "Видимость") { data in
                    if let v = data?.current?.visibilityKm { return "\(Int(v)) км" }
                    return "—"
                }
            }
            .padding(.bottom, AppTheme.spacingS)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Details (AQI)

    private var detailsComparison: some View {
        let hasAQI = cities.contains { cityData[$0.0]?.aqi != nil }

        return Group {
            if hasAQI {
                VStack(alignment: .leading, spacing: 0) {
                    GlassSectionHeader(title: "КАЧЕСТВО ВОЗДУХА", color: .green)

                    HStack(spacing: 0) {
                        ForEach(cities, id: \.0) { city, _ in
                            let aqi = cityData[city]?.aqi
                            VStack(spacing: 6) {
                                Text(city)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                if let aqi {
                                    Image(systemName: aqi.sfSymbol)
                                        .font(.system(size: 22))
                                        .foregroundStyle(aqi.color)

                                    Text(aqi.levelLocalized)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(aqi.color)

                                    Text("PM2.5: \(String(format: "%.0f", aqi.pm25))")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                } else {
                                    Text("—")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.spacingM)

                            if city != cities.last?.0 {
                                Divider().opacity(0.15)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingS)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Helpers

    private func comparisonRow(icon: String, label: String, valueFor: @escaping (WeatherService.WeatherDetailData?) -> String) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 100, alignment: .leading)

            ForEach(cities, id: \.0) { city, _ in
                Text(valueFor(cityData[city]))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, 8)
    }

    private func loadAllCities() async {
        isLoading = true
        await withTaskGroup(of: (String, WeatherService.WeatherDetailData).self) { group in
            for (city, coord) in cities {
                group.addTask {
                    let data = await weather.fetchFullDetail(for: coord)
                    return (city, data)
                }
            }
            for await (city, data) in group {
                cityData[city] = data
            }
        }
        isLoading = false
    }
}
