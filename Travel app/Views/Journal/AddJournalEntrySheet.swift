import SwiftUI

struct AddJournalEntrySheet: View {
    let store: TripStore
    @Environment(\.dismiss) private var dismiss

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
                            Image(systemName: "book.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("НОВАЯ ЗАПИСЬ")
                                .font(.system(size: 12, weight: .black))
                                .tracking(3)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.sakuraPink)

                        formField(label: "ЗАГОЛОВОК", color: AppTheme.sakuraPink) {
                            TextField("Удивительный день в Киото", text: $title)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }

                        formField(label: "НАСТРОЕНИЕ", color: AppTheme.templeGold) {
                            moodPicker
                        }

                        formField(label: "ДАТА", color: AppTheme.oceanBlue) {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(AppTheme.sakuraPink)
                        }

                        formField(label: "МЫСЛИ", color: AppTheme.bambooGreen) {
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
                    Button {
                        dismiss()
                    } label: {
                        Text("ОТМЕНА")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveEntry()
                    } label: {
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

    private func formField<Content: View>(label: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(color)
                    .frame(width: 4)
                Text(label)
                    .font(.system(size: 9, weight: .black))
                    .tracking(2)
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                Spacer()
            }
            .background(AppTheme.surface)

            content()
                .padding(.horizontal, AppTheme.spacingS)
                .padding(.vertical, AppTheme.spacingS)
                .background(AppTheme.card)
        }
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1))
    }

    private var moodPicker: some View {
        HStack(spacing: 4) {
            ForEach(Mood.allCases) { m in
                let moodColor = AppTheme.moodColor(for: m)

                Button {
                    mood = m
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: m.systemImage)
                            .font(.system(size: 22, weight: .bold))
                        Text(m.rawValue.uppercased())
                            .font(.system(size: 7, weight: .black))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(
                        mood == m ? moodColor : AppTheme.textMuted
                    )
                    .background(
                        mood == m ? moodColor.opacity(0.1) : AppTheme.surface
                    )
                    .overlay(
                        Rectangle()
                            .stroke(
                                mood == m ? moodColor : AppTheme.border,
                                lineWidth: mood == m ? 2 : 1
                            )
                    )
                    .overlay(
                        Rectangle()
                            .fill(mood == m ? moodColor : .clear)
                            .frame(height: 3),
                        alignment: .bottom
                    )
                }
            }
        }
    }

    private func saveEntry() {
        let entry = JournalEntry(
            id: UUID(),
            date: date,
            title: title.trimmingCharacters(in: .whitespaces),
            content: content.trimmingCharacters(in: .whitespaces),
            mood: mood
        )

        store.addJournalEntry(entry)
        dismiss()
    }
}

#Preview {
    AddJournalEntrySheet(store: TripStore())
}
