import SwiftUI
import SwiftData

struct TripsListView: View {
    @Query(sort: \Trip.startDate) var trips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // @AppStorage("appMode") private var appMode: String = AppMode.personal.rawValue

    var onSelectTrip: ((Trip) -> Void)?

    private var filteredTrips: [Trip] {
        trips
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingM) {
                    if filteredTrips.isEmpty {
                        emptyState
                    } else {
                        if !activeTrips.isEmpty {
                            tripSection(title: "АКТИВНЫЕ", trips: activeTrips, color: AppTheme.bambooGreen)
                        }
                        if !upcomingTrips.isEmpty {
                            tripSection(title: "ПРЕДСТОЯЩИЕ", trips: upcomingTrips, color: AppTheme.oceanBlue)
                        }
                        if !pastTrips.isEmpty {
                            tripSection(title: "ПРОШЕДШИЕ", trips: pastTrips, color: AppTheme.textSecondary)
                        }
                    }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ПОЕЗДКИ")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
        }
        .sakuraGradientBackground()
    }

    // MARK: - Sections

    private func tripSection(title: String, trips: [Trip], color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: title, color: color)

            ForEach(trips) { trip in
                Button {
                    dismiss()
                    onSelectTrip?(trip)
                } label: {
                    TripCardView(trip: trip)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        deleteTrip(trip)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingM) {
            Spacer(minLength: 80)

            Image(systemName: "airplane.circle")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.4))

            Text("НЕТ ПОЕЗДОК")
                .font(.system(size: 14, weight: .bold))
                .tracking(3)
                .foregroundStyle(.secondary)

            Text("Создайте поездку на главном экране")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 80)
        }
    }

    // MARK: - Filters

    private var activeTrips: [Trip] {
        filteredTrips.filter(\.isActive)
    }

    private var upcomingTrips: [Trip] {
        filteredTrips.filter(\.isUpcoming)
    }

    private var pastTrips: [Trip] {
        filteredTrips.filter(\.isPast)
    }

    // MARK: - Actions

    private func deleteTrip(_ trip: Trip) {
        modelContext.delete(trip)
        try? modelContext.save()
    }
}
