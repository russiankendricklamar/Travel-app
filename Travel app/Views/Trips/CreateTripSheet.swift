import SwiftUI
import SwiftData

struct CreateTripSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query var bucketItems: [BucketListItem]

    var onCreated: ((Trip) -> Void)?
    var prefilledDestination: String = ""

    @State private var tripName = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var budget = ""
    @State private var flightDateEnabled = false
    @State private var flightDate = Date()
    @State private var flightNumber = ""
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

                    GlassFormField(label: "НАПРАВЛЕНИЕ", color: AppTheme.oceanBlue) {
                        TextField("Направление", text: $destination)
                            .textFieldStyle(GlassTextFieldStyle())
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

                    GlassFormField(label: "БЮДЖЕТ (RUB)", color: AppTheme.templeGold) {
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
                if !prefilledDestination.isEmpty && destination.isEmpty {
                    destination = prefilledDestination
                }
            }
        }
    }

    // MARK: - Flight Section

    private var flightSection: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.oceanBlue)
                        .frame(width: 3, height: 12)
                    Text("РЕЙС")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.oceanBlue)
                }
                Spacer()
                Toggle("", isOn: $flightDateEnabled)
                    .tint(AppTheme.sakuraPink)
                    .labelsHidden()
            }
            .padding(AppTheme.spacingM)

            if flightDateEnabled {
                TextField("SU260", text: $flightNumber)
                    .textFieldStyle(GlassTextFieldStyle())
                    .textInputAutocapitalization(.characters)
                    .padding(.horizontal, AppTheme.spacingM)

                DatePicker("", selection: $flightDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(AppTheme.sakuraPink)
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.bottom, AppTheme.spacingM)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Bucket List Suggestions

    private var matchingBucketItems: [BucketListItem] {
        let dest = destination.trimmingCharacters(in: .whitespaces).lowercased()
        guard !dest.isEmpty else { return [] }
        return bucketItems.filter { !$0.isConverted && $0.destination.lowercased().contains(dest) }
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

    // MARK: - Validation

    private var isValid: Bool {
        !tripName.trimmingCharacters(in: .whitespaces).isEmpty
            && !destination.trimmingCharacters(in: .whitespaces).isEmpty
            && endDate > startDate
    }

    // MARK: - Create

    private func createTrip() {
        let budgetValue = Double(budget) ?? 350000
        let trip = Trip(
            name: tripName.trimmingCharacters(in: .whitespaces),
            destination: destination.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: endDate,
            budget: budgetValue,
            currency: "RUB",
            coverSystemImage: "airplane",
            flightDate: flightDateEnabled ? flightDate : nil,
            flightNumber: flightDateEnabled && !flightNumber.isEmpty ? flightNumber.trimmingCharacters(in: .whitespaces) : nil
        )
        modelContext.insert(trip)

        // Convert selected bucket items into places
        if !selectedBucketIDs.isEmpty {
            let firstDay = TripDay(
                date: startDate,
                title: "День 1",
                cityName: destination.trimmingCharacters(in: .whitespaces),
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
        dismiss()
    }
}
