import SwiftUI

struct EditFlightSheet: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss

    @State private var flightNumber: String
    @State private var flightDate: Date
    @State private var flightEnabled: Bool

    init(trip: Trip) {
        self.trip = trip
        _flightNumber = State(initialValue: trip.flightNumber ?? "")
        _flightDate = State(initialValue: trip.flightDate ?? Date())
        _flightEnabled = State(initialValue: trip.flightNumber != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "airplane",
                        title: "РЕДАКТИРОВАТЬ РЕЙС",
                        color: AppTheme.oceanBlue
                    )

                    // Toggle
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
                        Toggle("", isOn: $flightEnabled)
                            .tint(AppTheme.sakuraPink)
                            .labelsHidden()
                    }
                    .padding(AppTheme.spacingM)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                            .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
                    )

                    if flightEnabled {
                        GlassFormField(label: "НОМЕР РЕЙСА", color: AppTheme.oceanBlue) {
                            TextField("SU260", text: $flightNumber)
                                .textFieldStyle(GlassTextFieldStyle())
                                .textInputAutocapitalization(.characters)
                        }

                        GlassFormField(label: "ДАТА И ВРЕМЯ ВЫЛЕТА", color: AppTheme.oceanBlue) {
                            DatePicker(
                                "",
                                selection: $flightDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
                        }
                    }
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
                    Button("СОХРАНИТЬ") { save() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.oceanBlue)
                }
            }
        }
    }

    private func save() {
        if flightEnabled {
            let trimmed = flightNumber.trimmingCharacters(in: .whitespaces)
            trip.flightNumber = trimmed.isEmpty ? nil : trimmed
            trip.flightDate = flightDate
        } else {
            trip.flightNumber = nil
            trip.flightDate = nil
        }
        dismiss()
    }
}
