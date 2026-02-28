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
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "calendar.badge.plus",
                        title: editing != nil ? "РЕДАКТИРОВАТЬ СОБЫТИЕ" : "НОВОЕ СОБЫТИЕ",
                        color: AppTheme.oceanBlue
                    )

                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Shinkansen Nozomi", text: $title)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    GlassFormField(label: "ОПИСАНИЕ", color: .secondary) {
                        TextField("Токио → Киото", text: $subtitle)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    GlassFormField(label: "КАТЕГОРИЯ", color: AppTheme.oceanBlue) {
                        categoryPicker
                    }
                    GlassFormField(label: "НАЧАЛО", color: AppTheme.bambooGreen) {
                        DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
                    }
                    GlassFormField(label: "КОНЕЦ", color: AppTheme.toriiRed) {
                        DatePicker("", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
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
            .onAppear {
                if let e = editing {
                    title = e.title
                    subtitle = e.subtitle
                    category = e.category
                    startTime = e.startTime
                    endTime = e.endTime
                    notes = e.notes
                } else {
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
            HStack(spacing: 6) {
                ForEach(Array(EventCategory.allCases), id: \.self) { (cat: EventCategory) in
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
                        .background(category == cat ? cat.color : .clear)
                        .background { if category != cat { Color.clear.background(.ultraThinMaterial) } }
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                category == cat ? cat.color.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: 0.5
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
