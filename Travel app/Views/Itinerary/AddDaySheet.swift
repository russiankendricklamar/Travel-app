import SwiftUI
import SwiftData

struct AddDaySheet: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var cityName = ""
    @State private var date = Date()
    @State private var notes = ""

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !cityName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppTheme.spacingM) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 16, weight: .bold))
                            Text("НОВЫЙ ДЕНЬ")
                                .font(.system(size: 12, weight: .black))
                                .tracking(3)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.sakuraPink)

                        SakuraFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                            TextField("Прилёт и Сибуя", text: $title)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }

                        SakuraFormField(label: "ГОРОД", color: AppTheme.oceanBlue) {
                            TextField("Токио", text: $cityName)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }

                        SakuraFormField(label: "ДАТА", color: AppTheme.sakuraPink) {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(AppTheme.sakuraPink)
                        }

                        SakuraFormField(label: "ЗАМЕТКИ", color: AppTheme.textMuted) {
                            TextField("Дополнительные детали...", text: $notes)
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
                    Button { save() } label: {
                        Text("СОХРАНИТЬ")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1)
                            .foregroundStyle(isValid ? AppTheme.sakuraPink : AppTheme.textMuted)
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let day = TripDay(
            date: date,
            title: title.trimmingCharacters(in: .whitespaces),
            cityName: cityName.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        trip.days.append(day)
        dismiss()
    }
}
