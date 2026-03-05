import SwiftUI

// MARK: - 7-Day Forecast Strip

struct WeatherForecastStrip: View {
    let forecasts: [WeatherInfo]

    private static let dayAbbreviations: [String] = [String(localized: "Вс"), String(localized: "Пн"), String(localized: "Вт"), String(localized: "Ср"), String(localized: "Чт"), String(localized: "Пт"), String(localized: "Сб")]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(forecasts) { info in
                    dayColumn(info)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func dayColumn(_ info: WeatherInfo) -> some View {
        VStack(spacing: 4) {
            if let date = info.date {
                Text(Self.dayAbbreviations[Calendar.current.component(.weekday, from: date) - 1])
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: info.sfSymbol)
                .font(.system(size: 16))
                .symbolRenderingMode(.multicolor)

            if let max = info.temperatureMax {
                Text("\(Int(max))°")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
            }
            if let min = info.temperatureMin {
                Text("\(Int(min))°")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 40)
    }
}

// MARK: - Recommendations Row

struct WeatherRecommendationsRow: View {
    let recommendations: [WeatherRecommendation]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(recommendations, id: \.labelLocalized) { rec in
                    HStack(spacing: 4) {
                        Image(systemName: rec.icon)
                            .font(.system(size: 11))
                        Text(rec.labelLocalized)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(rec.capsuleColor.opacity(0.15))
                    .foregroundStyle(rec.capsuleColor)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - City Weather Card

struct CityWeatherCard: View {
    let cityName: String
    let weather: WeatherInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cityName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: weather.sfSymbol)
                    .font(.system(size: 18))
                    .symbolRenderingMode(.multicolor)

                VStack(alignment: .leading, spacing: 1) {
                    if let max = weather.temperatureMax, let min = weather.temperatureMin {
                        Text("\(Int(max))°/\(Int(min))°")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Text(weather.conditionLocalized)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusMedium)))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusMedium))
                .stroke(AppTheme.oceanBlue.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Hourly Forecast Strip (for DayWeatherSection)

struct HourlyForecastStrip: View {
    let items: [HourlyWeatherInfo]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    hourColumn(item)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func hourColumn(_ item: HourlyWeatherInfo) -> some View {
        VStack(spacing: 3) {
            Text(item.hourLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Image(systemName: item.sfSymbol)
                .font(.system(size: 14))
                .symbolRenderingMode(.multicolor)

            Text("\(Int(item.temperature))°")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)

            if let precip = item.precipitationProbability, precip > 0 {
                Text("\(precip)%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppTheme.oceanBlue)
            }
        }
        .frame(width: 44)
    }
}
