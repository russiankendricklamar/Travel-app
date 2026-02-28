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
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "mappin.circle.fill",
                        title: editing != nil ? "РЕДАКТИРОВАТЬ МЕСТО" : "НОВОЕ МЕСТО",
                        color: AppTheme.sakuraPink
                    )

                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Храм Сэнсо-дзи", text: $name)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    GlassFormField(label: "ЯПОНСКОЕ НАЗВАНИЕ", color: AppTheme.templeGold) {
                        TextField("浅草寺", text: $nameJapanese)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    GlassFormField(label: "КАТЕГОРИЯ", color: AppTheme.oceanBlue) {
                        categoryPicker
                    }
                    GlassFormField(label: "АДРЕС", color: .secondary) {
                        TextField("Адрес", text: $address)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    HStack(spacing: AppTheme.spacingS) {
                        GlassFormField(label: "ШИРОТА", color: .secondary) {
                            TextField("35.7148", text: $latitude)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                        GlassFormField(label: "ДОЛГОТА", color: .secondary) {
                            TextField("139.7967", text: $longitude)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(GlassTextFieldStyle())
                        }
                    }
                    GlassFormField(label: "ВРЕМЯ НА ПОСЕЩЕНИЕ", color: AppTheme.sakuraPink) {
                        TextField("1,5 ч", text: $timeToSpend)
                            .textFieldStyle(GlassTextFieldStyle())
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
            HStack(spacing: 6) {
                ForEach(Array(PlaceCategory.allCases), id: \.self) { (cat: PlaceCategory) in
                    let color = AppTheme.categoryColor(for: cat.rawValue)
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
                        .background(category == cat ? color : .clear)
                        .background { if category != cat { Color.clear.background(.ultraThinMaterial) } }
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                category == cat ? color.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: 0.5
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
