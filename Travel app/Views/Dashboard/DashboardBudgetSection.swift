import SwiftUI

struct DashboardBudgetSection: View {
    let trip: Trip
    let budgetWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "\(CurrencyService.baseCurrencyIcon).circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink)
                    Text("БЮДЖЕТ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                Spacer()
                Text(CurrencyService.formatBase(trip.budget))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(AppTheme.spacingM)

            // Budget bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [budgetBarColor, budgetBarColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * budgetWidth)

                    Text("\(Int(trip.budgetUsedPercent * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .padding(.leading, 12)
                }
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, AppTheme.spacingM)

            // Spent / Remaining
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ПОТРАЧЕНО")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.tertiary)
                    Text(CurrencyService.formatBase(trip.totalSpent))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.toriiRed)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.spacingS)

                Divider().frame(height: 30)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("ОСТАТОК")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.tertiary)
                    Text(CurrencyService.formatBase(trip.remainingBudget))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(trip.remainingBudget >= 0 ? AppTheme.bambooGreen : AppTheme.toriiRed)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(AppTheme.spacingS)
            }
            .padding(.horizontal, AppTheme.spacingS)

            // Categories
            if !trip.expensesByCategory.isEmpty {
                let maxAmount = trip.expensesByCategory.first?.total ?? 1
                VStack(spacing: 6) {
                    ForEach(trip.expensesByCategory, id: \.category) { item in
                        categoryRow(item: item, maxAmount: maxAmount)
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingM)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    private func categoryRow(item: (category: ExpenseCategory, total: Double), maxAmount: Double) -> some View {
        let color = AppTheme.expenseColor(for: item.category)
        return HStack(spacing: 8) {
            Image(systemName: item.category.systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(item.category.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.4))
                        .frame(width: geo.size.width * (item.total / maxAmount))
                }
            }
            .frame(height: 8)

            Text(CurrencyService.formatBase(item.total))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    private var budgetBarColor: Color {
        if trip.budgetUsedPercent > 0.9 { return AppTheme.toriiRed }
        if trip.budgetUsedPercent > 0.7 { return AppTheme.templeGold }
        return AppTheme.bambooGreen
    }
}
