import SwiftUI
import SwiftData
import MapKit

struct JournalMemoryBookView: View {
    let trip: Trip

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()

    private var daysWithEntries: [TripDay] {
        trip.sortedDays.filter { !$0.journalEntries.isEmpty }
    }

    private var daysWithRoutes: [TripDay] {
        trip.sortedDays.filter { !$0.routePoints.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                // Title
                VStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AppTheme.indigoPurple)
                    Text(trip.name.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.primary)
                    Text(tripDateRange)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, AppTheme.spacingL)

                // Days
                ForEach(daysWithEntries) { day in
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        // Day header
                        HStack {
                            Text(dateFormatter.string(from: day.date).uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(day.cityName)
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundStyle(.white)
                                .background(AppTheme.oceanBlue)
                                .clipShape(Capsule())
                        }

                        ForEach(day.journalEntries.sorted(by: { $0.timestamp < $1.timestamp })) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(entry.journalMood.emoji)
                                        .font(.system(size: 20))
                                    if let place = entry.place {
                                        Text(place.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AppTheme.oceanBlue)
                                    }
                                    Spacer()
                                }

                                Text(entry.text)
                                    .font(.system(size: 14))
                                    .lineSpacing(4)

                                // Photos
                                if !entry.photos.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(entry.photos) { photo in
                                                if let uiImage = UIImage(data: photo.imageData) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 120, height: 120)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(AppTheme.spacingM)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                        }
                    }
                }

                // Route map
                if !daysWithRoutes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        GlassSectionHeader(title: "МАРШРУТ", color: AppTheme.bambooGreen)
                        Map {
                            ForEach(daysWithRoutes) { day in
                                let coords = day.routePoints
                                    .sorted { $0.timestamp < $1.timestamp }
                                    .map(\.coordinate)
                                if coords.count >= 2 {
                                    MapPolyline(coordinates: coords)
                                        .stroke(AppTheme.sakuraPink, lineWidth: 3)
                                }
                            }
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    }
                }

                // Stats
                HStack(spacing: 0) {
                    statItem("\(trip.allJournalEntries.count)", label: "ЗАПИСЕЙ")
                    Divider().frame(height: 40)
                    statItem("\(trip.placesVisitedCount)", label: "МЕСТ")
                    Divider().frame(height: 40)
                    statItem("\(Set(trip.days.map(\.cityName)).count)", label: "ГОРОДОВ")
                }
                .padding(.vertical, AppTheme.spacingM)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))

                Spacer(minLength: 40)
            }
            .padding(.horizontal, AppTheme.spacingM)
        }
        .sakuraGradientBackground()
        .navigationTitle("Книга воспоминаний")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statItem(_ value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.indigoPurple)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var tripDateRange: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return "\(f.string(from: trip.startDate)) – \(f.string(from: trip.endDate))"
    }
}
