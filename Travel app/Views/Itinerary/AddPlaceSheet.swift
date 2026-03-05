import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct AddPlaceSheet: View {
    let day: TripDay
    var editing: Place?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var nameLocal = ""
    @State private var category: PlaceCategory = .culture
    @State private var address = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var timeToSpend = ""
    @State private var notes = ""

    // Search
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false

    // AI Info
    @State private var isLoadingAI = false
    @State private var aiError: String?
    @State private var selectedCity: String?

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasCoordinates: Bool {
        let lat = Double(latitude.replacingOccurrences(of: ",", with: "."))
        let lon = Double(longitude.replacingOccurrences(of: ",", with: "."))
        return lat != nil && lon != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "mappin.circle.fill",
                        title: editing != nil ? "РЕДАКТИРОВАТЬ МЕСТО" : "НОВОЕ МЕСТО",
                        color: AppTheme.sakuraPink
                    )

                    // MARK: - Map Search
                    if editing == nil {
                        mapSearchSection
                    }

                    // MARK: - Manual Fields
                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Название места", text: $name)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    GlassFormField(label: "МЕСТНОЕ НАЗВАНИЕ", color: AppTheme.templeGold) {
                        TextField("Local name", text: $nameLocal)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    GlassFormField(label: "КАТЕГОРИЯ", color: AppTheme.oceanBlue) {
                        categoryPicker
                    }
                    GlassFormField(label: "АДРЕС", color: .secondary) {
                        TextField("Адрес", text: $address)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    HStack(spacing: AppTheme.spacingS) {
                        GlassFormField(label: "ШИРОТА", color: hasCoordinates ? AppTheme.bambooGreen : .secondary) {
                            TextField("35.7148", text: $latitude)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                        GlassFormField(label: "ДОЛГОТА", color: hasCoordinates ? AppTheme.bambooGreen : .secondary) {
                            TextField("139.7967", text: $longitude)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                    }
                    GlassFormField(label: "ВРЕМЯ НА ПОСЕЩЕНИЕ", color: AppTheme.sakuraPink) {
                        TextField("1,5 ч", text: $timeToSpend)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    // MARK: - AI Info Button
                    if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        aiInfoSection
                    }

                    GlassFormField(label: "ЗАМЕТКИ", color: .secondary) {
                        TextEditor(text: $notes)
                            .font(.system(size: 14))
                            .frame(minHeight: notes.isEmpty ? 44 : 120)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                    }

                    if let place = editing {
                        PhotoGridView(
                            photos: place.photos,
                            onAdd: { photo in
                                place.photos.append(photo)
                            },
                            onDelete: { photo in
                                place.photos.removeAll { $0.id == photo.id }
                                modelContext.delete(photo)
                            }
                        )
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
            .onAppear {
                if let p = editing {
                    name = p.name
                    nameLocal = p.nameLocal
                    category = p.category
                    address = p.address
                    latitude = String(p.latitude)
                    longitude = String(p.longitude)
                    timeToSpend = p.timeToSpend
                    notes = p.notes
                }
            }
        }
    }

    // MARK: - Map Search Section

    private var mapSearchSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.oceanBlue)
                Text("ПОИСК НА КАРТЕ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.oceanBlue)
                Spacer()
                if isSearching {
                    ProgressView().scaleEffect(0.6)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                TextField("Поиск места...", text: $searchQuery)
                    .font(.system(size: 14))
                    .autocorrectionDisabled()
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.oceanBlue.opacity(0.2), lineWidth: 0.5)
            )
            .onChange(of: searchQuery) { _, newValue in
                searchTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 2 else {
                    searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await searchPlaces(query: trimmed)
                }
            }

            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.prefix(5).enumerated()), id: \.offset) { _, item in
                        Button {
                            selectMapItem(item)
                        } label: {
                            searchResultRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusLarge)))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusLarge))
                .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func searchResultRow(_ item: MKMapItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.sakuraPink)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle = formatAddress(item) {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.bambooGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - AI Info Section

    private var aiInfoSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            Button {
                Task { await fetchAIInfo() }
            } label: {
                HStack(spacing: 8) {
                    if isLoadingAI {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(isLoadingAI ? "ЗАГРУЗКА..." : "УЗНАТЬ О МЕСТЕ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [AppTheme.indigoPurple, AppTheme.oceanBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .shadow(color: AppTheme.indigoPurple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isLoadingAI)

            if let error = aiError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 11))
                }
                .foregroundStyle(AppTheme.toriiRed)
            }
        }
    }

    private func fetchAIInfo() async {
        isLoadingAI = true
        aiError = nil

        let info = await PlaceInfoService.shared.fetchInfo(
            placeName: name,
            category: category.rawValue,
            city: selectedCity ?? day.cityName
        )

        if let info {
            notes = info.formatted
        } else {
            aiError = PlaceInfoService.shared.lastError ?? String(localized: "Не удалось получить информацию")
        }

        isLoadingAI = false
    }

    // MARK: - Search Logic

    private func searchPlaces(query: String) async {
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }

        isSearching = false
    }

    private func selectMapItem(_ item: MKMapItem) {
        if let itemName = item.name {
            name = itemName
        }
        let coord = item.placemark.coordinate
        latitude = String(format: "%.6f", coord.latitude)
        longitude = String(format: "%.6f", coord.longitude)

        if let formatted = formatAddress(item) {
            address = formatted
        }

        selectedCity = item.placemark.locality

        searchQuery = ""
        searchResults = []
    }

    private func formatAddress(_ item: MKMapItem) -> String? {
        let pm = item.placemark
        var parts: [String] = []
        if let subLocality = pm.subLocality { parts.append(subLocality) }
        if let locality = pm.locality { parts.append(locality) }
        if let admin = pm.administrativeArea, !parts.contains(admin) { parts.append(admin) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(PlaceCategory.allCases), id: \.self) { (cat: PlaceCategory) in
                    let color = AppTheme.categoryColor(for: cat.rawValue)
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
                        .background(category == cat ? color : .clear)
                        .background { if category != cat { Color.clear.background(.ultraThinMaterial) } }
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                category == cat ? color.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: 0.5
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        let lat = Double(latitude.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let lon = Double(longitude.replacingOccurrences(of: ",", with: ".")) ?? 0.0

        if let p = editing {
            p.name = name.trimmingCharacters(in: .whitespaces)
            p.nameLocal = nameLocal.trimmingCharacters(in: .whitespaces)
            p.category = category
            p.address = address.trimmingCharacters(in: .whitespaces)
            p.latitude = lat
            p.longitude = lon
            p.timeToSpend = timeToSpend.trimmingCharacters(in: .whitespaces)
            p.notes = notes.trimmingCharacters(in: .whitespaces)
        } else {
            let place = Place(
                name: name.trimmingCharacters(in: .whitespaces),
                nameLocal: nameLocal.trimmingCharacters(in: .whitespaces),
                category: category,
                address: address.trimmingCharacters(in: .whitespaces),
                latitude: lat,
                longitude: lon,
                notes: notes.trimmingCharacters(in: .whitespaces),
                timeToSpend: timeToSpend.trimmingCharacters(in: .whitespaces)
            )
            place.sortOrder = day.places.count
            day.places.append(place)
        }
        dismiss()
    }
}
