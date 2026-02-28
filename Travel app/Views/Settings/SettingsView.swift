import SwiftUI
import SwiftData

struct SettingsView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Palette
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    // Notifications
    @AppStorage("notif_morning") private var notifMorning = true
    @AppStorage("notif_event") private var notifEvent = true
    @AppStorage("notif_budget") private var notifBudget = true

    // Currency
    @AppStorage("preferredCurrency") private var currency = "JPY"

    @State private var showResetConfirmation = false

    private var selectedPalette: ColorPalette {
        ColorPalette(rawValue: palette) ?? .sakura
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    paletteSection
                    notificationSection
                    currencySection
                    languageSection
                    dataSection
                    aboutSection
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .confirmationDialog(
                "Сбросить все данные?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить всё", role: .destructive) {
                    resetAllData()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это удалит все поездки, расходы и записи. Действие нельзя отменить.")
            }
        }
    }

    // MARK: - Palette Section

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ПАЛИТРА", icon: "paintbrush.fill")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                ForEach(ColorPalette.allCases) { p in
                    paletteOption(p)
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func paletteOption(_ p: ColorPalette) -> some View {
        let isSelected = selectedPalette == p
        return Button {
            withAnimation(.spring(response: 0.3)) {
                palette = p.rawValue
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(
                            LinearGradient(
                                colors: p.backgroundColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                .stroke(isSelected ? p.accentColor : Color.clear, lineWidth: 2)
                        )

                    Circle()
                        .fill(p.accentColor)
                        .frame(width: 16, height: 16)
                        .shadow(color: p.accentColor.opacity(0.5), radius: 4, x: 0, y: 2)
                }

                Text(p.label)
                    .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? AppTheme.sakuraPink : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("УВЕДОМЛЕНИЯ", icon: "bell.fill")

            notifToggle(
                title: "Утренний план",
                subtitle: "Каждый день в 8:00",
                icon: "sunrise.fill",
                color: AppTheme.templeGold,
                isOn: $notifMorning
            )
            notifToggle(
                title: "Напоминания о событиях",
                subtitle: "За 30 мин до начала",
                icon: "clock.fill",
                color: AppTheme.sakuraPink,
                isOn: $notifEvent
            )
            notifToggle(
                title: "Бюджет",
                subtitle: "Когда потрачено > 80%",
                icon: "yensign.circle.fill",
                color: AppTheme.toriiRed,
                isOn: $notifBudget
            )
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func notifToggle(title: String, subtitle: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.sakuraPink)
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }

    // MARK: - Currency Section

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ВАЛЮТА", icon: "banknote.fill")

            HStack(spacing: 8) {
                ForEach(["JPY", "USD", "EUR", "RUB"], id: \.self) { code in
                    currencyButton(code)
                }
            }

            Text("Только для отображения. Суммы хранятся в JPY.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func currencyButton(_ code: String) -> some View {
        let isSelected = currency == code
        let symbols: [String: String] = ["JPY": "\u{00A5}", "USD": "$", "EUR": "\u{20AC}", "RUB": "\u{20BD}"]
        return Button {
            withAnimation(.spring(response: 0.3)) { currency = code }
        } label: {
            VStack(spacing: 4) {
                Text(symbols[code] ?? code)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(code)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? AppTheme.sakuraPink : Color.clear)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(isSelected ? AppTheme.sakuraPink : Color.white.opacity(0.15), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
    }

    // MARK: - Language Section

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ЯЗЫК", icon: "globe")

            HStack(spacing: 12) {
                Image(systemName: "textformat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.sakuraPink)
                    .frame(width: 34, height: 34)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                Text("Русский")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.sakuraPink)
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ДАННЫЕ", icon: "externaldrive.fill")

            Button {
                showResetConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.toriiRed, AppTheme.toriiRed.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Сбросить все данные")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.toriiRed)
                        Text("Удалить поездки, расходы и записи")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.sakuraPink.opacity(0.3), AppTheme.sakuraPink.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                Text("JP")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.sakuraPink)
            }

            Text("Japan Travel")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)

            Text("v1.0.0")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("Сделано с \u{2764}\u{FE0F} для Японии")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingL)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink)
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(AppTheme.sakuraPink)
        }
    }

    private func resetAllData() {
        do {
            try modelContext.delete(model: Trip.self)
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        } catch {
            // Silently handle — data reset is best-effort
        }
    }
}
