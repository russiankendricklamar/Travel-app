import SwiftUI
import CoreLocation

struct TravelStatsView: View {
    let trips: [Trip]
    @Environment(\.dismiss) private var dismiss

    enum Period: String, CaseIterable {
        case all = "Всё время"
        case year = "По годам"
        case month = "По месяцам"
    }

    @State private var selectedPeriod: Period = .all
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())

    // MARK: - Filtered trips (past only)

    private var filteredTrips: [Trip] {
        let base = trips.filter(\.isPast)
        switch selectedPeriod {
        case .all:
            return base
        case .year:
            return base.filter {
                Calendar.current.component(.year, from: $0.startDate) == selectedYear
            }
        case .month:
            return base.filter {
                let cal = Calendar.current
                return cal.component(.year, from: $0.startDate) == selectedYear
                    && cal.component(.month, from: $0.startDate) == selectedMonth
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingM) {
                    periodPicker
                    if selectedPeriod != .all { yearPicker }
                    if selectedPeriod == .month { monthPicker }

                    summaryCard
                    geographySection
                    flightsSection
                    transportSection
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)
                .padding(.bottom, 40)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("СТАТИСТИКА")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ГОТОВО") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("", selection: $selectedPeriod) {
            ForEach(Period.allCases, id: \.self) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .tint(AppTheme.sakuraPink)
    }

    private var yearPicker: some View {
        let years = availableYears
        return Picker("Год", selection: $selectedYear) {
            ForEach(years, id: \.self) { y in
                Text(String(y)).tag(y)
            }
        }
        .pickerStyle(.segmented)
        .tint(AppTheme.sakuraPink)
    }

    private var monthPicker: some View {
        let f = DateFormatter()
        f.locale = .current
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(1...12, id: \.self) { m in
                    Button {
                        selectedMonth = m
                    } label: {
                        Text(f.shortMonthSymbols[m - 1].capitalized)
                            .font(.system(size: 11, weight: selectedMonth == m ? .bold : .medium))
                            .foregroundStyle(selectedMonth == m ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedMonth == m ? AppTheme.sakuraPink : Color.clear)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - 1. Summary Card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(value: filteredTrips.count, label: "ПОЕЗДОК", icon: "airplane")
            Divider()
                .frame(height: 40)
                .overlay(Color.white.opacity(0.2))
            summaryItem(value: totalDays, label: "ДНЕЙ В ПУТИ", icon: "calendar")
        }
        .padding(.vertical, AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func summaryItem(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink)
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 2. Geography

    private var geographySection: some View {
        VStack(spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: "ГЕОГРАФИЯ", color: AppTheme.bambooGreen)

            // Combined map: countries + routes
            if !countryCounts.isEmpty || !filteredTrips.isEmpty {
                VisitedCountriesMapView(
                    trips: filteredTrips,
                    visitedCountries: countryCounts.map(\.country)
                )
            }

            // Countries
            if !countryCounts.isEmpty {
                statListCard(title: "Страны (\(countryCounts.count))", icon: "globe", color: AppTheme.bambooGreen) {
                    ForEach(countryCounts, id: \.country) { item in
                        if item.count > 0 {
                            statRow(
                                icon: "globe",
                                color: AppTheme.bambooGreen,
                                text: item.country,
                                count: item.count,
                                suffix: pluralTrips(item.count)
                            )
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.bambooGreen.opacity(0.7))
                                    .frame(width: 20)
                                Text(item.country)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }

        }
    }

    // MARK: - 3. Flights

    private var flightsSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: "ПЕРЕЛЁТЫ", color: AppTheme.oceanBlue)

            // Total distance
            kmCard(
                value: flightKm,
                label: "Километров самолётом",
                icon: "airplane",
                color: AppTheme.oceanBlue
            )

            // Airports
            if !airportCounts.isEmpty {
                statListCard(title: "Аэропорты", icon: "airplane.arrival", color: AppTheme.indigoPurple) {
                    ForEach(airportCounts, id: \.iata) { item in
                        statRow(
                            icon: "airplane.arrival",
                            color: AppTheme.indigoPurple,
                            text: "\(item.iata) — \(item.city)",
                            count: item.count,
                            suffix: pluralTimes(item.count)
                        )
                    }
                }
            }

            // Airlines
            if !airlineCounts.isEmpty {
                statListCard(title: "Авиакомпании", icon: "shield.fill", color: AppTheme.toriiRed) {
                    ForEach(airlineCounts, id: \.code) { item in
                        let displayName = FlightData.airlineNames[item.code]
                        let text = displayName != nil ? "\(item.code) — \(displayName!)" : item.code
                        statRow(
                            icon: "shield.fill",
                            color: AppTheme.toriiRed,
                            text: text,
                            count: item.count,
                            suffix: pluralFlights(item.count)
                        )
                    }
                }
            }

            // Aircraft types
            if !aircraftCounts.isEmpty {
                statListCard(title: "Типы самолётов", icon: "airplane.circle", color: AppTheme.oceanBlue) {
                    ForEach(aircraftCounts, id: \.icao) { item in
                        let displayName = FlightData.aircraftTypeNames[item.icao]
                        let text = displayName != nil ? "\(item.icao) — \(displayName!)" : item.icao
                        statRow(
                            icon: "airplane.circle",
                            color: AppTheme.oceanBlue,
                            text: text,
                            count: item.count,
                            suffix: pluralFlights(item.count)
                        )
                    }
                }
            }
        }
    }

    // MARK: - 4. Ground Transport

    private var transportSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: "НАЗЕМНЫЙ ТРАНСПОРТ", color: AppTheme.templeGold)

            kmCard(
                value: trainKm,
                label: "Поездом",
                icon: "tram.fill",
                color: AppTheme.sakuraPink
            )

            kmCard(
                value: busKm,
                label: "Автобусом",
                icon: "bus.fill",
                color: AppTheme.templeGold
            )
        }
    }

    // MARK: - Reusable Components

    private func statListCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(color)
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, 12)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(color.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func statRow(icon: String, color: Color, text: String, count: Int, suffix: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color.opacity(0.7))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Text("\(count) \(suffix)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func kmCard(value: Double, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            Text(formatFullKm(value))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Text(distanceComparison(value))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(color.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Computed Stats

    private var totalDays: Int {
        filteredTrips.reduce(0) { $0 + max(1, $1.totalDays) }
    }

    private var availableYears: [Int] {
        let years = Set(trips.filter(\.isPast).map { Calendar.current.component(.year, from: $0.startDate) })
        return years.sorted()
    }

    // Countries — trips + profile visitedCountries
    private var countryCounts: [(country: String, count: Int)] {
        var counts: [String: Int] = [:]
        for trip in filteredTrips {
            for c in trip.countries {
                counts[c, default: 0] += 1
            }
        }
        // Add profile visited countries (only in "all time" mode)
        if selectedPeriod == .all {
            let profileCountries = ProfileService.shared.profile?.visitedCountries ?? []
            for c in profileCountries {
                if counts[c] == nil {
                    counts[c] = 0
                }
            }
        }
        return counts.map { (country: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }


    // Airports
    private var airportCounts: [(iata: String, city: String, count: Int)] {
        var counts: [String: Int] = [:]
        for trip in filteredTrips {
            for flight in trip.flights {
                if let dep = flight.departureIata, !dep.isEmpty { counts[dep, default: 0] += 1 }
                if let arr = flight.arrivalIata, !arr.isEmpty { counts[arr, default: 0] += 1 }
            }
        }
        return counts
            .map { (iata: $0.key, city: FlightData.airportCities[$0.key] ?? $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // Airlines
    private var airlineCounts: [(code: String, count: Int)] {
        var counts: [String: Int] = [:]
        for trip in filteredTrips {
            for flight in trip.flights {
                let code: String
                if let ac = flight.airlineCode, !ac.isEmpty {
                    code = ac
                } else {
                    let prefix = String(flight.number.prefix(while: \.isLetter))
                    guard prefix.count >= 2 else { continue }
                    code = prefix
                }
                counts[code, default: 0] += 1
            }
        }
        return counts
            .map { (code: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // Aircraft types
    private var aircraftCounts: [(icao: String, count: Int)] {
        var counts: [String: Int] = [:]
        for trip in filteredTrips {
            for flight in trip.flights {
                guard let type = flight.aircraftType, !type.isEmpty else { continue }
                counts[type, default: 0] += 1
            }
        }
        return counts
            .map { (icao: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Distance Calculations

    private var flightKm: Double {
        var total: Double = 0
        for trip in filteredTrips {
            for flight in trip.flights {
                let depIata = flight.departureIata ?? ""
                let arrIata = flight.arrivalIata ?? ""
                guard let depCoord = FlightData.coordinate(forIata: depIata),
                      let arrCoord = FlightData.coordinate(forIata: arrIata) else { continue }
                total += haversineKm(from: depCoord, to: arrCoord)
            }
        }
        return total
    }

    private var trainKm: Double {
        transportKm(for: .train) + transportKm(for: .shinkansen)
    }

    private var busKm: Double {
        transportKm(for: .bus)
    }

    private func transportKm(for category: EventCategory) -> Double {
        var total: Double = 0
        for trip in filteredTrips {
            for day in trip.days {
                for event in day.events where event.category == category {
                    guard let startCoord = event.primaryCoordinate,
                          let endCoord = event.arrivalCoordinate else { continue }
                    total += haversineKm(from: startCoord, to: endCoord)
                }
            }
        }
        return total
    }

    private func haversineKm(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R = 6371.0
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(from.latitude * .pi / 180) * cos(to.latitude * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    // MARK: - Formatting

    private func formatFullKm(_ km: Double) -> String {
        if km < 1 { return "0 км" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: Int(km))) ?? "0") + " км"
    }

    private func distanceComparison(_ km: Double) -> String {
        let equatorKm = 40_075.0
        let voyagerKm = 24_800_000_000.0

        if km < 1 {
            return "≈ 0 экватора · 0 Вояджера-1"
        }

        let equators = km / equatorKm
        let eqStr: String
        if equators >= 1 {
            eqStr = String(format: "%.1f экватора", equators)
        } else {
            eqStr = String(format: "%.2f экватора", equators)
        }

        let voyagerRatio = Int(voyagerKm / km)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        let voyagerStr = formatter.string(from: NSNumber(value: voyagerRatio)) ?? "\(voyagerRatio)"

        return "≈ \(eqStr) · 1 / \(voyagerStr) Вояджера-1"
    }

    // MARK: - Plurals

    private func pluralTrips(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "поездок" }
        switch mod10 {
        case 1: return "поездка"
        case 2, 3, 4: return "поездки"
        default: return "поездок"
        }
    }

    private func pluralTimes(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "раз" }
        if mod10 == 1 { return "раз" }
        return "раз"
    }

    private func pluralFlights(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "рейсов" }
        switch mod10 {
        case 1: return "рейс"
        case 2, 3, 4: return "рейса"
        default: return "рейсов"
        }
    }
}
