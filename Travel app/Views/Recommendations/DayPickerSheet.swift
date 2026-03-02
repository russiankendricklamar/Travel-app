import SwiftUI
import SwiftData

struct DayPickerSheet: View {
    let trip: Trip
    let recommendation: PlaceRecommendation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: recommendation.categoryIcon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.sakuraPink)
                        Text(recommendation.name)
                            .font(.system(size: 16, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text("Выберите день")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, AppTheme.spacingM)

                    // Days list
                    ForEach(trip.sortedDays) { day in
                        Button {
                            addToDay(day)
                        } label: {
                            dayRow(day)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationTitle("Добавить в маршрут")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private func dayRow(_ day: TripDay) -> some View {
        HStack(spacing: 12) {
            // Date circle
            VStack(spacing: 2) {
                Text(dayNumber(day))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(monthAbbrev(day))
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(day.isToday ? .white : .primary)
            .frame(width: 44, height: 44)
            .background(
                day.isToday
                    ? AnyShapeStyle(AppTheme.sakuraPink)
                    : AnyShapeStyle(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(day.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(day.cityName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(day.places.count) мест")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }

    private func addToDay(_ day: TripDay) {
        let place = Place(
            name: recommendation.name,
            nameLocal: "",
            category: recommendation.placeCategory,
            address: "",
            latitude: recommendation.latitude,
            longitude: recommendation.longitude,
            notes: recommendation.description,
            timeToSpend: recommendation.estimatedTime
        )
        day.places.append(place)
        try? modelContext.save()
        dismiss()
    }

    private func dayNumber(_ day: TripDay) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: day.date)
    }

    private func monthAbbrev(_ day: TripDay) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "MMM"
        return f.string(from: day.date)
    }
}
