import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    let trip: Trip
    var editing: Expense?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .food
    @State private var date = Date()
    @State private var notes = ""
    @State private var inputCurrency = UserDefaults.standard.string(forKey: "preferredCurrency") ?? "RUB"

    private var currency: CurrencyService { CurrencyService.shared }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(amountText) != nil
            && Double(amountText)! > 0
    }

    private var baseCurrency: String {
        currency.baseCurrency
    }

    private var convertedBase: Double? {
        guard let amount = Double(amountText), amount > 0 else { return nil }
        if inputCurrency == baseCurrency { return amount }
        let result = currency.convert(amount, from: inputCurrency, to: baseCurrency)
        return result > 0 ? result : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(icon: "\(CurrencyService.baseCurrencyIcon).circle.fill", title: editing != nil ? "РЕДАКТИРОВАТЬ РАСХОД" : "НОВЫЙ РАСХОД", color: AppTheme.sakuraPink)

                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Рамен Ichiran", text: $title)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    // Amount + currency selector
                    GlassFormField(label: "СУММА (\(inputCurrency))", color: AppTheme.templeGold) {
                        VStack(spacing: AppTheme.spacingS) {
                            TextField(inputCurrency == "RUB" ? "5000" : "10.00", text: $amountText)
                                .keyboardType((inputCurrency == "RUB" || inputCurrency == "JPY") ? .numberPad : .decimalPad)
                                .textFieldStyle(GlassTextFieldStyle())

                            currencySelector

                            if inputCurrency != baseCurrency, let base = convertedBase {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10))
                                    Text("\u{2248} \(currency.format(base, currency: baseCurrency))")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(AppTheme.templeGold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    GlassFormField(label: "КАТЕГОРИЯ", color: AppTheme.oceanBlue) {
                        categoryPicker
                    }

                    GlassFormField(label: "ДАТА", color: AppTheme.sakuraPink) {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
                    }

                    GlassFormField(label: "ЗАМЕТКА", color: .secondary) {
                        TextField("Дополнительные детали...", text: $notes)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    if let expense = editing {
                        PhotoGridView(
                            photos: expense.photos,
                            onAdd: { photo in
                                expense.photos.append(photo)
                            },
                            onDelete: { photo in
                                expense.photos.removeAll { $0.id == photo.id }
                                modelContext.delete(photo)
                            }
                        )
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("ОТМЕНА")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { saveExpense() } label: {
                        Text("СОХРАНИТЬ")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(isValid ? AppTheme.sakuraPink : .secondary)
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let e = editing {
                    title = e.title
                    amountText = String(Int(e.amount))
                    category = e.category
                    date = e.date
                    notes = e.notes
                    inputCurrency = baseCurrency
                }
            }
            .task {
                await currency.fetchRates()
            }
        }
    }

    // MARK: - Currency Selector

    private var currencySelector: some View {
        HStack(spacing: 6) {
            ForEach(CurrencyService.supportedCurrencies, id: \.self) { code in
                let isSelected = inputCurrency == code
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        inputCurrency = code
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(CurrencyService.symbols[code] ?? code)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text(code)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .background(isSelected ? AppTheme.templeGold : .clear)
                    .background { if !isSelected { Color.clear.background(.ultraThinMaterial) } }
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(
                            isSelected ? AppTheme.templeGold.opacity(0.5) : Color.white.opacity(0.2),
                            lineWidth: 0.5
                        )
                    )
                }
            }
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(ExpenseCategory.allCases), id: \.self) { (cat: ExpenseCategory) in
                    let color = AppTheme.expenseColor(for: cat)
                    Button {
                        category = cat
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.systemImage)
                                .font(.system(size: 12, weight: .bold))
                            Text(cat.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundStyle(category == cat ? .white : .secondary)
                        .background(category == cat ? color : .clear)
                        .background { if category != cat { Color.clear.background(.ultraThinMaterial) } }
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                category == cat ? color.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: 0.5
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func saveExpense() {
        guard let amount = Double(amountText), amount > 0 else { return }

        // Convert to base currency if needed
        let baseAmount: Double
        if inputCurrency == baseCurrency {
            baseAmount = amount
        } else {
            baseAmount = currency.convert(amount, from: inputCurrency, to: baseCurrency)
            guard baseAmount > 0 else { return }
        }

        if let e = editing {
            e.title = title.trimmingCharacters(in: .whitespaces)
            e.amount = baseAmount
            e.category = category
            e.date = date
            e.notes = notes.trimmingCharacters(in: .whitespaces)
        } else {
            let expense = Expense(
                title: title.trimmingCharacters(in: .whitespaces),
                amount: baseAmount,
                category: category,
                date: date,
                notes: notes.trimmingCharacters(in: .whitespaces)
            )
            trip.expenses.append(expense)
        }
        dismiss()
    }
}

// MARK: - Reusable Sheet Header

struct SheetHeader: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(3)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [color, color.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }
}

// MARK: - Legacy Compat (kept for any remaining references)

typealias SakuraTextFieldStyle = GlassTextFieldStyle
typealias SakuraFormField = GlassFormField

#if DEBUG
#Preview {
    AddExpenseSheet(trip: .preview)
        .modelContainer(.preview)
}
#endif
