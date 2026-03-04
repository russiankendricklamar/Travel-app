import SwiftUI
import SwiftData

struct AddPackingItemSheet: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: PackingCategory = .other
    @State private var quantity: Int = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(icon: "bag.fill", title: "ДОБАВИТЬ ВЕЩЬ", color: AppTheme.oceanBlue)

                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Зарядка", text: $name)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    GlassFormField(label: "КАТЕГОРИЯ", color: AppTheme.templeGold) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(PackingCategory.allCases) { cat in
                                    let isSelected = category == cat
                                    Button {
                                        withAnimation(.spring(response: 0.3)) { category = cat }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: cat.systemImage)
                                                .font(.system(size: 11, weight: .bold))
                                            Text(cat.label)
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(isSelected ? .white : .secondary)
                                        .background(isSelected ? AppTheme.sakuraPink : Color.clear)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(
                                                isSelected ? AppTheme.sakuraPink.opacity(0.5) : Color.white.opacity(0.2),
                                                lineWidth: 0.5
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }

                    GlassFormField(label: "КОЛИЧЕСТВО", color: AppTheme.oceanBlue) {
                        HStack {
                            Stepper("\(quantity)", value: $quantity, in: 1...99)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .padding(8)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ОТМЕНА") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ДОБАВИТЬ") { save() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.sakuraPink)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1.0)
                }
            }
        }
    }

    private func save() {
        let item = PackingItem(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category.rawValue,
            quantity: quantity,
            sortOrder: trip.packingItems.count
        )
        item.trip = trip
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}
