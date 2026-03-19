import SwiftUI
import Charts

struct TemperatureTrendChart: View {
    let hourlyData: [HourlyWeatherInfo]

    private var chartData: [HourlyWeatherInfo] {
        // Show all available hourly data (up to 3 days from API)
        hourlyData
    }

    private var minTemp: Double {
        (chartData.map(\.temperature).min() ?? 0) - 2
    }

    private var maxTemp: Double {
        (chartData.map(\.temperature).max() ?? 30) + 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "ТРЕНД ТЕМПЕРАТУРЫ", color: AppTheme.templeGold)

            if chartData.isEmpty {
                Text("Нет данных")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.spacingM)
            } else {
                Chart(chartData) { item in
                    LineMark(
                        x: .value("Час", item.hour),
                        y: .value("°C", item.temperature)
                    )
                    .foregroundStyle(AppTheme.templeGold)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Час", item.hour),
                        yStart: .value("Min", minTemp),
                        yEnd: .value("°C", item.temperature)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.templeGold.opacity(0.3), AppTheme.templeGold.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    if let feels = item.apparentTemperature {
                        LineMark(
                            x: .value("Час", item.hour),
                            y: .value("Ощущается", feels)
                        )
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: minTemp...maxTemp)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatHour(date))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(.secondary.opacity(0.3))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let temp = value.as(Double.self) {
                                Text("\(Int(temp))°")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(.secondary.opacity(0.3))
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingS)

                // Legend
                HStack(spacing: AppTheme.spacingM) {
                    legendItem(color: AppTheme.templeGold, label: "Температура", dashed: false)
                    legendItem(color: AppTheme.sakuraPink.opacity(0.5), label: "Ощущается", dashed: true)
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingM)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            if dashed {
                Rectangle()
                    .fill(color)
                    .frame(width: 12, height: 2)
                    .overlay(
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 4, height: 2)
                    )
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
