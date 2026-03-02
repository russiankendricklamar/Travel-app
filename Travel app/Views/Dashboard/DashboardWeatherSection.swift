import SwiftUI
import CoreLocation

struct DashboardWeatherSection: View {
    let trip: Trip

    private var weather: WeatherService { WeatherService.shared }
    private var location: LocationManager { LocationManager.shared }

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.15).padding(.horizontal, AppTheme.spacingM)

            if let error = weather.errorMessage {
                errorView(error)
            } else if let current = weather.currentWeather {
                currentWeatherView(current)
            } else if weather.isLoading {
                loadingView
            } else {
                loadingView
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusLarge)))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusLarge))
                .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        .task {
            guard !appeared else { return }
            appeared = true
            await loadWeather()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.oceanBlue)
                Text("ПОГОДА")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(AppTheme.oceanBlue)
            }
            Spacer()
            if weather.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(AppTheme.spacingM)
    }

    // MARK: - Current Weather

    private func currentWeatherView(_ current: WeatherInfo) -> some View {
        VStack(spacing: AppTheme.spacingS) {
            HStack(alignment: .center, spacing: AppTheme.spacingM) {
                Image(systemName: current.sfSymbol)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.multicolor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(current.temperature))°")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(current.conditionRussian)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            todayForecastRow

            detailsRow(current)
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingS)
    }

    // MARK: - Today Min/Max

    private var todayForecastRow: some View {
        Group {
            if let today = weather.forecast(for: Date()),
               let max = today.temperatureMax,
               let min = today.temperatureMin {
                HStack(spacing: AppTheme.spacingM) {
                    Label("\(Int(min))°", systemImage: "arrow.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Label("\(Int(max))°", systemImage: "arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let precip = today.precipitationProbability, precip > 0 {
                        Label("\(precip)%", systemImage: "drop.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.oceanBlue)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Details Row

    private func detailsRow(_ current: WeatherInfo) -> some View {
        HStack(spacing: 0) {
            if let humidity = current.humidity {
                detailItem(icon: "humidity.fill", value: "\(humidity)%")
            }
            if let wind = current.windSpeed {
                detailItem(icon: "wind", value: "\(Int(wind)) м/с")
            }
        }
    }

    private func detailItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppTheme.spacingS) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button {
                Task {
                    weather.invalidateCache()
                    await loadWeather()
                }
            } label: {
                Text("Повторить")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.oceanBlue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingM)
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: AppTheme.spacingS) {
            ProgressView()
            Text("Загрузка погоды...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingM)
    }

    // MARK: - Load Weather

    private var weatherCityName: String? {
        if let activeDay = trip.activeDay {
            return activeDay.cityName
        }
        return trip.sortedDays.first?.cityName
    }

    private func loadWeather() async {
        let coordinate: CLLocationCoordinate2D

        if trip.isActive, let current = location.currentLocation {
            coordinate = current
        } else if let city = weatherCityName,
                  let resolved = await weather.resolveCoordinate(forCity: city) {
            coordinate = resolved
        } else if let firstPlace = trip.sortedDays.first?.places.first {
            coordinate = firstPlace.coordinate
        } else {
            return
        }

        await weather.fetchWeather(for: coordinate)
    }
}
