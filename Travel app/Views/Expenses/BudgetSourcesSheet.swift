import SwiftUI
import SwiftData

struct BudgetSourcesSheet: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var sources: [BudgetSource] = []
    @State private var showAdd = false

    private let currency = CurrencyService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(icon: "wallet.bifold.fill", title: "ИСТОЧНИКИ БЮДЖЕТА", color: AppTheme.templeGold)

                    // Total
                    totalCard

                    // Sources list
                    if sources.isEmpty {
                        emptyState
                    } else {
                        ForEach(sources) { source in
                            sourceCard(source)
                        }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.templeGold)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddBudgetSourceSheet { newSource in
                    sources.append(newSource)
                    saveSources()
                }
            }
            .onAppear {
                sources = trip.budgetSources
            }
        }
    }

    // MARK: - Total Card

    private var totalCard: some View {
        let total = trip.effectiveBudget
        return VStack(spacing: 4) {
            Text("ОБЩИЙ БЮДЖЕТ")
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text(CurrencyService.formatBase(total))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.templeGold)
            if sources.count > 1 {
                Text("\(sources.count) источников в \(Set(sources.map(\.currency)).count) валютах")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            } else if sources.isEmpty {
                Text("Добавьте источники для мультивалютного бюджета")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingL)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.templeGold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Source Card

    private func sourceCard(_ source: BudgetSource) -> some View {
        let convertedBase = source.currency == currency.baseCurrency
            ? source.amount
            : currency.convert(source.amount, from: source.currency, to: currency.baseCurrency)

        return HStack(spacing: 12) {
            Image(systemName: source.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.templeGold)
                .frame(width: 36, height: 36)
                .background(AppTheme.templeGold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(currency.format(source.amount, currency: source.currency))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.templeGold)
                if source.currency != currency.baseCurrency {
                    Text("≈ \(CurrencyService.formatBase(convertedBase))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button(role: .destructive) {
                sources.removeAll { $0.id == source.id }
                saveSources()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.toriiRed.opacity(0.6))
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

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingM) {
            Image(systemName: "wallet.bifold")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.templeGold.opacity(0.3))
            Text("Добавьте источники бюджета")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Карты, наличные, счета в разных валютах")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingXL)
    }

    private func saveSources() {
        trip.budgetSources = sources
        trip.budget = sources.reduce(0.0) { acc, s in
            if s.currency == currency.baseCurrency { return acc + s.amount }
            return acc + currency.convert(s.amount, from: s.currency, to: currency.baseCurrency)
        }
        try? modelContext.save()
    }
}

// MARK: - Add Budget Source Sheet

struct AddBudgetSourceSheet: View {
    let onAdd: (BudgetSource) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amountText = ""
    @State private var selectedCurrency = UserDefaults.standard.string(forKey: "preferredCurrency") ?? "RUB"
    @State private var selectedIcon = BudgetSource.SourceIcon.card

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(amountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    SheetHeader(icon: "plus.circle.fill", title: "НОВЫЙ ИСТОЧНИК", color: AppTheme.templeGold)

                    GlassFormField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                        TextField("Карта Тинькофф", text: $name)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    GlassFormField(label: "СУММА", color: AppTheme.templeGold) {
                        TextField("100000", text: $amountText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(GlassTextFieldStyle())
                    }

                    GlassFormField(label: "ВАЛЮТА", color: AppTheme.oceanBlue) {
                        HStack(spacing: 6) {
                            ForEach(CurrencyService.supportedCurrencies, id: \.self) { code in
                                let isSelected = selectedCurrency == code
                                Button { selectedCurrency = code } label: {
                                    Text("\(CurrencyService.symbols[code] ?? code) \(code)")
                                        .font(.system(size: 11, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(isSelected ? .white : .secondary)
                                        .background(isSelected ? AppTheme.oceanBlue : .clear)
                                        .background { if !isSelected { Color.clear.background(.ultraThinMaterial) } }
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    GlassFormField(label: "ТИП", color: AppTheme.bambooGreen) {
                        HStack(spacing: 6) {
                            ForEach(BudgetSource.SourceIcon.allCases, id: \.rawValue) { icon in
                                let isSelected = selectedIcon == icon
                                Button { selectedIcon = icon } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: icon.rawValue)
                                            .font(.system(size: 16, weight: .bold))
                                        Text(icon.label)
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(isSelected ? .white : .secondary)
                                    .background(isSelected ? AppTheme.bambooGreen : .clear)
                                    .background { if !isSelected { Color.clear.background(.ultraThinMaterial) } }
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("ОТМЕНА").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let amount = Double(amountText), amount > 0 else { return }
                        let source = BudgetSource(
                            name: name.trimmingCharacters(in: .whitespaces),
                            currency: selectedCurrency,
                            amount: amount,
                            icon: selectedIcon.rawValue
                        )
                        onAdd(source)
                        dismiss()
                    } label: {
                        Text("ДОБАВИТЬ").font(.system(size: 11, weight: .bold)).tracking(1)
                            .foregroundStyle(isValid ? AppTheme.sakuraPink : .secondary)
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
