import SwiftUI
import SwiftData

struct AddEventSheet: View {
    let day: TripDay
    var editing: TripEvent?
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subtitle = ""
    @State private var category: EventCategory = .other
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var notes = ""

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && endTime > startTime
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
                            Text(editing != nil ? "РЕДАКТИРОВАТЬ СОБЫТИЕ" : "НОВОЕ СОБЫТИЕ")
                                .font(.system(size: 12, weight: .black))
                                .tracking(3)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.oceanBlue)

                        SakuraFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                            TextField("Shinkansen Nozomi", text: $title)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }
                        SakuraFormField(label: "ОПИСАНИЕ", color: AppTheme.textMuted) {
                            TextField("Токио → Киото", text: $subtitle)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }
                        SakuraFormField(label: "КАТЕГОРИЯ", color: AppTheme.oceanBlue) {
                            categoryPicker
                        }
                        SakuraFormField(label: "НАЧАЛО", color: AppTheme.bambooGreen) {
                            DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(AppTheme.sakuraPink)
                        }
                        SakuraFormField(label: "КОНЕЦ", color: AppTheme.toriiRed) {
                            DatePicker("", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
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
            .onAppear {
                if let e = editing {
                    title = e.title
                    subtitle = e.subtitle
                    category = e.category
                    startTime = e.startTime
                    endTime = e.endTime
                    notes = e.notes
                } else {
                    // Default times based on day's date
                    var comps = Calendar.current.dateComponents([.year, .month, .day], from: day.date)
                    comps.hour = 9
                    startTime = Calendar.current.date(from: comps) ?? Date()
                    comps.hour = 10
                    endTime = Calendar.current.date(from: comps) ?? Date()
                }
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(EventCategory.allCases) { cat in
                    Button {
                        category = cat
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.systemImage)
                                .font(.system(size: 12, weight: .bold))
                            Text(cat.rawValue.uppercased())
                                .font(.system(size: 10, weight: .black))
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundStyle(category == cat ? .white : AppTheme.textSecondary)
                        .background(category == cat ? cat.color : AppTheme.surface)
                        .overlay(
                            Rectangle().stroke(
                                category == cat ? cat.color : AppTheme.border,
                                lineWidth: category == cat ? 2 : 1
                            )
                        )
                    }
                }
            }
        }
    }

    private func save() {
        if let e = editing {
            e.title = title.trimmingCharacters(in: .whitespaces)
            e.subtitle = subtitle.trimmingCharacters(in: .whitespaces)
            e.category = category
            e.startTime = startTime
            e.endTime = endTime
            e.notes = notes.trimmingCharacters(in: .whitespaces)
        } else {
            let event = TripEvent(
                title: title.trimmingCharacters(in: .whitespaces),
                subtitle: subtitle.trimmingCharacters(in: .whitespaces),
                category: category,
                startTime: startTime,
                endTime: endTime,
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
            day.events.append(event)
        }
        dismiss()
    }
}
