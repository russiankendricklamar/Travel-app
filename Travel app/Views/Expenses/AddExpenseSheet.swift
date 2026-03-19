import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    let trip: Trip
    var editing: Expense?
    var prefillTitle: String?
    var prefillCategory: ExpenseCategory?
    var prefillAmount: Double?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .food
    @State private var date = Date()
    @State private var notes = ""
    @State private var inputCurrency = UserDefaults.standard.string(forKey: "preferredCurrency") ?? "RUB"
    @State private var historicalRate: Double?
    @State private var isFetchingRate = false
    @State private var categoryAutoSet = false
    @State private var showReceiptScanner = false

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
        // Prefer historical rate if available
        if let rate = historicalRate {
            return amount * rate
        }
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
                                .keyboardType(inputCurrency == "JPY" ? .numberPad : .decimalPad)
                                .textFieldStyle(GlassTextFieldStyle())

                            currencySelector

                            if inputCurrency != baseCurrency {
                                HStack(spacing: 4) {
                                    if isFetchingRate {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                        Text("Загрузка курса...")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    } else if let base = convertedBase {
                                        Image(systemName: historicalRate != nil ? "checkmark.circle.fill" : "arrow.right")
                                            .font(.system(size: 10))
                                        Text("\u{2248} \(currency.format(base, currency: baseCurrency))")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        if historicalRate != nil {
                                            Text("НКЦ")
                                                .font(.system(size: 8, weight: .bold))
                                                .tracking(0.5)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(AppTheme.templeGold.opacity(0.2))
                                                .clipShape(Capsule())
                                        }
                                    }
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
                                try? modelContext.save()
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
                    HStack(spacing: 12) {
                        if editing == nil {
                            Button { showReceiptScanner = true } label: {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.templeGold)
                            }
                        }
                        Button { saveExpense() } label: {
                            Text("СОХРАНИТЬ")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(isValid ? AppTheme.sakuraPink : .secondary)
                        }
                        .disabled(!isValid)
                    }
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
                } else {
                    if let t = prefillTitle { title = t }
                    if let c = prefillCategory { category = c; categoryAutoSet = true }
                    if let a = prefillAmount {
                        amountText = a.truncatingRemainder(dividingBy: 1) == 0
                            ? String(format: "%.0f", a) : String(format: "%.2f", a)
                    }
                }
            }
            .task {
                await currency.fetchRates()
                await fetchHistoricalRateIfNeeded()
            }
            .onChange(of: title) { _, newTitle in
                guard editing == nil, !categoryAutoSet || category == .other else { return }
                let guessed = ExpenseCategory.guess(from: newTitle)
                if guessed != .other {
                    withAnimation(.spring(response: 0.3)) { category = guessed }
                    categoryAutoSet = true
                }
            }
            .onChange(of: date) { _, _ in
                Task { await fetchHistoricalRateIfNeeded() }
            }
            .onChange(of: inputCurrency) { _, _ in
                historicalRate = nil
                Task { await fetchHistoricalRateIfNeeded() }
            }
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScannerSheet { scanned in
                    title = scanned.title
                    amountText = String(format: scanned.amount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", scanned.amount)
                    category = scanned.category
                    date = scanned.date
                    inputCurrency = scanned.currency
                    categoryAutoSet = true
                }
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

    // MARK: - Historical Rate

    private func fetchHistoricalRateIfNeeded() async {
        guard inputCurrency != baseCurrency else {
            historicalRate = nil
            return
        }
        isFetchingRate = true
        let rate = await currency.fetchHistoricalRate(from: inputCurrency, to: baseCurrency, date: date)
        historicalRate = rate
        isFetchingRate = false
    }

    // MARK: - Save

    private func saveExpense() {
        guard let amount = Double(amountText), amount > 0 else { return }

        let baseAmount: Double
        let rate: Double
        if inputCurrency == baseCurrency {
            baseAmount = amount
            rate = 1.0
        } else if let histRate = historicalRate, histRate > 0 {
            // Use historical (НКЦ) rate at transaction date
            baseAmount = amount * histRate
            rate = histRate
        } else {
            baseAmount = currency.convert(amount, from: inputCurrency, to: baseCurrency)
            guard baseAmount > 0 else { return }
            rate = baseAmount / amount
        }

        if let e = editing {
            e.title = title.trimmingCharacters(in: .whitespaces)
            e.amount = baseAmount
            e.originalAmount = amount
            e.originalCurrency = inputCurrency
            e.exchangeRate = rate
            e.category = category
            e.date = date
            e.notes = notes.trimmingCharacters(in: .whitespaces)
        } else {
            let expense = Expense(
                title: title.trimmingCharacters(in: .whitespaces),
                amount: baseAmount,
                category: category,
                date: date,
                notes: notes.trimmingCharacters(in: .whitespaces),
                originalAmount: amount,
                originalCurrency: inputCurrency,
                exchangeRate: rate
            )
            trip.expenses.append(expense)
        }
        dismiss()
    }
}

// MARK: - Reusable Sheet Header

// SheetHeader moved to Views/Shared/SheetHeader.swift

// MARK: - Legacy Compat (kept for any remaining references)

typealias SakuraTextFieldStyle = GlassTextFieldStyle
typealias SakuraFormField = GlassFormField

#if DEBUG
#Preview {
    AddExpenseSheet(trip: .preview)
        .modelContainer(.preview)
}
#endif
