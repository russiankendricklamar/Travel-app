import SwiftUI
import SwiftData

struct EditCountriesSheet: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var countries: [String] = []
    @State private var currentInput = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "globe",
                        title: "СТРАНЫ",
                        color: AppTheme.oceanBlue
                    )

                    // Current countries
                    if !countries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(countries, id: \.self) { name in
                                countryRow(name)
                            }
                        }
                    } else {
                        Text("Нет стран")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.spacingL)
                    }

                    // Add new country
                    HStack(spacing: 8) {
                        TextField("Добавить страну", text: $currentInput)
                            .textFieldStyle(GlassTextFieldStyle())
                            .onSubmit { addCountry() }
                        Button {
                            addCountry()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(AppTheme.oceanBlue)
                        }
                        .disabled(currentInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(currentInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
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
                    Button("СОХРАНИТЬ") { save() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.sakuraPink)
                        .disabled(countries.isEmpty)
                        .opacity(countries.isEmpty ? 0.4 : 1)
                }
            }
            .onAppear {
                countries = trip.countries
            }
        }
    }

    private func countryRow(_ name: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.oceanBlue)
                .frame(width: 24)

            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.25)) {
                    countries.removeAll { $0 == name }
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.toriiRed.opacity(0.7))
            }
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color(AppTheme.oceanBlue).opacity(0.15), lineWidth: 0.5)
        }
    }

    private func addCountry() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let capitalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        if !countries.contains(where: { $0.lowercased() == capitalized.lowercased() }) {
            withAnimation(.spring(response: 0.25)) {
                countries.append(capitalized)
            }
        }
        currentInput = ""
    }

    private func save() {
        trip.countries = countries
        trip.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            // Save failed silently
        }
        dismiss()
    }
}
