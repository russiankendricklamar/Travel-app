import SwiftUI
import SwiftData

struct ExpensesView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false
    @State private var showingBudgetEdit = false
    @State private var budgetInput = ""
    @State private var editingExpense: Expense?

    @AppStorage("preferredCurrency") private var preferredCurrency = "RUB"
    @AppStorage("notif_budget") private var notifBudget = true

    private var sortedExpenses: [Expense] {
        trip.expenses.sorted { $0.date > $1.date }
    }

    private var currency: CurrencyService { CurrencyService.shared }

    private func formatAmount(_ amount: Double) -> String {
        currency.format(amount, currency: preferredCurrency)
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
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("РАСХОДЫ")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
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
            .sheet(item: $editingExpense) { expense in
                AddExpenseSheet(trip: trip, editing: expense)
            }
            .alert("Изменить бюджет", isPresented: $showingBudgetEdit) {
                TextField("Сумма в \(preferredCurrency)", text: $budgetInput)
                    .keyboardType(.numberPad)
                Button("Сохранить") {
                    if let value = Double(budgetInput), value > 0 {
                        trip.budget = value
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Введите новый бюджет поездки в \(preferredCurrency)")
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: AppTheme.spacingS) {
        VStack(spacing: AppTheme.spacingS) {
            HStack(spacing: AppTheme.spacingM) {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ПОТРАЧЕНО")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(.tertiary)
                        Text(formatAmount(trip.totalSpent))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.toriiRed)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ОСТАТОК")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(.tertiary)
                        Text(formatAmount(trip.remainingBudget))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(trip.remainingBudget >= 0 ? AppTheme.bambooGreen : AppTheme.toriiRed)
                    }
                }

                Spacer()

                ZStack {
                    ProgressRing(
                        progress: trip.budgetUsedPercent,
                        color: trip.budgetUsedPercent > 0.9 ? AppTheme.toriiRed : AppTheme.bambooGreen,
                        lineWidth: 6,
                        size: 70
                    )
                    Text("\(Int(trip.budgetUsedPercent * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .padding(AppTheme.spacingM)

            Button {
                budgetInput = "\(Int(trip.budget))"
                showingBudgetEdit = true
            } label: {
                HStack {
                    Text("БЮДЖЕТ")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(formatAmount(trip.budget))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)

        // Budget notification toggle
        HStack(spacing: 12) {
            Image(systemName: "\(CurrencyService.baseCurrencyIcon).circle.fill")
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
                Text("Уведомление о бюджете")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Когда потрачено > 80%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $notifBudget)
                .labelsHidden()
                .tint(AppTheme.sakuraPink)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(spacing: 0) {
            GlassSectionHeader(title: "ПО КАТЕГОРИЯМ", color: AppTheme.templeGold)

            let maxAmount = trip.expensesByCategory.first?.total ?? 1

            VStack(spacing: 8) {
                ForEach(trip.expensesByCategory, id: \.category) { item in
                    let color = AppTheme.expenseColor(for: item.category)
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: item.category.systemImage)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(color)
                                .clipShape(RoundedRectangle(cornerRadius: 7))

                            Text(item.category.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer()

                            Text(formatAmount(item.total))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(color.opacity(0.1))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(color.opacity(0.4))
                                    .frame(width: geo.size.width * (item.total / maxAmount))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingM)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    // MARK: - Expenses List

    private var expensesList: some View {
        VStack(spacing: 0) {
            GlassSectionHeader(title: "ВСЕ РАСХОДЫ", color: AppTheme.sakuraPink)

            VStack(spacing: 6) {
                ForEach(sortedExpenses) { expense in
                    expenseRow(expense)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingExpense = expense
                        }
                        .contextMenu {
                            Button {
                                editingExpense = expense
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                modelContext.delete(expense)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingM)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func expenseRow(_ expense: Expense) -> some View {
        let color = AppTheme.expenseColor(for: expense.category)
        return HStack(spacing: AppTheme.spacingS) {
            Image(systemName: expense.category.systemImage)
                .font(.system(size: 14, weight: .bold))
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
                Text(expense.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: AppTheme.spacingXS) {
                    Text(expense.category.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(color)
                    Text(expense.date, style: .date)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(formatAmount(expense.amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}

#if DEBUG
#Preview {
    ExpensesView(trip: .preview)
        .modelContainer(.preview)
}
#endif
