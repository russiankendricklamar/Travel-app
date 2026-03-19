import SwiftUI
import SwiftData

struct ExpensesView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false
    @State private var showingBudgetSources = false
    @State private var editingExpense: Expense?
    @State private var showAllExpenses = false
    @State private var quickTemplate: QuickTemplate?

    @AppStorage("preferredCurrency") private var preferredCurrency = "RUB"
    @AppStorage("notif_budget") private var notifBudget = true
    @State private var showReceiptScanner = false
    @State private var expandedCategory: ExpenseCategory?

    private var recentExpenses: [Expense] {
        Array(trip.expenses.sorted { $0.updatedAt > $1.updatedAt }.prefix(10))
    }

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
                    quickAddSection
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
                    HStack(spacing: 12) {
                        Button { showReceiptScanner = true } label: {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 18))
                                .foregroundStyle(AppTheme.templeGold)
                        }
                        Button { showingAddSheet = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.sakuraPink)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddExpenseSheet(trip: trip)
            }
            .sheet(item: $quickTemplate) { template in
                AddExpenseSheet(
                    trip: trip,
                    prefillTitle: template.title,
                    prefillCategory: template.category
                )
            }
            .sheet(item: $editingExpense) { expense in
                AddExpenseSheet(trip: trip, editing: expense)
            }
            .sheet(isPresented: $showingBudgetSources) {
                BudgetSourcesSheet(trip: trip)
            }
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScannerSheet { scanned in
                    let expense = Expense(
                        title: scanned.title,
                        amount: scanned.amount,
                        category: scanned.category,
                        date: scanned.date,
                        originalAmount: scanned.amount,
                        originalCurrency: scanned.currency,
                        exchangeRate: 1.0
                    )
                    trip.expenses.append(expense)
                    try? modelContext.save()
                }
            }
        }
    }

    // MARK: - Quick Add (dynamic from expense history)

    private struct QuickTemplate: Identifiable {
        let id: String
        let title: String
        let category: ExpenseCategory
        let count: Int
    }

    private var quickTemplates: [QuickTemplate] {
        let all = trip.expenses
        guard !all.isEmpty else { return [] }

        var groups: [String: (category: ExpenseCategory, count: Int)] = [:]
        for e in all {
            let key = e.title.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            if let group = groups[key] {
                groups[key] = (category: group.category, count: group.count + 1)
            } else {
                groups[key] = (category: e.category, count: 1)
            }
        }

        return groups
            .filter { $0.value.count >= 3 }
            .map { (key, val) in
                let originalTitle = all
                    .last { $0.title.trimmingCharacters(in: .whitespaces).lowercased() == key }?
                    .title ?? key
                return QuickTemplate(id: key, title: originalTitle, category: val.category, count: val.count)
            }
            .sorted { $0.count > $1.count }
            .prefix(8)
            .map { $0 }
    }

    @ViewBuilder
    private var quickAddSection: some View {
        if !quickTemplates.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("ЧАСТЫЕ")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                }
                .foregroundStyle(.tertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickTemplates) { template in
                            quickChip(template)
                        }
                    }
                }
            }
        }
    }

    private func quickChip(_ template: QuickTemplate) -> some View {
        let color = AppTheme.expenseColor(for: template.category)
        return Button { quickTemplate = template } label: {
            HStack(spacing: 5) {
                Image(systemName: template.category.systemImage)
                    .font(.system(size: 10, weight: .bold))
                Text(template.title)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: color.opacity(0.3), radius: 4, y: 2)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: AppTheme.spacingS) {
            // Main stats card
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

                // Budget sources button
                Button { showingBudgetSources = true } label: {
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: "wallet.bifold.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("БЮДЖЕТ")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(2)
                            Spacer()
                            Text(formatAmount(trip.effectiveBudget))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .opacity(0.6)
                        }
                        .foregroundStyle(.white)

                        // Multi-currency chips
                        if !trip.budgetSources.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(trip.budgetSources) { source in
                                        HStack(spacing: 3) {
                                            Image(systemName: source.icon)
                                                .font(.system(size: 8, weight: .bold))
                                            Text(currency.format(source.amount, currency: source.currency))
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.white.opacity(0.2))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.templeGold, AppTheme.templeGold.opacity(0.8)],
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

    private struct MerchantGroup: Identifiable {
        let id: String
        let title: String
        let total: Double
        let count: Int
    }

    private func merchantGroups(for category: ExpenseCategory) -> [MerchantGroup] {
        let categoryExpenses = trip.expenses.filter { $0.category == category }
        var groups: [String: (title: String, total: Double, count: Int)] = [:]
        for e in categoryExpenses {
            let key = e.title.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            if let g = groups[key] {
                groups[key] = (title: g.title, total: g.total + e.amount, count: g.count + 1)
            } else {
                groups[key] = (title: e.title, total: e.amount, count: 1)
            }
        }
        return groups
            .map { MerchantGroup(id: $0.key, title: $0.value.title, total: $0.value.total, count: $0.value.count) }
            .sorted { $0.total > $1.total }
    }

    private var categoryBreakdown: some View {
        VStack(spacing: 0) {
            GlassSectionHeader(title: "ПО КАТЕГОРИЯМ", color: AppTheme.templeGold)

            let maxAmount = trip.expensesByCategory.first?.total ?? 1

            VStack(spacing: 8) {
                ForEach(trip.expensesByCategory, id: \.category) { item in
                    let color = AppTheme.expenseColor(for: item.category)
                    let isExpanded = expandedCategory == item.category

                    VStack(spacing: 6) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                expandedCategory = isExpanded ? nil : item.category
                            }
                        } label: {
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

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            }
                        }
                        .buttonStyle(.plain)

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

                        if isExpanded {
                            let merchants = merchantGroups(for: item.category)
                            VStack(spacing: 4) {
                                ForEach(merchants) { merchant in
                                    HStack(spacing: 8) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(color.opacity(0.5))
                                            .frame(width: 3, height: 20)

                                        Text(merchant.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        Spacer()

                                        Text("\(merchant.count)×")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(.tertiary)

                                        Text(formatAmount(merchant.total))
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.primary)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(color.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(.top, 2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
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

    // MARK: - Expenses List (last 10)

    private var expensesList: some View {
        VStack(spacing: 0) {
            GlassSectionHeader(title: "ПОСЛЕДНИЕ РАСХОДЫ", color: AppTheme.sakuraPink)

            VStack(spacing: 6) {
                ForEach(recentExpenses) { expense in
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
                                try? modelContext.save()
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                }

                if trip.expenses.count > 10 {
                    Button { showAllExpenses = true } label: {
                        HStack {
                            Text("ВСЕ РАСХОДЫ")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                            Spacer()
                            Text("\(trip.expenses.count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(AppTheme.sakuraPink)
                        .padding(12)
                        .background(AppTheme.sakuraPink.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
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
        .sheet(isPresented: $showAllExpenses) {
            AllExpensesByDaySheet(trip: trip, editingExpense: $editingExpense)
        }
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
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatAmount(expense.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                if expense.originalCurrency != preferredCurrency,
                   expense.originalAmount > 0 {
                    Text(currency.format(expense.originalAmount, currency: expense.originalCurrency))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
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
