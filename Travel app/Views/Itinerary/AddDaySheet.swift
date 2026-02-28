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
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(icon: "calendar.badge.plus", title: "НОВЫЙ ДЕНЬ", color: AppTheme.sakuraPink)

                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Прилёт и Сибуя", text: $title)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    GlassFormField(label: "ГОРОД", color: AppTheme.oceanBlue) {
                        TextField("Токио", text: $cityName)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    GlassFormField(label: "ДАТА", color: AppTheme.sakuraPink) {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
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
