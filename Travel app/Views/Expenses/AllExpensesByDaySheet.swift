import SwiftUI
import SwiftData

struct AllExpensesByDaySheet: View {
    let trip: Trip
    @Binding var editingExpense: Expense?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("preferredCurrency") private var preferredCurrency = "RUB"

    private var currency: CurrencyService { CurrencyService.shared }

    private func formatAmount(_ amount: Double) -> String {
        currency.format(amount, currency: preferredCurrency)
    }

    private var groupedByDay: [(date: Date, expenses: [Expense], total: Double)] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: trip.expenses) { expense in
            cal.startOfDay(for: expense.date)
        }
        return grouped
            .map { (date: $0.key, expenses: $0.value.sorted { $0.date > $1.date }, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(
                        icon: "list.bullet.rectangle.portrait.fill",
                        title: "ВСЕ РАСХОДЫ",
                        color: AppTheme.sakuraPink
                    )

                    // Total summary
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ВСЕГО")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(.tertiary)
                            Text(formatAmount(trip.totalSpent))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.toriiRed)
                        }
                        Spacer()
                        Text("\(trip.expenses.count) расходов")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(AppTheme.spacingM)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))

                    // Days
                    ForEach(groupedByDay, id: \.date) { group in
                        daySection(date: group.date, expenses: group.expenses, total: group.total)
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("ЗАКРЫТЬ")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Day Section

    private func daySection(date: Date, expenses: [Expense], total: Double) -> some View {
        VStack(spacing: 0) {
            // Day header
            HStack {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.sakuraPink)
                        .frame(width: 4, height: 16)
                    Text(dayFormatted(date))
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                Spacer()
                Text(formatAmount(total))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(AppTheme.spacingM)

            Divider().opacity(0.15).padding(.horizontal, AppTheme.spacingM)

            // Expenses
            VStack(spacing: 6) {
                ForEach(expenses) { expense in
                    expenseRow(expense)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingExpense = expense
                            dismiss()
                        }
                        .contextMenu {
                            Button {
                                editingExpense = expense
                                dismiss()
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
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingS)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Expense Row

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
                    Text(expense.date, format: .dateTime.hour().minute())
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

    // MARK: - Helpers

    private func dayFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "d MMMM, EEEE"
        return f.string(from: date).uppercased()
    }
}
