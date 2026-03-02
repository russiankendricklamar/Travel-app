import SwiftUI

struct DashboardActiveSection: View {
    let trip: Trip
    let heroScale: CGFloat
    let statsOffset: CGFloat
    let counterValue: Int
    let budgetWidth: CGFloat

    var body: some View {
        VStack(spacing: AppTheme.spacingM) {
            heroSection
            statsBanner
            statsCards
            DashboardBudgetSection(trip: trip, budgetWidth: budgetWidth)
            recentExpensesSection
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            ZStack {
                Text("\(counterValue)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.sakuraPink.opacity(0.08))
                    .blur(radius: 30)

                Text("\(counterValue)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .shadow(color: AppTheme.sakuraPink.opacity(0.25), radius: 20, x: 0, y: 10)
            }

            HStack(spacing: 8) {
                Capsule()
                    .fill(AppTheme.sakuraPink.opacity(0.3))
                    .frame(height: 1.5)
                Text("ДЕНЬ ПУТЕШЕСТВИЯ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(AppTheme.sakuraPink)
                    .fixedSize()
                Capsule()
                    .fill(AppTheme.sakuraPink.opacity(0.3))
                    .frame(height: 1.5)
            }
            .padding(.horizontal, AppTheme.spacingL)

            Spacer(minLength: 12)

            Text(trip.name.uppercased())
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(tripDateRange.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            Spacer(minLength: 16)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusXL)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink.opacity(0.4), AppTheme.sakuraPink.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: AppTheme.sakuraPink.opacity(0.12), radius: 20, x: 0, y: 10)
        .padding(.top, 8)
        .scaleEffect(heroScale)
    }

    // MARK: - Stats Banner

    private var statsBanner: some View {
        HStack(spacing: 0) {
            bannerStat("\(trip.placesVisitedCount)/\(trip.totalPlacesCount)", label: "МЕСТ", icon: "mappin.and.ellipse")
            Divider().frame(height: 40)
            bannerStat("\(uniqueCities.count)", label: "ГОРОДОВ", icon: "building.2")
            Divider().frame(height: 40)
            bannerStat(formatRub(trip.totalSpent), label: "ПОТРАЧЕНО", icon: "rublesign")
        }
        .padding(.vertical, AppTheme.spacingM)
        .background(AppTheme.sakuraPink.opacity(0.12))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.sakuraPink.opacity(0.2), lineWidth: 0.5)
        )
        .offset(y: statsOffset)
    }

    private func bannerStat(_ value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.sakuraPink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: AppTheme.spacingS) {
            glassStatCard(
                value: "\(trip.days.count)",
                label: "ДНЕЙ",
                icon: "calendar",
                color: AppTheme.sakuraPink
            )
            glassStatCard(
                value: "\(Int(trip.budgetUsedPercent * 100))%",
                label: "БЮДЖЕТА",
                icon: "chart.bar.fill",
                color: AppTheme.templeGold
            )
        }
        .offset(y: statsOffset)
    }

    private func glassStatCard(value: String, label: String, icon: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color.opacity(0.2))
        }
        .padding(AppTheme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(color.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    // MARK: - Recent Expenses

    private var recentExpensesSection: some View {
        Group {
            if !trip.recentExpenses.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    HStack {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppTheme.sakuraPink)
                                .frame(width: 4, height: 16)
                            Text("ПОСЛЕДНИЕ РАСХОДЫ")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(AppTheme.sakuraPink)
                        }
                        Spacer()
                        Text("\(trip.recentExpenses.count)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.sakuraPink.opacity(0.4))
                    }
                    .padding(.horizontal, 4)

                    ForEach(Array(trip.recentExpenses.enumerated()), id: \.element.id) { index, expense in
                        expenseRow(index: index, expense: expense)
                    }
                }
            }
        }
    }

    private func expenseRow(index: Int, expense: Expense) -> some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: expense.category.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [AppTheme.expenseColor(for: expense.category), AppTheme.expenseColor(for: expense.category).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(expense.category.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatRub(expense.amount))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private var uniqueCities: [String] {
        Array(Set(trip.days.map(\.cityName))).sorted()
    }

    private var tripDateRange: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: trip.startDate)
        let end = formatter.string(from: trip.endDate)
        return "\(start) – \(end) // \(trip.totalDays) дн."
    }

    private func formatRub(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        let formatted = formatter.string(from: NSNumber(value: Int(amount))) ?? "0"
        return "\u{20BD}\(formatted)"
    }
}
