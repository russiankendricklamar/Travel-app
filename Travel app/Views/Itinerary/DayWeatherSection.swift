import SwiftUI
import CoreLocation

struct DayWeatherSection: View {
    let day: TripDay

    private var weather: WeatherService { WeatherService.shared }

    @State private var forecast: WeatherInfo?
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
        HStack(spacing: AppTheme.spacingM) {
            Image(systemName: forecast.sfSymbol)
                .font(.system(size: 32))
                .symbolRenderingMode(.multicolor)

            VStack(alignment: .leading, spacing: 2) {
                Text(forecast.conditionRussian)
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

            if let max = forecast.temperatureMax {
                Text("\(Int(max))°")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusLarge)))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusLarge))
                .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
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

        // Resolve coordinate: city name → places → Tokyo fallback
        let coordinate: CLLocationCoordinate2D
        if let resolved = await weather.resolveCoordinate(forCity: day.cityName) {
            coordinate = resolved
        } else if let firstPlace = day.places.first {
            coordinate = firstPlace.coordinate
        } else {
            coordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        }

        await weather.fetchDailyForecast(for: coordinate)
        forecast = weather.forecast(for: day.date, at: coordinate)
        isLoading = false
    }
}
