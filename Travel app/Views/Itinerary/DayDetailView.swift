import SwiftUI
import SwiftData
import CoreLocation

struct DayDetailView: View {
    let trip: Trip
    let day: TripDay
    @Environment(\.modelContext) private var modelContext

    @State private var showingEditDay = false
    @State private var showingAddPlace = false
    @State private var showingAddEvent = false
    @State private var editingPlace: Place?
    @State private var editingEvent: TripEvent?

    private var locationManager: LocationManager { LocationManager.shared }

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
                gpsTrackingSection
                if !day.events.isEmpty {
                    eventsSection
                }
                placesSection
                notesSection
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
        .sakuraGradientBackground()
        .navigationTitle(day.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditDay = true
                    } label: {
                        Label("Редактировать день", systemImage: "pencil")
                    }
                    Button {
                        showingAddPlace = true
                    } label: {
                        Label("Добавить место", systemImage: "mappin.circle")
                    }
                    Button {
                        showingAddEvent = true
                    } label: {
                        Label("Добавить событие", systemImage: "calendar.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
        }
        .sheet(isPresented: $showingEditDay) {
            EditDaySheet(day: day)
        }
        .sheet(isPresented: $showingAddPlace) {
            AddPlaceSheet(day: day)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventSheet(day: day)
        }
        .sheet(item: $editingPlace) { place in
            AddPlaceSheet(day: day, editing: place)
        }
        .sheet(item: $editingEvent) { event in
            AddEventSheet(day: day, editing: event)
        }
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
                        .font(.system(size: 22, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(day.visitedCount)/\(day.places.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("ПОСЕЩЕНО")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(AppTheme.spacingM)
            .background(
                LinearGradient(
                    colors: [AppTheme.oceanBlue, AppTheme.oceanBlue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Progress bar
            GeometryReader { geo in
                let progress = day.places.isEmpty ? 0.0 : Double(day.visitedCount) / Double(day.places.count)
                ZStack(alignment: .leading) {
                    Rectangle().fill(.thinMaterial)
                    Rectangle()
                        .fill(progress >= 1.0 ? AppTheme.bambooGreen : AppTheme.sakuraPink)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .shadow(color: AppTheme.oceanBlue.opacity(0.2), radius: 12, x: 0, y: 6)
    }

    // MARK: - Events

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: "РАСПИСАНИЕ", color: AppTheme.oceanBlue)

            ForEach(day.events.sorted(by: { $0.startTime < $1.startTime })) { event in
                EventCard(event: event)
                    .contextMenu {
                        Button {
                            editingEvent = event
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            modelContext.delete(event)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: - Places

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: "МЕСТА", color: AppTheme.sakuraPink)

            ForEach(Array(day.places.enumerated()), id: \.element.id) { index, place in
                placeRow(place, index: index)
                    .contextMenu {
                        Button {
                            editingPlace = place
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            modelContext.delete(place)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func placeRow(_ place: Place, index: Int) -> some View {
        let accentColor = place.isVisited
            ? AppTheme.bambooGreen
            : AppTheme.categoryColor(for: place.category.rawValue)

        return HStack(spacing: AppTheme.spacingS) {
            // Index
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(place.isVisited ? AppTheme.bambooGreen.opacity(0.3) : Color.secondary.opacity(0.5))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                HStack(alignment: .top) {
                    Button {
                        place.isVisited.toggle()
                    } label: {
                        Image(systemName: place.isVisited ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(place.isVisited ? AppTheme.bambooGreen : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                            .strikethrough(place.isVisited, color: AppTheme.bambooGreen.opacity(0.5))

                        Text(place.nameJapanese)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)

                        HStack(spacing: AppTheme.spacingS) {
                            CategoryBadge(category: place.category)

                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10, weight: .bold))
                                Text(place.timeToSpend)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(.tertiary)
                        }

                        if let rating = place.rating {
                            StarRatingView(rating: rating) { newRating in
                                place.rating = newRating
                            }
                        } else if place.isVisited {
                            StarRatingView(rating: 0) { newRating in
                                place.rating = newRating
                            }
                        }

                        if !place.notes.isEmpty {
                            Text(place.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 34)
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(accentColor.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    // MARK: - GPS Tracking

    private var gpsTrackingSection: some View {
        let isActiveForDay = locationManager.isTracking && locationManager.activeDay?.id == day.id
        let trackingColor = isActiveForDay ? AppTheme.toriiRed : AppTheme.bambooGreen

        return HStack(spacing: AppTheme.spacingS) {
            Image(systemName: isActiveForDay ? "location.fill" : "location")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(trackingColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("GPS-ТРЕКИНГ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.primary)

                if isActiveForDay {
                    Text("\(day.routePoints.count) ТОЧЕК ЗАПИСАНО")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(AppTheme.toriiRed)
                } else if !day.routePoints.isEmpty {
                    Text("\(day.routePoints.count) ТОЧЕК")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("ЗАПИШИТЕ МАРШРУТ ДНЯ")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                toggleTracking()
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isActiveForDay ? AppTheme.toriiRed : AppTheme.bambooGreen)
                        .frame(width: 8, height: 8)
                    Text(isActiveForDay ? "СТОП" : "СТАРТ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(isActiveForDay ? AppTheme.toriiRed : AppTheme.bambooGreen)
                .clipShape(Capsule())
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(trackingColor.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func toggleTracking() {
        if locationManager.isTracking && locationManager.activeDay?.id == day.id {
            locationManager.stopTracking()
        } else {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            }
            locationManager.startTracking(for: day, context: modelContext)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        Group {
            if !day.notes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    GlassSectionHeader(title: "ЗАМЕТКИ", color: AppTheme.templeGold)

                    Text(day.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .padding(AppTheme.spacingM)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
            }
        }
    }
}

// MARK: - Edit Day Sheet

struct EditDaySheet: View {
    let day: TripDay
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var cityName: String = ""
    @State private var notes: String = ""
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(icon: "pencil.line", title: "РЕДАКТИРОВАТЬ ДЕНЬ", color: AppTheme.oceanBlue)

                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Название дня", text: $title)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    GlassFormField(label: "ГОРОД", color: AppTheme.oceanBlue) {
                        TextField("Город", text: $cityName)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    GlassFormField(label: "ДАТА", color: AppTheme.sakuraPink) {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
                    }
                    GlassFormField(label: "ЗАМЕТКИ", color: .secondary) {
                        TextField("Заметки", text: $notes)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("ОТМЕНА")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        day.title = title.trimmingCharacters(in: .whitespaces)
                        day.cityName = cityName.trimmingCharacters(in: .whitespaces)
                        day.notes = notes.trimmingCharacters(in: .whitespaces)
                        day.date = date
                        dismiss()
                    } label: {
                        Text("СОХРАНИТЬ")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }
            }
            .onAppear {
                title = day.title
                cityName = day.cityName
                notes = day.notes
                date = day.date
            }
        }
    }
}

#if DEBUG
#Preview {
    let trip = Trip.preview
    NavigationStack {
        DayDetailView(trip: trip, day: trip.sortedDays[0])
    }
    .modelContainer(.preview)
}
#endif
