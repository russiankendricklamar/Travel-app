import SwiftUI

struct DayDetailView: View {
    let store: TripStore
    let day: TripDay

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingM) {
                headerSection
                if !day.events.isEmpty {
                    eventsSection
                }
                placesSection
                notesSection
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
        .background(AppTheme.background)
        .navigationTitle(day.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateFormatter.string(from: day.date).uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(day.cityName.uppercased())
                        .font(.system(size: 22, weight: .black))
                        .tracking(3)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(day.visitedCount)/\(day.places.count)")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("ПОСЕЩЕНО")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.oceanBlue)

            // Progress bar under header
            GeometryReader { geo in
                let progress = day.places.isEmpty ? 0.0 : Double(day.visitedCount) / Double(day.places.count)
                ZStack(alignment: .leading) {
                    Rectangle().fill(AppTheme.surface)
                    Rectangle()
                        .fill(progress >= 1.0 ? AppTheme.bambooGreen : AppTheme.sakuraPink)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
    }

    // MARK: - Events

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            BoldSectionHeader(title: "РАСПИСАНИЕ", color: AppTheme.card)
                .overlay(
                    Rectangle()
                        .fill(AppTheme.oceanBlue)
                        .frame(width: 4),
                    alignment: .leading
                )
                .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1))

            ForEach(day.events.sorted(by: { $0.startTime < $1.startTime })) { event in
                EventCard(event: event)
            }
        }
    }

    // MARK: - Places

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            BoldSectionHeader(title: "МЕСТА", color: AppTheme.card)
                .overlay(
                    Rectangle()
                        .fill(AppTheme.sakuraPink)
                        .frame(width: 4),
                    alignment: .leading
                )
                .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1))

            ForEach(Array(day.places.enumerated()), id: \.element.id) { index, place in
                placeRow(place, index: index)
            }
        }
    }

    private func placeRow(_ place: Place, index: Int) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(place.isVisited
                    ? AppTheme.bambooGreen
                    : AppTheme.categoryColor(for: place.category.rawValue))
                .frame(width: 4)

            Text(String(format: "%02d", index + 1))
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(place.isVisited
                    ? AppTheme.bambooGreen.opacity(0.3)
                    : AppTheme.textMuted.opacity(0.3))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                HStack(alignment: .top) {
                    Button {
                        store.togglePlaceVisited(dayId: day.id, placeId: place.id)
                    } label: {
                        Image(systemName: place.isVisited ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(place.isVisited ? AppTheme.bambooGreen : AppTheme.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .strikethrough(place.isVisited, color: AppTheme.bambooGreen.opacity(0.5))

                        Text(place.nameJapanese)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)

                        HStack(spacing: AppTheme.spacingS) {
                            CategoryBadge(category: place.category)

                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10, weight: .bold))
                                Text(place.timeToSpend)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(AppTheme.textMuted)
                        }

                        if let rating = place.rating {
                            StarRatingView(rating: rating) { newRating in
                                store.ratePlace(dayId: day.id, placeId: place.id, rating: newRating)
                            }
                        } else if place.isVisited {
                            StarRatingView(rating: 0) { newRating in
                                store.ratePlace(dayId: day.id, placeId: place.id, rating: newRating)
                            }
                        }

                        if !place.notes.isEmpty {
                            Text(place.notes)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.top, 2)
                        }
                    }

                    Spacer()
                }

                if !place.address.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                        Text(place.address)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.leading, 34)
                }
            }
            .padding(AppTheme.spacingM)
        }
        .background(index % 2 == 0 ? AppTheme.card : AppTheme.surface)
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1))
    }

    // MARK: - Notes

    private var notesSection: some View {
        Group {
            if !day.notes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    BoldSectionHeader(title: "ЗАМЕТКИ", color: AppTheme.templeGold.opacity(0.9))

                    Text(day.notes)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(4)
                        .padding(AppTheme.spacingM)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.card)
                }
                .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
            }
        }
    }
}

#Preview {
    NavigationStack {
        DayDetailView(store: TripStore(), day: TripStore().days[0])
    }
}
