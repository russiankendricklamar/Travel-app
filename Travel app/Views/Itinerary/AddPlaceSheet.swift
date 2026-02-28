import SwiftUI
import SwiftData

struct AddPlaceSheet: View {
    let day: TripDay
    var editing: Place?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var nameJapanese = ""
    @State private var category: PlaceCategory = .culture
    @State private var address = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var timeToSpend = ""
    @State private var notes = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppTheme.spacingM) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(editing != nil ? "РЕДАКТИРОВАТЬ МЕСТО" : "НОВОЕ МЕСТО")
                                .font(.system(size: 12, weight: .black))
                                .tracking(3)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.sakuraPink)

                        SakuraFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                            TextField("Храм Сэнсо-дзи", text: $name)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }
                        SakuraFormField(label: "ЯПОНСКОЕ НАЗВАНИЕ", color: AppTheme.templeGold) {
                            TextField("浅草寺", text: $nameJapanese)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }
                        SakuraFormField(label: "КАТЕГОРИЯ", color: AppTheme.oceanBlue) {
                            categoryPicker
                        }
                        SakuraFormField(label: "АДРЕС", color: AppTheme.textMuted) {
                            TextField("Адрес", text: $address)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }
                        HStack(spacing: AppTheme.spacingS) {
                            SakuraFormField(label: "ШИРОТА", color: AppTheme.textMuted) {
                                TextField("35.7148", text: $latitude)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(SakuraTextFieldStyle())
                            }
                            SakuraFormField(label: "ДОЛГОТА", color: AppTheme.textMuted) {
                                TextField("139.7967", text: $longitude)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(SakuraTextFieldStyle())
                            }
                        }
                        SakuraFormField(label: "ВРЕМЯ НА ПОСЕЩЕНИЕ", color: AppTheme.sakuraPink) {
                            TextField("1,5 ч", text: $timeToSpend)
                                .textFieldStyle(SakuraTextFieldStyle())
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
                if let p = editing {
                    name = p.name
                    nameJapanese = p.nameJapanese
                    category = p.category
                    address = p.address
                    latitude = String(p.latitude)
                    longitude = String(p.longitude)
                    timeToSpend = p.timeToSpend
                    notes = p.notes
                }
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(PlaceCategory.allCases) { cat in
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
                        .background(category == cat ? AppTheme.categoryColor(for: cat.rawValue) : AppTheme.surface)
                        .overlay(
                            Rectangle().stroke(
                                category == cat ? AppTheme.categoryColor(for: cat.rawValue) : AppTheme.border,
                                lineWidth: category == cat ? 2 : 1
                            )
                        )
                    }
                }
            }
        }
    }

    private func save() {
        let lat = Double(latitude) ?? 35.6762
        let lon = Double(longitude) ?? 139.6503

        if let p = editing {
            p.name = name.trimmingCharacters(in: .whitespaces)
            p.nameJapanese = nameJapanese.trimmingCharacters(in: .whitespaces)
            p.category = category
            p.address = address.trimmingCharacters(in: .whitespaces)
            p.latitude = lat
            p.longitude = lon
            p.timeToSpend = timeToSpend.trimmingCharacters(in: .whitespaces)
            p.notes = notes.trimmingCharacters(in: .whitespaces)
        } else {
            let place = Place(
                name: name.trimmingCharacters(in: .whitespaces),
                nameJapanese: nameJapanese.trimmingCharacters(in: .whitespaces),
                category: category,
                address: address.trimmingCharacters(in: .whitespaces),
                latitude: lat,
                longitude: lon,
                notes: notes.trimmingCharacters(in: .whitespaces),
                timeToSpend: timeToSpend.trimmingCharacters(in: .whitespaces)
            )
            day.places.append(place)
        }
        dismiss()
    }
}
