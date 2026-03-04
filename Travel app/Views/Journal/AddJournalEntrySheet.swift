import SwiftUI
import SwiftData

struct AddJournalEntrySheet: View {
    let day: TripDay
    var linkedPlace: Place?
    var editing: JournalEntry?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text = ""
    @State private var selectedMood: JournalMood = .good
    @State private var photos: [TripPhoto] = []

    private var isValid: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "book.fill",
                        title: editing != nil ? "РЕДАКТИРОВАТЬ ЗАПИСЬ" : "НОВАЯ ЗАПИСЬ",
                        color: AppTheme.indigoPurple
                    )

                    if let place = linkedPlace {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.oceanBlue)
                            Text(place.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    }

                    // Mood picker
                    GlassFormField(label: "НАСТРОЕНИЕ", color: AppTheme.indigoPurple) {
                        HStack(spacing: 8) {
                            ForEach(JournalMood.allCases, id: \.self) { mood in
                                Button {
                                    selectedMood = mood
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(mood.emoji)
                                            .font(.system(size: 24))
                                        Text(mood.label)
                                            .font(.system(size: 9, weight: .bold))
                                            .tracking(0.5)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedMood == mood ? mood.color.opacity(0.2) : .clear)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                            .stroke(selectedMood == mood ? mood.color : Color.white.opacity(0.15), lineWidth: selectedMood == mood ? 1.5 : 0.5)
                                    )
                                }
                                .foregroundStyle(selectedMood == mood ? mood.color : .secondary)
                            }
                        }
                    }

                    GlassFormField(label: "ЗАПИСЬ", color: AppTheme.sakuraPink) {
                        TextEditor(text: $text)
                            .font(.system(size: 14))
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                    }

                    PhotoGridView(
                        photos: photos,
                        onAdd: { photo in photos.append(photo) },
                        onDelete: { photo in
                            photos.removeAll { $0.id == photo.id }
                            modelContext.delete(photo)
                        }
                    )
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
                            .foregroundStyle(isValid ? AppTheme.indigoPurple : .secondary)
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let e = editing {
                    text = e.text
                    selectedMood = e.journalMood
                    photos = e.photos
                }
            }
        }
    }

    private func save() {
        if let e = editing {
            e.text = text.trimmingCharacters(in: .whitespaces)
            e.mood = selectedMood.rawValue
            e.photos = photos
        } else {
            let entry = JournalEntry(
                text: text.trimmingCharacters(in: .whitespaces),
                mood: selectedMood.rawValue,
                isStandalone: linkedPlace == nil,
                latitude: linkedPlace?.latitude,
                longitude: linkedPlace?.longitude
            )
            entry.day = day
            entry.place = linkedPlace
            entry.photos = photos
            modelContext.insert(entry)
        }
        try? modelContext.save()
        dismiss()
    }
}
