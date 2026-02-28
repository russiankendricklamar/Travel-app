import SwiftUI

struct ItineraryView: View {
    let store: TripStore

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEE, d MMM"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppTheme.spacingM) {
                    ForEach(Array(store.sortedDays.enumerated()), id: \.element.id) { index, day in
                        NavigationLink(value: day.id) {
                            dayCard(day, index: index)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingXL)
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 12, height: 3)
                        Text("МАРШРУТ")
                            .font(.system(size: 14, weight: .black))
                            .tracking(4)
                            .foregroundStyle(AppTheme.textPrimary)
                        Rectangle()
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 12, height: 3)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { dayId in
                if let day = store.days.first(where: { $0.id == dayId }) {
                    DayDetailView(store: store, day: day)
                }
            }
        }
    }

    private func dayCard(_ day: TripDay, index: Int) -> some View {
        let isToday = day.isToday
        let isPast = day.isPast

        return HStack(spacing: 0) {
            // Bold day number column
            VStack(spacing: 2) {
                if isToday {
                    Text("СЕЙЧАС")
                        .font(.system(size: 8, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.white)
                } else {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(isToday ? .white : (isPast ? AppTheme.textMuted : AppTheme.sakuraPink))
                }
                if !isToday {
                    Text("ДЕНЬ")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(isToday ? .white.opacity(0.8) : AppTheme.textMuted)
                }
            }
            .frame(width: 56)
            .frame(maxHeight: .infinity)
            .background(isToday ? AppTheme.sakuraPink : AppTheme.sakuraPink.opacity(isPast ? 0.03 : 0.06))

            // Accent bar
            Rectangle()
                .fill(dayAccentColor(day))
                .frame(width: 4)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(dateFormatter.string(from: day.date).uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(AppTheme.textMuted)

                            if isToday {
                                Text("СЕГОДНЯ")
                                    .font(.system(size: 8, weight: .black))
                                    .tracking(1)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(.white)
                                    .background(AppTheme.sakuraPink)
                            }

                            if isPast {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.bambooGreen)
                            }
                        }

                        Text(day.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isPast ? AppTheme.textSecondary : AppTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(day.cityName.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .tracking(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(AppTheme.oceanBlue.opacity(isPast ? 0.5 : 1))

                        Text("\(day.visitedCount)/\(day.places.count)")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(day.visitedCount == day.places.count && !day.places.isEmpty
                                ? AppTheme.bambooGreen
                                : AppTheme.textSecondary)
                    }
                }

                // Place icons
                if !day.places.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(day.places.prefix(5)) { place in
                            Image(systemName: place.category.systemImage)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(
                                    place.isVisited
                                        ? AppTheme.bambooGreen
                                        : AppTheme.categoryColor(for: place.category.rawValue)
                                )
                                .frame(width: 22, height: 22)
                                .background(
                                    (place.isVisited
                                        ? AppTheme.bambooGreen
                                        : AppTheme.categoryColor(for: place.category.rawValue)
                                    ).opacity(0.1)
                                )
                        }
                        if day.places.count > 5 {
                            Text("+\(day.places.count - 5)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        Spacer()
                    }
                }

                if !day.notes.isEmpty {
                    Text(day.notes)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(1)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AppTheme.surface)
                            .frame(height: 5)

                        let progress = day.places.isEmpty ? 0.0 : Double(day.visitedCount) / Double(day.places.count)
                        Rectangle()
                            .fill(dayAccentColor(day))
                            .frame(width: geometry.size.width * progress, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .padding(AppTheme.spacingM)
        }
        .background(AppTheme.card)
        .overlay(
            Rectangle().stroke(
                isToday ? AppTheme.sakuraPink : AppTheme.border,
                lineWidth: isToday ? 3 : 2
            )
        )
    }

    private func dayAccentColor(_ day: TripDay) -> Color {
        if day.isToday { return AppTheme.sakuraPink }
        guard !day.places.isEmpty else { return AppTheme.textMuted }
        let progress = Double(day.visitedCount) / Double(day.places.count)
        if progress >= 1.0 { return AppTheme.bambooGreen }
        if progress > 0 { return AppTheme.sakuraPink }
        return AppTheme.textMuted
    }
}

#Preview {
    ItineraryView(store: TripStore())
}
