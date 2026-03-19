import SwiftUI
import SwiftData

struct FlightsListView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showAddFlight = false

    private var futureFlights: [TripFlight] {
        let now = Date()
        return trip.flights.filter { ($0.date ?? .distantFuture) > now }
    }

    private var pastFlights: [TripFlight] {
        let now = Date()
        return trip.flights.filter {
            guard let date = $0.date else { return false }
            return date <= now
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingM) {
                SheetHeader(
                    icon: "airplane",
                    title: "РЕЙСЫ",
                    color: AppTheme.oceanBlue
                )

                if trip.flights.isEmpty {
                    emptyState
                } else {
                    if !futureFlights.isEmpty {
                        sectionHeader("ПРЕДСТОЯЩИЕ", count: futureFlights.count)
                        ForEach(futureFlights) { flight in
                            flightCard(flight, isPast: false)
                        }
                    }

                    if !pastFlights.isEmpty {
                        sectionHeader("ЗАВЕРШЁННЫЕ", count: pastFlights.count)
                        ForEach(pastFlights) { flight in
                            flightCard(flight, isPast: true)
                        }
                    }
                }
            }
            .padding(AppTheme.spacingM)
        }
        .sakuraGradientBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Text("ЗАКРЫТЬ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddFlight = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.oceanBlue)
                }
            }
        }
        .sheet(isPresented: $showAddFlight) {
            EditFlightSheet(trip: trip)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: LocalizedStringKey, count: Int) -> some View {
        HStack {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.oceanBlue)
                    .frame(width: 4, height: 16)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.oceanBlue)
            }
            Spacer()
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.oceanBlue.opacity(0.4))
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    // MARK: - Flight Card

    private func flightCard(_ flight: TripFlight, isPast: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isPast ? "airplane.arrival" : "airplane.departure")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isPast ? .secondary : AppTheme.oceanBlue)
                .frame(width: 36, height: 36)
                .background((isPast ? Color.secondary : AppTheme.oceanBlue).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(flight.number.uppercased())
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(isPast ? .secondary : .primary)

                if let date = flight.date {
                    Text(flightDateFormatted(date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                if let dep = flight.departureIata, let arr = flight.arrivalIata {
                    Text("\(dep) → \(arr)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isPast ? Color.secondary : AppTheme.oceanBlue.opacity(0.7))
                }
            }

            Spacer()

            if isPast {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.bambooGreen.opacity(0.5))
            }

            Button(role: .destructive) {
                deleteFlight(flight)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.toriiRed.opacity(0.6))
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke((isPast ? Color.secondary : AppTheme.oceanBlue).opacity(0.15), lineWidth: 0.5)
        )
        .opacity(isPast ? 0.7 : 1.0)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingM) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppTheme.oceanBlue.opacity(0.3))
            Text("Нет добавленных рейсов")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Button {
                showAddFlight = true
            } label: {
                Text("ДОБАВИТЬ РЕЙС")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.oceanBlue)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingXL)
    }

    // MARK: - Helpers

    private func deleteFlight(_ flight: TripFlight) {
        var updated = trip.flights.filter { $0.id != flight.id }
        trip.flights = updated
        try? modelContext.save()
    }

    private func flightDateFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM yyyy, HH:mm"
        return f.string(from: date)
    }
}
