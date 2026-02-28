import SwiftUI
import SwiftData

struct DayDetailView: View {
    let trip: Trip
    let day: TripDay
    @Environment(\.modelContext) private var modelContext

    @State private var showingEditDay = false
    @State private var showingAddPlace = false
    @State private var showingAddEvent = false
    @State private var editingPlace: Place?
    @State private var editingEvent: TripEvent?

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
                        place.isVisited.toggle()
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
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppTheme.spacingM) {
                        HStack {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 16, weight: .bold))
                            Text("РЕДАКТИРОВАТЬ ДЕНЬ")
                                .font(.system(size: 12, weight: .black))
                                .tracking(3)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.oceanBlue)

                        SakuraFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                            TextField("Название дня", text: $title)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }
                        SakuraFormField(label: "ГОРОД", color: AppTheme.oceanBlue) {
                            TextField("Город", text: $cityName)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }
                        SakuraFormField(label: "ДАТА", color: AppTheme.sakuraPink) {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(AppTheme.sakuraPink)
                        }
                        SakuraFormField(label: "ЗАМЕТКИ", color: AppTheme.textMuted) {
                            TextField("Заметки", text: $notes)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }
                    }
                    .padding(AppTheme.spacingM)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("ОТМЕНА")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(AppTheme.textSecondary)
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
                            .font(.system(size: 11, weight: .black))
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
