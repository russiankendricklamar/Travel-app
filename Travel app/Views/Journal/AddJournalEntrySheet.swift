import SwiftUI
import SwiftData

struct AddJournalEntrySheet: View {
    let trip: Trip
    var editing: JournalEntry?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var content = ""
    @State private var mood: Mood = .happy
    @State private var date = Date()

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppTheme.spacingM) {
                        HStack {
                            Image(systemName: "book.fill").font(.system(size: 16, weight: .bold))
                            Text(editing != nil ? "РЕДАКТИРОВАТЬ ЗАПИСЬ" : "НОВАЯ ЗАПИСЬ")
                                .font(.system(size: 12, weight: .black)).tracking(3)
                        }
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(AppTheme.sakuraPink)

                        SakuraFormField(label: "ЗАГОЛОВОК", color: AppTheme.sakuraPink) {
                            TextField("Удивительный день в Киото", text: $title).textFieldStyle(SakuraTextFieldStyle())
                        }
                        SakuraFormField(label: "НАСТРОЕНИЕ", color: AppTheme.templeGold) { moodPicker }
                        SakuraFormField(label: "ДАТА", color: AppTheme.oceanBlue) {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact).labelsHidden().tint(AppTheme.sakuraPink)
                        }
                        SakuraFormField(label: "МЫСЛИ", color: AppTheme.bambooGreen) {
                            TextEditor(text: $content)
                                .frame(minHeight: 180)
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.card)
                                .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1))
                        }
                    }
                    .padding(AppTheme.spacingM)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("ОТМЕНА").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(AppTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { saveEntry() } label: {
                        Text("СОХРАНИТЬ").font(.system(size: 11, weight: .black)).tracking(1)
                            .foregroundStyle(isValid ? AppTheme.sakuraPink : AppTheme.textMuted)
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let e = editing {
                    title = e.title; content = e.content; mood = e.mood; date = e.date
                }
            }
        }
    }

    private var moodPicker: some View {
        HStack(spacing: 4) {
            ForEach(Mood.allCases) { m in
                let moodColor = AppTheme.moodColor(for: m)
                Button { mood = m } label: {
                    VStack(spacing: 4) {
                        Image(systemName: m.systemImage).font(.system(size: 22, weight: .bold))
                        Text(m.rawValue.uppercased()).font(.system(size: 7, weight: .black)).tracking(0.5)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .foregroundStyle(mood == m ? moodColor : AppTheme.textMuted)
                    .background(mood == m ? moodColor.opacity(0.1) : AppTheme.surface)
                    .overlay(Rectangle().stroke(mood == m ? moodColor : AppTheme.border, lineWidth: mood == m ? 2 : 1))
                    .overlay(Rectangle().fill(mood == m ? moodColor : .clear).frame(height: 3), alignment: .bottom)
                }
            }
        }
    }

    private func saveEntry() {
        if let e = editing {
            e.title = title.trimmingCharacters(in: .whitespaces)
            e.content = content.trimmingCharacters(in: .whitespaces)
            e.mood = mood; e.date = date
        } else {
            let entry = JournalEntry(
                date: date,
                title: title.trimmingCharacters(in: .whitespaces),
                content: content.trimmingCharacters(in: .whitespaces),
                mood: mood
            )
            trip.journalEntries.append(entry)
        }
        dismiss()
    }
}

#if DEBUG
#Preview {
    AddJournalEntrySheet(trip: .preview).modelContainer(.preview)
}
#endif
