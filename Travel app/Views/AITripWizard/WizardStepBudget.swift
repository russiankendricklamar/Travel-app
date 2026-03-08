import SwiftUI

struct WizardStepBudget: View {
    @Binding var budget: Double?

    var onNext: () -> Void

    @State private var customBudgetText = ""

    private let presets: [(label: String, value: Double?)] = [
        ("Эконом", 50_000),
        ("Средний", 150_000),
        ("Без ограничений", nil)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                stepHeader
                presetsSection
                customField

                Spacer(minLength: 40)

                nextButton
            }
            .padding(AppTheme.spacingM)
        }
    }

    // MARK: - Header

    private var stepHeader: some View {
        VStack(spacing: AppTheme.spacingS) {
            Image(systemName: "rublesign.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.sakuraPink)
            Text("Бюджет")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
            Text("На сколько рассчитываете?")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.top, AppTheme.spacingXL)
    }

    // MARK: - Presets

    private var presetsSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                let isSelected = budget == preset.value && customBudgetText.isEmpty
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        budget = preset.value
                        customBudgetText = ""
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.label)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.primary)
                            if let value = preset.value {
                                Text("\(Int(value)) \u{20BD}")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isSelected ? AppTheme.sakuraPink : Color.gray.opacity(0.4))
                    }
                    .padding(AppTheme.spacingM)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                            .stroke(isSelected ? AppTheme.sakuraPink.opacity(0.4) : Color.white.opacity(0.2), lineWidth: isSelected ? 1 : 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Custom Field

    private var customField: some View {
        GlassFormField(label: "СВОЯ СУММА", color: AppTheme.templeGold) {
            TextField("Введите сумму", text: $customBudgetText)
                .keyboardType(.numberPad)
                .textFieldStyle(GlassTextFieldStyle())
                .onChange(of: customBudgetText) { _, newValue in
                    if let val = Double(newValue), val > 0 {
                        budget = val
                    }
                }
        }
    }

    // MARK: - Next Button

    private var nextButton: some View {
        Button {
            onNext()
        } label: {
            Text("ДАЛЕЕ")
                .font(.system(size: 14, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.sakuraPink)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        }
        .padding(.bottom, AppTheme.spacingM)
    }
}
