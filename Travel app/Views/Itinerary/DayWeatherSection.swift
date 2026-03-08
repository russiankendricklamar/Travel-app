import SwiftUI
import CoreLocation

struct DayWeatherSection: View {
    let day: TripDay

    private var weather: WeatherService { WeatherService.shared }

    @State private var forecast: WeatherInfo?
    @State private var hourlyItems: [HourlyWeatherInfo] = []
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var isLoading = false
    @State private var appeared = false

    var body: some View {
        if let forecast {
            forecastCard(forecast)
        } else if isLoading {
            loadingView
        } else {
            Color.clear
                .frame(height: 0)
                .task {
                    guard !appeared else { return }
                    appeared = true
                    await loadWeather()
                }
        }
    }

    // MARK: - Forecast Card

    private func forecastCard(_ forecast: WeatherInfo) -> some View {
        VStack(spacing: 0) {
            // Row 1: Main weather info + UV badge
            HStack(spacing: AppTheme.spacingM) {
                Image(systemName: forecast.sfSymbol)
                    .font(.system(size: 32))
                    .symbolRenderingMode(.multicolor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(forecast.conditionLocalized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: AppTheme.spacingS) {
                        if let max = forecast.temperatureMax, let min = forecast.temperatureMin {
                            Text("\(Int(min))...\(Int(max))°")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        if let precip = forecast.precipitationProbability, precip > 0 {
                            Label("\(precip)%", systemImage: "drop.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.oceanBlue)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let max = forecast.temperatureMax {
                        Text("\(Int(max))°")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    if let uv = forecast.uvIndexMax {
                        let level = UVIndexLevel(uvIndex: uv)
                        Text("УФ \(Int(uv))")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(level.color.opacity(0.2))
                            .foregroundStyle(level.color)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(AppTheme.spacingM)

            // Row 2: Sunrise/Sunset pills
            if forecast.sunrise != nil || forecast.sunset != nil {
                Divider().opacity(0.1).padding(.horizontal, AppTheme.spacingM)
                sunriseSunsetRow(sunrise: forecast.sunrise, sunset: forecast.sunset)
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.vertical, 6)
            }

            // Row 3: Hourly strip
            if !hourlyItems.isEmpty {
                Divider().opacity(0.1).padding(.horizontal, AppTheme.spacingM)
                HourlyForecastStrip(items: hourlyItems)
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.vertical, 8)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusLarge)))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusLarge))
                .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    // MARK: - Sunrise/Sunset Row

    private func sunriseSunsetRow(sunrise: Date?, sunset: Date?) -> some View {
        let timeFormatter: DateFormatter = {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            return fmt
        }()

        return HStack(spacing: 12) {
            if let rise = sunrise {
                HStack(spacing: 4) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(timeFormatter.string(from: rise))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }
            if let set = sunset {
                HStack(spacing: 4) {
                    Image(systemName: "sunset.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.sakuraPink)
                    Text(timeFormatter.string(from: set))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.sakuraPink.opacity(0.1))
                .clipShape(Capsule())
            }
            Spacer()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: AppTheme.spacingS) {
            ProgressView().scaleEffect(0.7)
            Text("Загрузка погоды...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingS)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusMedium)))
    }

    // MARK: - Load

    private func loadWeather() async {
        isLoading = true

        let resolved: CLLocationCoordinate2D
        if let coord = await weather.resolveCoordinate(forCity: day.cityName) {
            resolved = coord
        } else if let firstPlace = day.places.first {
            resolved = firstPlace.coordinate
        } else {
            isLoading = false
            return
        }

        coordinate = resolved
        await weather.fetchDailyForecast(for: resolved)
        forecast = weather.forecast(for: day.date, at: resolved)
        hourlyItems = weather.hourlyForecast(for: day.date, at: resolved)
        isLoading = false
    }
}
