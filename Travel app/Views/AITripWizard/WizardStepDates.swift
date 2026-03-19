import SwiftUI

struct WizardStepDates: View {
    @Binding var startDate: Date
    @Binding var endDate: Date

    let destination: String
    var onNext: () -> Void

    @State private var seasonHint: String?
    @State private var isLoadingHint = false

    private var daysCount: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                stepHeader

                datePickersSection

                daysCountBadge

                seasonHintSection

                Spacer(minLength: 40)

                nextButton
            }
            .padding(AppTheme.spacingM)
        }
        .task(id: destination) { loadSeasonHint() }
        .onChange(of: startDate) { _, _ in loadSeasonHint() }
    }

    // MARK: - Header

    private var stepHeader: some View {
        VStack(spacing: AppTheme.spacingS) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.sakuraPink)
            Text("Когда едем?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
            Text("Выберите даты поездки в \(destination)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.spacingXL)
    }

    // MARK: - Date Pickers

    private var datePickersSection: some View {
        HStack(spacing: AppTheme.spacingS) {
            GlassFormField(label: "НАЧАЛО", color: AppTheme.bambooGreen) {
                DatePicker("", selection: $startDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(AppTheme.sakuraPink)
            }
            GlassFormField(label: "КОНЕЦ", color: AppTheme.toriiRed) {
                DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(AppTheme.sakuraPink)
            }
        }
    }

    // MARK: - Days Badge

    private var daysCountBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.sakuraPink)
            Text("\(daysCount) " + daysWord(daysCount))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, AppTheme.spacingL)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.sakuraPink.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Season Hint

    @ViewBuilder
    private var seasonHintSection: some View {
        if isLoadingHint {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(AppTheme.sakuraPink)
                Text("Анализируем сезон...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(AppTheme.spacingM)
        }

        if let hint = seasonHint {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.sakuraPink)
                    Text("AI О СЕЗОНЕ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
            )
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

    // MARK: - Helpers

    private func loadSeasonHint() {
        guard !destination.isEmpty else { return }
        isLoadingHint = true
        let fmt = DateFormatter()
        fmt.dateFormat = "LLLL"
        fmt.locale = Locale(identifier: "ru_RU")
        let monthName = fmt.string(from: startDate)

        Task {
            let hint = await AITripGeneratorService.shared.seasonHint(
                destination: destination,
                month: monthName
            )
            seasonHint = hint
            isLoadingHint = false
        }
    }

    private func daysWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 14 { return "дней" }
        if mod10 == 1 { return "день" }
        if mod10 >= 2 && mod10 <= 4 { return "дня" }
        return "дней"
    }
}
