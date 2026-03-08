import SwiftUI

struct AddDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    // @AppStorage("appMode") private var appMode: String = AppMode.personal.rawValue

    @State private var docType: DocumentType = .passport
    @State private var number: String = ""
    @State private var country: String = ""
    @State private var issueDate: Date = Date()
    @State private var expiryDate: Date = Calendar.current.date(byAdding: .year, value: 5, to: Date()) ?? Date()
    @State private var hasIssueDate = false
    @State private var hasExpiryDate = true
    @State private var notes: String = ""

    let onSave: (TravelDocument) -> Void

    // Corporate mode disabled
    private var isCorporate: Bool { false }

    private var availableTypes: [DocumentType] {
        DocumentType.personalCases
    }

    private var accent: Color {
        (ColorPalette(rawValue: palette) ?? .sakura).accentColor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingS) {
                    // Document type picker
                    GlassFormField(label: "ТИП ДОКУМЕНТА", color: accent) {
                        Picker("Тип", selection: $docType) {
                            ForEach(availableTypes) { type in
                                Label(type.label, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)
                    }

                    // Number
                    GlassFormField(label: "НОМЕР", color: accent) {
                        TextField("Номер документа", text: $number)
                            .textFieldStyle(GlassTextFieldStyle())
                            .font(.system(size: 14))
                            .autocorrectionDisabled()
                    }

                    // Country
                    GlassFormField(label: "СТРАНА ВЫДАЧИ", color: accent) {
                        TextField("Россия", text: $country)
                            .textFieldStyle(GlassTextFieldStyle())
                            .font(.system(size: 14))
                    }

                    // Issue date
                    GlassFormField(label: "ДАТА ВЫДАЧИ", color: accent) {
                        Toggle(isOn: $hasIssueDate) {
                            Text("Указать дату выдачи")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .tint(accent)

                        if hasIssueDate {
                            DatePicker("", selection: $issueDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                        }
                    }

                    // Expiry date
                    GlassFormField(label: "СРОК ДЕЙСТВИЯ", color: AppTheme.templeGold) {
                        Toggle(isOn: $hasExpiryDate) {
                            Text("Указать срок действия")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .tint(accent)

                        if hasExpiryDate {
                            DatePicker("", selection: $expiryDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                        }
                    }

                    // Notes
                    GlassFormField(label: "ЗАМЕТКИ", color: .secondary) {
                        TextField("Дополнительная информация", text: $notes, axis: .vertical)
                            .textFieldStyle(GlassTextFieldStyle())
                            .font(.system(size: 14))
                            .lineLimit(3...5)
                    }

                    // Save button
                    Button {
                        saveDocument()
                    } label: {
                        Text("СОХРАНИТЬ")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(number.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(number.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    .padding(.top, AppTheme.spacingS)

                    Spacer(minLength: 40)
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationTitle("Новый документ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ОТМЕНА") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func saveDocument() {
        let doc = TravelDocument(
            type: docType,
            number: number.trimmingCharacters(in: .whitespaces),
            country: country.trimmingCharacters(in: .whitespaces),
            issueDate: hasIssueDate ? issueDate : nil,
            expiryDate: hasExpiryDate ? expiryDate : nil,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        onSave(doc)
        dismiss()
    }
}
