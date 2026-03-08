import SwiftUI

struct AddLoyaltySheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    @State private var company: String = ""
    @State private var programName: String = ""
    @State private var memberNumber: String = ""
    @State private var tier: String = ""

    let onSave: (LoyaltyProgram) -> Void

    private var accent: Color {
        (ColorPalette(rawValue: palette) ?? .sakura).accentColor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingS) {
                    // Company
                    GlassFormField(label: "КОМПАНИЯ", color: AppTheme.indigoPurple) {
                        TextField("Аэрофлот, Hilton...", text: $company)
                            .textFieldStyle(GlassTextFieldStyle())
                            .font(.system(size: 14))
                    }

                    // Program name
                    GlassFormField(label: "ПРОГРАММА", color: AppTheme.indigoPurple) {
                        TextField("Аэрофлот Бонус, Hilton Honors...", text: $programName)
                            .textFieldStyle(GlassTextFieldStyle())
                            .font(.system(size: 14))
                    }

                    // Member number
                    GlassFormField(label: "НОМЕР УЧАСТНИКА", color: accent) {
                        TextField("Номер карты / участника", text: $memberNumber)
                            .textFieldStyle(GlassTextFieldStyle())
                            .font(.system(size: 14))
                            .autocorrectionDisabled()
                    }

                    // Tier
                    GlassFormField(label: "УРОВЕНЬ", color: AppTheme.templeGold) {
                        TextField("Gold, Platinum, Silver...", text: $tier)
                            .textFieldStyle(GlassTextFieldStyle())
                            .font(.system(size: 14))
                    }

                    // Save button
                    Button {
                        saveLoyalty()
                    } label: {
                        Text("СОХРАНИТЬ")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.indigoPurple, AppTheme.indigoPurple.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.indigoPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(company.trimmingCharacters(in: .whitespaces).isEmpty || memberNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity((company.trimmingCharacters(in: .whitespaces).isEmpty || memberNumber.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.5 : 1)
                    .padding(.top, AppTheme.spacingS)

                    Spacer(minLength: 40)
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationTitle("Программа лояльности")
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

    private func saveLoyalty() {
        let program = LoyaltyProgram(
            company: company.trimmingCharacters(in: .whitespaces),
            programName: programName.trimmingCharacters(in: .whitespaces),
            memberNumber: memberNumber.trimmingCharacters(in: .whitespaces),
            tier: tier.trimmingCharacters(in: .whitespaces)
        )
        onSave(program)
        dismiss()
    }
}
