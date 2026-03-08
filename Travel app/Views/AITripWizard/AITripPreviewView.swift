import SwiftUI
import SwiftData

struct AITripPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State var trip: AIGeneratedTrip
    let budget: Double?
    var onRegenerate: () -> Void

    private var isOverBudget: Bool {
        guard let budget, budget > 0, trip.totalEstimate > 0 else { return false }
        return trip.totalEstimate > budget
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    headerCard
                    budgetWarning
                    daysSection
                    flightsSection
                    hotelsSection

                    Spacer(minLength: 100)
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ЗАКРЫТЬ") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.sakuraPink)

            Text(trip.destination)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)

            HStack(spacing: AppTheme.spacingM) {
                Label("\(trip.totalDays) дн.", systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                if trip.totalEstimate > 0 {
                    Label(formatPrice(trip.totalEstimate), systemImage: "rublesign.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.bambooGreen)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingL)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink.opacity(0.4), AppTheme.sakuraPink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Budget Warning

    @ViewBuilder
    private var budgetWarning: some View {
        if isOverBudget, let budget {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.templeGold)
                Text("Превышает бюджет \(formatPrice(budget)) на \(formatPrice(trip.totalEstimate - budget))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.templeGold)
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.templeGold.opacity(0.1))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        }
    }

    // MARK: - Days Section

    private var daysSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: "МАРШРУТ ПО ДНЯМ", color: AppTheme.sakuraPink)

            ForEach(Array(trip.days.enumerated()), id: \.element.id) { dayIndex, day in
                dayCard(day: day, dayIndex: dayIndex)
            }
        }
    }

    private func dayCard(day: GeneratedDay, dayIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                Text("ДЕНЬ \(day.dayNumber)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.sakuraPink)
                Text(day.city)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(day.places.count) мест")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            ForEach(Array(day.places.enumerated()), id: \.element.id) { placeIndex, place in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: mapCategory(place.category).systemImage)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.sakuraPink)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        if !place.description.isEmpty {
                            Text(place.description)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Text(place.timeToSpend)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            trip.days[dayIndex].places.remove(at: placeIndex)
                        }
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Flights Section

    @ViewBuilder
    private var flightsSection: some View {
        if !trip.flights.isEmpty {
            VStack(spacing: AppTheme.spacingS) {
                GlassSectionHeader(title: "АВИАБИЛЕТЫ", color: AppTheme.oceanBlue)

                ForEach(trip.flights) { flight in
                    flightCard(flight)
                }
            }
        }
    }

    private func flightCard(_ flight: FlightOffer) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(flight.origin)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Text("departure")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "airplane")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.sakuraPink)

            VStack(spacing: 4) {
                Text(flight.destination)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Text("arrival")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatPrice(Double(flight.price)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.bambooGreen)
                if flight.transfers > 0 {
                    Text("\(flight.transfers) пересадка")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("прямой")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.bambooGreen)
                }
            }

            Link(destination: URL(string: flight.deepLink)!) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.sakuraPink)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Hotels Section

    @ViewBuilder
    private var hotelsSection: some View {
        if !trip.hotels.isEmpty {
            VStack(spacing: AppTheme.spacingS) {
                GlassSectionHeader(title: "ОТЕЛИ", color: AppTheme.templeGold)

                ForEach(trip.hotels) { hotel in
                    hotelCard(hotel)
                }
            }
        }
    }

    private func hotelCard(_ hotel: HotelOffer) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(hotel.hotelName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 2) {
                    ForEach(0..<hotel.stars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(AppTheme.templeGold)
                    }
                }
                Text(hotel.locationName)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatPrice(hotel.priceFrom))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.bambooGreen)
                Text("\(formatPrice(hotel.pricePerNight))/ночь")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Link(destination: URL(string: hotel.deepLink)!) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.sakuraPink)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: AppTheme.spacingS) {
            Button {
                dismiss()
                onRegenerate()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14))
                    Text("ЗАНОВО")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(AppTheme.sakuraPink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.sakuraPink.opacity(0.3), lineWidth: 1)
                )
            }

            Button {
                saveTrip()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("СОЗДАТЬ")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.sakuraPink)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .shadow(color: AppTheme.sakuraPink.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
    }

    // MARK: - Save Trip

    private func saveTrip() {
        let newTrip = Trip(
            name: trip.destination,
            country: trip.destination,
            startDate: trip.startDate,
            endDate: trip.endDate,
            budget: trip.totalEstimate > 0 ? trip.totalEstimate : (budget ?? 0),
            currency: "RUB",
            coverSystemImage: "airplane"
        )

        // Convert flights
        let tripFlights = trip.flights.map { offer in
            TripFlight(
                number: "\(offer.airline)\(offer.flightNumber)",
                date: parseFlightDate(offer.departureAt),
                departureIata: offer.origin,
                arrivalIata: offer.destination
            )
        }
        if !tripFlights.isEmpty {
            newTrip.flights = tripFlights
        }

        // Convert days + places
        for genDay in trip.days {
            let dayDate = Calendar.current.date(
                byAdding: .day,
                value: genDay.dayNumber - 1,
                to: trip.startDate
            ) ?? trip.startDate

            let tripDay = TripDay(
                date: dayDate,
                title: "День \(genDay.dayNumber)",
                cityName: genDay.city,
                sortOrder: genDay.dayNumber - 1
            )

            for (index, genPlace) in genDay.places.enumerated() {
                let place = Place(
                    name: genPlace.name,
                    nameLocal: "",
                    category: mapCategory(genPlace.category),
                    address: "",
                    latitude: genPlace.latitude,
                    longitude: genPlace.longitude,
                    notes: genPlace.description,
                    timeToSpend: genPlace.timeToSpend
                )
                place.sortOrder = index
                tripDay.places.append(place)
            }

            newTrip.days.append(tripDay)
        }

        modelContext.insert(newTrip)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helpers

    private func mapCategory(_ category: String) -> PlaceCategory {
        switch category.lowercased() {
        case "restaurant", "cafe": return .food
        case "museum": return .museum
        case "park": return .park
        case "shopping", "market": return .shopping
        case "beach": return .nature
        case "temple": return .temple
        case "viewpoint": return .viewpoint
        case "gallery": return .gallery
        default: return .culture
        }
    }

    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "\(formatted) \u{20BD}"
    }

    private func parseFlightDate(_ dateString: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        if let d = fmt.date(from: String(dateString.prefix(10))) { return d }
        let iso = ISO8601DateFormatter()
        return iso.date(from: dateString + "T00:00:00Z")
    }
}
