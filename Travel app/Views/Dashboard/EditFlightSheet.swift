import SwiftUI

struct EditFlightSheet: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss

    @State private var drafts: [FlightDraft]
    @State private var showScanner = false

    init(trip: Trip) {
        self.trip = trip
        let existing = trip.flights.map {
            FlightDraft(
                id: $0.id,
                number: $0.number,
                date: $0.date ?? Date(),
                departureIata: $0.departureIata,
                arrivalIata: $0.arrivalIata
            )
        }
        _drafts = State(initialValue: existing)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "airplane",
                        title: "РЕЙСЫ",
                        color: AppTheme.oceanBlue
                    )

                    ForEach($drafts) { $draft in
                        flightRow(draft: $draft)
                    }

                    scanButton

                    addButton
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .sheet(isPresented: $showScanner) {
                BookingScannerSheet { scannedFlights in
                    let newDrafts = scannedFlights.map { flight in
                        FlightDraft(
                            number: flight.number,
                            date: flight.date ?? trip.startDate,
                            departureIata: flight.departureIata,
                            arrivalIata: flight.arrivalIata
                        )
                    }
                    withAnimation(.spring(response: 0.3)) {
                        drafts.append(contentsOf: newDrafts)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ОТМЕНА") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("СОХРАНИТЬ") { save() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.oceanBlue)
                }
            }
        }
    }

    // MARK: - Flight Row

    private func flightRow(draft: Binding<FlightDraft>) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.oceanBlue)
                        .frame(width: 3, height: 12)
                    Text("РЕЙС \(indexLabel(for: draft.wrappedValue))")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.oceanBlue)
                }
                Spacer()

                if drafts.count > 1 {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            drafts.removeAll { $0.id == draft.wrappedValue.id }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.toriiRed.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingS)

            TextField("SU260", text: draft.number)
                .textFieldStyle(GlassTextFieldStyle())
                .textInputAutocapitalization(.characters)
                .padding(.horizontal, AppTheme.spacingM)

            DatePicker("", selection: draft.date, displayedComponents: [.date, .hourAndMinute])
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

    // MARK: - Scan Button

    private var scanButton: some View {
        Button {
            showScanner = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("СКАНИРОВАТЬ БРОНЬ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.sakuraPink)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.sakuraPink.opacity(0.5))
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.sakuraPink.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                drafts.append(FlightDraft(number: "", date: trip.startDate))
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

    // MARK: - Helpers

    private func indexLabel(for draft: FlightDraft) -> String {
        guard let idx = drafts.firstIndex(where: { $0.id == draft.id }) else { return "" }
        return "\(idx + 1)"
    }

    private func save() {
        let existingMap = Dictionary(uniqueKeysWithValues: trip.flights.map { ($0.id, $0) })
        let validFlights = drafts.compactMap { draft -> TripFlight? in
            let trimmed = draft.number.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let existing = existingMap[draft.id]
            return TripFlight(
                id: draft.id,
                number: trimmed,
                date: draft.date,
                departureIata: draft.departureIata ?? existing?.departureIata,
                arrivalIata: draft.arrivalIata ?? existing?.arrivalIata,
                airlineCode: existing?.airlineCode,
                aircraftType: existing?.aircraftType
            )
        }
        trip.flights = validFlights
        dismiss()
    }
}

// MARK: - Flight Draft

struct FlightDraft: Identifiable {
    var id: UUID = UUID()
    var number: String
    var date: Date
    var departureIata: String?
    var arrivalIata: String?
}
