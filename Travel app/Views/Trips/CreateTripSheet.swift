import SwiftUI
import SwiftData

struct CreateTripSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query var bucketItems: [BucketListItem]

    // @AppStorage("appMode") private var appMode: String = AppMode.personal.rawValue

    var onCreated: ((Trip) -> Void)?
    var prefilledCountry: String = ""

    @State private var tripName = ""
    @State private var countries: [String] = []
    @State private var currentCountryInput = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var budget = ""
    @State private var flightDrafts: [CreateFlightDraft] = []
    @State private var selectedBucketIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(icon: "airplane", title: "НОВАЯ ПОЕЗДКА", color: AppTheme.sakuraPink)

                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Моя поездка", text: $tripName)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    GlassFormField(label: "СТРАНЫ", color: AppTheme.oceanBlue) {
                        VStack(alignment: .leading, spacing: 8) {
                            if !countries.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(countries, id: \.self) { c in
                                        countryChip(c)
                                    }
                                }
                            }
                            HStack(spacing: 8) {
                                TextField("Добавить страну", text: $currentCountryInput)
                                    .textFieldStyle(GlassTextFieldStyle())
                                    .onSubmit { addCurrentCountry() }
                                Button {
                                    addCurrentCountry()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(AppTheme.oceanBlue)
                                }
                                .disabled(currentCountryInput.trimmingCharacters(in: .whitespaces).isEmpty)
                                .opacity(currentCountryInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
                            }
                        }
                    }

                    HStack(spacing: AppTheme.spacingS) {
                        GlassFormField(label: "НАЧАЛО", color: AppTheme.bambooGreen) {
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(AppTheme.sakuraPink)
                        }
                        GlassFormField(label: "КОНЕЦ", color: AppTheme.toriiRed) {
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(AppTheme.sakuraPink)
                        }
                    }

                    GlassFormField(label: "БЮДЖЕТ (\(CurrencyService.shared.baseCurrency))", color: AppTheme.templeGold) {
                        TextField("350000", text: $budget)
                            .keyboardType(.numberPad)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    flightSection
                    bucketListSection
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ОТМЕНА") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("СОЗДАТЬ") { createTrip() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.sakuraPink)
                        .disabled(!isValid)
                        .opacity(isValid ? 1.0 : 0.4)
                }
            }
            .onAppear {
                if !prefilledCountry.isEmpty && countries.isEmpty {
                    countries = [prefilledCountry]
                }
            }
        }
    }

    // MARK: - Flight Section

    private var flightSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            ForEach($flightDrafts) { $draft in
                VStack(spacing: 0) {
                    HStack {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppTheme.oceanBlue)
                                .frame(width: 3, height: 12)
                            Text("РЕЙС \(flightDraftIndex(draft) + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(AppTheme.oceanBlue)
                        }
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                flightDrafts.removeAll { $0.id == draft.id }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.toriiRed.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.top, AppTheme.spacingM)
                    .padding(.bottom, AppTheme.spacingS)

                    TextField("SU260", text: $draft.number)
                        .textFieldStyle(GlassTextFieldStyle())
                        .textInputAutocapitalization(.characters)
                        .padding(.horizontal, AppTheme.spacingM)

                    DatePicker("", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(AppTheme.sakuraPink)
                        .padding(.horizontal, AppTheme.spacingM)
                        .padding(.vertical, AppTheme.spacingS)
                        .padding(.bottom, AppTheme.spacingS)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
                )
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    flightDrafts.append(CreateFlightDraft(number: "", date: startDate))
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.oceanBlue)
                    Text("ДОБАВИТЬ РЕЙС")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.oceanBlue)
                    Spacer()
                }
                .padding(AppTheme.spacingM)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func flightDraftIndex(_ draft: CreateFlightDraft) -> Int {
        flightDrafts.firstIndex(where: { $0.id == draft.id }) ?? 0
    }

    // MARK: - Bucket List Suggestions

    private var matchingBucketItems: [BucketListItem] {
        guard !countries.isEmpty else { return [] }
        let lowerCountries = countries.map { $0.lowercased() }
        return bucketItems.filter { item in
            guard !item.isConverted else { return false }
            let dest = item.destination.lowercased()
            return lowerCountries.contains { dest.contains($0) }
        }
    }

    @ViewBuilder
    private var bucketListSection: some View {
        if !matchingBucketItems.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                bucketListHeader
                ForEach(matchingBucketItems) { item in
                    bucketItemRow(item)
                }
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    private var bucketListHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.sakuraPink)
                    .frame(width: 3, height: 12)
                Text("ИЗ СПИСКА ЖЕЛАНИЙ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.sakuraPink)
                Spacer()
                if !selectedBucketIDs.isEmpty {
                    Text("\(selectedBucketIDs.count) выбрано")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.bambooGreen)
                }
            }
            Text("Нажмите чтобы добавить в поездку")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func bucketItemRow(_ item: BucketListItem) -> some View {
        let isSelected = selectedBucketIDs.contains(item.id)
        return Button {
            withAnimation(.spring(response: 0.25)) {
                if isSelected {
                    selectedBucketIDs.remove(item.id)
                } else {
                    selectedBucketIDs.insert(item.id)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? AppTheme.bambooGreen : Color.gray.opacity(0.4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(item.destination)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if !item.notes.isEmpty {
                    Image(systemName: "note.text")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(10)
            .background(isSelected ? AppTheme.bambooGreen.opacity(0.08) : Color.clear)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(isSelected ? AppTheme.bambooGreen.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Country Helpers

    private func addCurrentCountry() {
        let trimmed = currentCountryInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Capitalize first letter
        let capitalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        if !countries.contains(where: { $0.lowercased() == capitalized.lowercased() }) {
            withAnimation(.spring(response: 0.25)) {
                countries.append(capitalized)
            }
        }
        currentCountryInput = ""
    }

    private func countryChip(_ name: String) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Button {
                withAnimation(.spring(response: 0.25)) {
                    countries.removeAll { $0 == name }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.oceanBlue.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Validation

    private var isValid: Bool {
        !tripName.trimmingCharacters(in: .whitespaces).isEmpty
            && !countries.isEmpty
            && endDate > startDate
    }

    // MARK: - Create

    private func createTrip() {
        let budgetValue = Double(budget) ?? 350000

        let validFlights = flightDrafts.compactMap { draft -> TripFlight? in
            let trimmed = draft.number.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return TripFlight(number: trimmed, date: draft.date)
        }

        let trip = Trip(
            name: tripName.trimmingCharacters(in: .whitespaces),
            country: countries.joined(separator: ", "),
            startDate: startDate,
            endDate: endDate,
            budget: budgetValue,
            currency: CurrencyService.shared.baseCurrency,
            coverSystemImage: "airplane",
            flightDate: validFlights.first?.date,
            flightNumber: validFlights.first?.number,
            isCorporateTrip: false
        )

        if !validFlights.isEmpty {
            trip.flights = validFlights
        }
        modelContext.insert(trip)

        // Convert selected bucket items into places
        if !selectedBucketIDs.isEmpty {
            let firstDay = TripDay(
                date: startDate,
                title: "День 1",
                cityName: countries.first ?? "",
                sortOrder: 0
            )
            firstDay.trip = trip
            modelContext.insert(firstDay)

            let selectedItems = matchingBucketItems.filter { selectedBucketIDs.contains($0.id) }
            for (index, item) in selectedItems.enumerated() {
                let place = Place(
                    name: item.name,
                    nameLocal: "",
                    category: PlaceCategory(rawValue: item.category) ?? .culture,
                    address: item.destination,
                    latitude: item.latitude ?? 0,
                    longitude: item.longitude ?? 0,
                    notes: item.notes
                )
                place.sortOrder = index
                place.day = firstDay
                modelContext.insert(place)
                item.isConverted = true
            }
        }

        do {
            try modelContext.save()
        } catch {
            // Save failed silently
        }

        let tripRef = trip
        let context = modelContext
        Task {
            await CountryInfoService.shared.populateTrip(tripRef, context: context)
        }

        dismiss()
    }
}

// MARK: - Create Flight Draft

private struct CreateFlightDraft: Identifiable {
    var id: UUID = UUID()
    var number: String
    var date: Date
}

// MARK: - Flow Layout (wrapping chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, containerWidth: proposal.width ?? .infinity)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, containerWidth: bounds.width)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func layout(subviews: Subviews, containerWidth: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > containerWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x - spacing)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
