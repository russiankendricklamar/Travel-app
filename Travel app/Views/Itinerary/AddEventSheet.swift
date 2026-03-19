import SwiftUI
import SwiftData
import CoreLocation

struct AddEventSheet: View {
    let day: TripDay
    var editing: TripEvent?
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subtitle = ""
    @State private var category: EventCategory = .other
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var notes = ""
    @State private var cityTimeZone: TimeZone?

    // Regular event location
    @State private var locationName = ""
    @State private var latitude: Double?
    @State private var longitude: Double?

    // Transport event locations
    @State private var departureLocationName = ""
    @State private var departureLatitude: Double?
    @State private var departureLongitude: Double?
    @State private var arrivalLocationName = ""
    @State private var arrivalLatitude: Double?
    @State private var arrivalLongitude: Double?

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && endTime > startTime
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "calendar.badge.plus",
                        title: editing != nil ? "РЕДАКТИРОВАТЬ СОБЫТИЕ" : "НОВОЕ СОБЫТИЕ",
                        color: AppTheme.oceanBlue
                    )

                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Название", text: $title)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    GlassFormField(label: "ОПИСАНИЕ", color: .secondary) {
                        TextField("Описание", text: $subtitle)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    GlassFormField(label: "КАТЕГОРИЯ", color: AppTheme.oceanBlue) {
                        categoryPicker
                    }

                    // Location search
                    if category.isTransport {
                        EventLocationSearchField(
                            label: "ОТПРАВЛЕНИЕ",
                            color: AppTheme.bambooGreen,
                            locationName: $departureLocationName,
                            latitude: $departureLatitude,
                            longitude: $departureLongitude
                        )
                        EventLocationSearchField(
                            label: "ПРИБЫТИЕ",
                            color: AppTheme.toriiRed,
                            locationName: $arrivalLocationName,
                            latitude: $arrivalLatitude,
                            longitude: $arrivalLongitude
                        )
                    } else {
                        EventLocationSearchField(
                            label: "МЕСТО",
                            color: AppTheme.sakuraPink,
                            locationName: $locationName,
                            latitude: $latitude,
                            longitude: $longitude
                        )
                    }

                    GlassFormField(label: "НАЧАЛО", color: AppTheme.bambooGreen) {
                        DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
                            .environment(\.timeZone, cityTimeZone ?? .current)
                    }
                    GlassFormField(label: "КОНЕЦ", color: AppTheme.toriiRed) {
                        DatePicker("", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
                            .environment(\.timeZone, cityTimeZone ?? .current)
                    }

                    if let tz = cityTimeZone, tz != .current {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.templeGold)
                            Text("Время указывается по \(day.cityName)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.templeGold)
                        }
                        .padding(.horizontal, AppTheme.spacingM)
                    }
                    GlassFormField(label: "ЗАМЕТКИ", color: .secondary) {
                        TextField("Дополнительные детали...", text: $notes)
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
                    Button { save() } label: {
                        Text("СОХРАНИТЬ")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(isValid ? AppTheme.sakuraPink : .secondary)
                    }
                    .disabled(!isValid)
                }
            }
            .task {
                // Use cached timezone if available
                if let cached = day.resolvedTimeZone {
                    cityTimeZone = cached
                    return
                }
                guard !day.cityName.isEmpty else { return }
                let coder = CLGeocoder()
                if let placemarks = try? await coder.geocodeAddressString(day.cityName),
                   let tz = placemarks.first?.timeZone {
                    cityTimeZone = tz
                    day.timezoneIdentifier = tz.identifier
                }
            }
            .onAppear {
                if let e = editing {
                    title = e.title
                    subtitle = e.subtitle
                    category = e.category
                    startTime = e.startTime
                    endTime = e.endTime
                    notes = e.notes
                    // Load location data
                    if e.category.isTransport {
                        departureLatitude = e.startLatitude
                        departureLongitude = e.startLongitude
                        arrivalLatitude = e.endLatitude
                        arrivalLongitude = e.endLongitude
                    } else {
                        latitude = e.latitude
                        longitude = e.longitude
                    }
                } else {
                    // Use destination timezone for default times
                    let tz = day.resolvedTimeZone ?? cityTimeZone ?? .current
                    var cal = Calendar.current
                    cal.timeZone = tz
                    var comps = cal.dateComponents([.year, .month, .day], from: day.date)
                    comps.hour = 9
                    startTime = cal.date(from: comps) ?? Date()
                    comps.hour = 10
                    endTime = cal.date(from: comps) ?? Date()
                }
            }
            .onChange(of: category) { oldValue, newValue in
                let wasTransport = oldValue.isTransport
                let isTransport = newValue.isTransport
                if wasTransport != isTransport {
                    // Clear all location data when switching between transport/regular
                    latitude = nil
                    longitude = nil
                    locationName = ""
                    departureLatitude = nil
                    departureLongitude = nil
                    departureLocationName = ""
                    arrivalLatitude = nil
                    arrivalLongitude = nil
                    arrivalLocationName = ""
                }
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(EventCategory.allCases), id: \.self) { (cat: EventCategory) in
                    Button {
                        category = cat
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.systemImage)
                                .font(.system(size: 12, weight: .bold))
                            Text(cat.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundStyle(category == cat ? .white : .secondary)
                        .background(category == cat ? cat.color : .clear)
                        .background { if category != cat { Color.clear.background(.ultraThinMaterial) } }
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                category == cat ? cat.color.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: 0.5
                            )
                        )
                    }
                }
            }
        }
    }

    private func save() {
        if let e = editing {
            e.title = title.trimmingCharacters(in: .whitespaces)
            e.subtitle = subtitle.trimmingCharacters(in: .whitespaces)
            e.category = category
            e.startTime = startTime
            e.endTime = endTime
            e.notes = notes.trimmingCharacters(in: .whitespaces)
            if category.isTransport {
                e.startLatitude = departureLatitude
                e.startLongitude = departureLongitude
                e.endLatitude = arrivalLatitude
                e.endLongitude = arrivalLongitude
                e.latitude = nil
                e.longitude = nil
            } else {
                e.latitude = latitude
                e.longitude = longitude
                e.startLatitude = nil
                e.startLongitude = nil
                e.endLatitude = nil
                e.endLongitude = nil
            }
        } else {
            let event = TripEvent(
                title: title.trimmingCharacters(in: .whitespaces),
                subtitle: subtitle.trimmingCharacters(in: .whitespaces),
                category: category,
                startTime: startTime,
                endTime: endTime,
                notes: notes.trimmingCharacters(in: .whitespaces),
                latitude: category.isTransport ? nil : latitude,
                longitude: category.isTransport ? nil : longitude,
                startLatitude: category.isTransport ? departureLatitude : nil,
                startLongitude: category.isTransport ? departureLongitude : nil,
                endLatitude: category.isTransport ? arrivalLatitude : nil,
                endLongitude: category.isTransport ? arrivalLongitude : nil
            )
            event.sortOrder = day.events.count
            day.events.append(event)
        }
        dismiss()
    }
}
