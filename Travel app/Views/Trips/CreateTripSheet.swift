import SwiftUI
import SwiftData

struct CreateTripSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query var bucketItems: [BucketListItem]

    var onCreated: ((Trip) -> Void)?

    @State private var tripName = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var budget = ""
    @State private var flightDateEnabled = false
    @State private var flightDate = Date()
    @State private var flightNumber = ""

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

    private var bucketListSection: some View {
        Group {
            if !matchingBucketItems.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 3, height: 12)
                        Text("ИЗ СПИСКА ЖЕЛАНИЙ")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(AppTheme.sakuraPink)
                    }

                    ForEach(matchingBucketItems) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.sakuraPink)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(item.destination)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.templeGold.opacity(0.5))
                        }
                        .padding(10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
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
        do {
            try modelContext.save()
        } catch {
            print("[CreateTripSheet] Save error: \(error)")
        }
        dismiss()
    }
}
