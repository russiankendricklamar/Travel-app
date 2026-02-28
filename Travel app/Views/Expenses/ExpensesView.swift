import SwiftUI
import SwiftData

struct ExpensesView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false

    private var sortedExpenses: [Expense] {
        trip.expenses.sorted { $0.date > $1.date }
    }

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }

    private func formatYen(_ amount: Double) -> String {
        let formatted = currencyFormatter.string(from: NSNumber(value: Int(amount))) ?? "0"
        return "\u{00A5}\(formatted)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    summarySection
                    categoryBreakdown
                    expensesList
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingXL)
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 12, height: 3)
                        Text("РАСХОДЫ")
                            .font(.system(size: 14, weight: .black))
                            .tracking(4)
                            .foregroundStyle(AppTheme.textPrimary)
                        Rectangle()
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 12, height: 3)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddExpenseSheet(trip: trip)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ПОТРАЧЕНО")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(AppTheme.textMuted)
                    Text(formatYen(trip.totalSpent))
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.toriiRed)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.spacingM)

                ZStack {
                    ProgressRing(
                        progress: trip.budgetUsedPercent,
                        color: trip.budgetUsedPercent > 0.9 ? AppTheme.toriiRed : AppTheme.bambooGreen,
                        lineWidth: 6,
                        size: 60
                    )
                    Text("\(Int(trip.budgetUsedPercent * 100))%")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.vertical, AppTheme.spacingS)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("ОСТАТОК")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(AppTheme.textMuted)
                    Text(formatYen(trip.remainingBudget))
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(trip.remainingBudget >= 0 ? AppTheme.bambooGreen : AppTheme.toriiRed)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(AppTheme.spacingM)
            }
            .background(AppTheme.card)

            HStack {
                Text("БЮДЖЕТ")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(formatYen(trip.budget))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, 6)
            .background(AppTheme.sakuraPink)
        }
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(spacing: 0) {
            BoldSectionHeader(title: "ПО КАТЕГОРИЯМ", color: AppTheme.card)
                .overlay(
                    Rectangle().fill(AppTheme.templeGold).frame(width: 4),
                    alignment: .leading
                )
                .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1))

            let maxAmount = trip.expensesByCategory.first?.total ?? 1

            ForEach(Array(trip.expensesByCategory.enumerated()), id: \.element.category) { index, item in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(AppTheme.expenseColor(for: item.category))
                        .frame(width: 5)
                    HStack(spacing: AppTheme.spacingS) {
                        Image(systemName: item.category.systemImage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.expenseColor(for: item.category))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.category.rawValue.uppercased())
                                .font(.system(size: 10, weight: .black))
                                .tracking(1)
                                .foregroundStyle(AppTheme.textPrimary)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(AppTheme.surface)
                                    Rectangle()
                                        .fill(AppTheme.expenseColor(for: item.category).opacity(0.35))
                                        .frame(width: geo.size.width * (item.total / maxAmount))
                                }
                            }
                            .frame(height: 4)
                        }
                        Spacer()
                        Text(formatYen(item.total))
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, AppTheme.spacingS)
                    .padding(.vertical, 10)
                }
                .background(index % 2 == 0 ? AppTheme.card : AppTheme.surface)
            }
        }
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
    }

    // MARK: - Expenses List

    private var expensesList: some View {
        VStack(spacing: 0) {
            BoldSectionHeader(title: "ВСЕ РАСХОДЫ", color: AppTheme.card)
                .overlay(
                    Rectangle().fill(AppTheme.sakuraPink).frame(width: 4),
                    alignment: .leading
                )
                .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1))

            ForEach(Array(sortedExpenses.enumerated()), id: \.element.id) { index, expense in
                expenseRow(expense, index: index)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(expense)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
            }
        }
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
    }

    private func expenseRow(_ expense: Expense, index: Int) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.expenseColor(for: expense.category))
                .frame(width: 4)
            HStack(spacing: AppTheme.spacingS) {
                Image(systemName: expense.category.systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.expenseColor(for: expense.category))
                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.title.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: AppTheme.spacingXS) {
                        Text(expense.category.rawValue.uppercased())
                            .font(.system(size: 8, weight: .black))
                            .tracking(1)
                            .foregroundStyle(AppTheme.expenseColor(for: expense.category))
                        Rectangle()
                            .fill(AppTheme.textMuted)
                            .frame(width: 1, height: 8)
                        Text(expense.date, style: .date)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                Spacer()
                Text(formatYen(expense.amount))
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, AppTheme.spacingS)
            .padding(.vertical, 10)
        }
        .background(index % 2 == 0 ? AppTheme.card : AppTheme.surface)
    }
}

#if DEBUG
#Preview {
    ExpensesView(trip: .preview)
        .modelContainer(.preview)
}
#endif
