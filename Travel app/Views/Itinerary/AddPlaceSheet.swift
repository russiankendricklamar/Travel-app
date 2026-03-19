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
    @State private var searchResults: [PlaceRecommendation] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var selectedFromSearch = false

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

                    // MARK: - Name + Search (unified)
                    if editing == nil {
                        nameSearchSection
                    } else {
                        GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                            TextField("Название места", text: $name)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                    }

                    // MARK: - Category
                    GlassFormField(label: "КАТЕГОРИЯ", color: AppTheme.oceanBlue) {
                        categoryPicker
                    }

                    // MARK: - Address
                    GlassFormField(label: "АДРЕС", color: .secondary) {
                        TextField("Адрес", text: $address)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    // MARK: - Coordinates
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
                                try? modelContext.save()
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

    // MARK: - Unified Name + Search Section

    private var nameSearchSection: some View {
        VStack(spacing: 0) {
            // Name input with integrated search
            GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                    TextField("Введите название или адрес...", text: $name)
                        .font(.system(size: 14))
                        .autocorrectionDisabled()
                    if isSearching {
                        ProgressView().scaleEffect(0.6)
                    }
                    if !name.isEmpty && !searchResults.isEmpty {
                        Button {
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
                        .stroke(
                            !searchResults.isEmpty ? AppTheme.sakuraPink.opacity(0.3) : Color.white.opacity(0.15),
                            lineWidth: 0.5
                        )
                )
            }
            .onChange(of: name) { _, newValue in
                // Don't search if we just selected from results
                if selectedFromSearch {
                    selectedFromSearch = false
                    return
                }

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

            // Search results dropdown
            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.prefix(5).enumerated()), id: \.offset) { index, rec in
                        if index > 0 {
                            Divider().opacity(0.3).padding(.horizontal, 12)
                        }
                        Button {
                            selectResult(rec)
                        } label: {
                            searchResultRow(rec)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.sakuraPink.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: searchResults.isEmpty)
    }

    private func searchResultRow(_ rec: PlaceRecommendation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: rec.categoryIcon)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.sakuraPink)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(rec.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !rec.description.isEmpty {
                    Text(rec.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if !rec.address.isEmpty {
                    Text(rec.address)
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
        defer { isSearching = false }

        // Detect coordinate input: two numbers separated by comma/space
        if let coordinate = parseCoordinates(query) {
            await searchNearCoordinate(coordinate, query: query)
            return
        }

        // Standard search: name or address, bound to the day's city
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]

        if let region = await dayRegion() {
            request.region = region
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            // Guard against stale results (user cleared or changed input)
            guard !Task.isCancelled else { return }
            let items = Array(response.mapItems.prefix(6))
            let enriched = await AIMapSearchService.shared.enrichMapItems(items, userQuery: query)
            guard !Task.isCancelled else { return }
            searchResults = enriched
        } catch {
            if !Task.isCancelled {
                searchResults = []
            }
        }
    }

    private func parseCoordinates(_ text: String) -> CLLocationCoordinate2D? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard cleaned.count == 2,
              let lat = Double(cleaned[0]),
              let lon = Double(cleaned[1]),
              (-90...90).contains(lat),
              (-180...180).contains(lon) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func searchNearCoordinate(_ coordinate: CLLocationCoordinate2D, query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = ""
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            guard !Task.isCancelled else { return }
            let items = Array(response.mapItems.prefix(6))
            let enriched = await AIMapSearchService.shared.enrichMapItems(items, userQuery: query)
            guard !Task.isCancelled else { return }
            searchResults = enriched
        } catch {
            if !Task.isCancelled {
                searchResults = []
            }
        }
    }

    private func dayRegion() async -> MKCoordinateRegion? {
        if let firstPlace = day.places.first, firstPlace.latitude != 0 || firstPlace.longitude != 0 {
            return MKCoordinateRegion(
                center: firstPlace.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }

        let cityName = day.cityName
        guard !cityName.isEmpty else { return nil }

        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(cityName)
            if let location = placemarks.first?.location {
                return MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
            }
        } catch {}

        return nil
    }

    // MARK: - Select Result

    private func selectResult(_ rec: PlaceRecommendation) {
        selectedFromSearch = true
        name = rec.name
        address = rec.address
        latitude = String(format: "%.6f", rec.latitude)
        longitude = String(format: "%.6f", rec.longitude)
        category = rec.placeCategory
        nameLocal = rec.localName
        timeToSpend = rec.estimatedTime

        if !rec.description.isEmpty {
            notes = rec.description
        }

        searchResults = []
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
