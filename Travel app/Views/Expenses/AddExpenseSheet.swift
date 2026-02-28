import SwiftUI

struct AddExpenseSheet: View {
    let store: TripStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .food
    @State private var date = Date()
    @State private var notes = ""

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(amountText) != nil
            && Double(amountText)! > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.spacingM) {
                        HStack {
                            Image(systemName: "yensign.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("НОВЫЙ РАСХОД")
                                .font(.system(size: 12, weight: .black))
                                .tracking(3)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.sakuraPink)

                        formField(label: "НАЗВАНИЕ", color: AppTheme.sakuraPink) {
                            TextField("Рамен Ichiran", text: $title)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }

                        formField(label: "СУММА (JPY)", color: AppTheme.templeGold) {
                            TextField("1290", text: $amountText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }

                        formField(label: "КАТЕГОРИЯ", color: AppTheme.oceanBlue) {
                            categoryPicker
                        }

                        formField(label: "ДАТА", color: AppTheme.sakuraPink) {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(AppTheme.sakuraPink)
                        }

                        formField(label: "ЗАМЕТКА", color: AppTheme.textMuted) {
                            TextField("Дополнительные детали...", text: $notes)
                                .textFieldStyle(SakuraTextFieldStyle())
                        }
                    }
                    .padding(AppTheme.spacingM)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("ОТМЕНА")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveExpense()
                    } label: {
                        Text("СОХРАНИТЬ")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1)
                            .foregroundStyle(isValid ? AppTheme.sakuraPink : AppTheme.textMuted)
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func formField<Content: View>(label: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(color)
                    .frame(width: 4)
                Text(label)
                    .font(.system(size: 9, weight: .black))
                    .tracking(2)
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                Spacer()
            }
            .background(AppTheme.surface)

            content()
                .padding(.horizontal, AppTheme.spacingS)
                .padding(.vertical, AppTheme.spacingS)
                .background(AppTheme.card)
        }
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1))
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ExpenseCategory.allCases) { cat in
                    Button {
                        category = cat
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.systemImage)
                                .font(.system(size: 12, weight: .bold))
                            Text(cat.rawValue.uppercased())
                                .font(.system(size: 10, weight: .black))
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundStyle(
                            category == cat
                                ? .white
                                : AppTheme.textSecondary
                        )
                        .background(
                            category == cat
                                ? AppTheme.expenseColor(for: cat)
                                : AppTheme.surface
                        )
                        .overlay(
                            Rectangle()
                                .stroke(
                                    category == cat
                                        ? AppTheme.expenseColor(for: cat)
                                        : AppTheme.border,
                                    lineWidth: category == cat ? 2 : 1
                                )
                        )
                    }
                }
            }
        }
    }

    private func saveExpense() {
        guard let amount = Double(amountText), amount > 0 else { return }

        let expense = Expense(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amount,
            category: category,
            date: date,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )

        store.addExpense(expense)
        dismiss()
    }
}

// MARK: - Sakura Text Field Style

struct SakuraTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .foregroundStyle(AppTheme.textPrimary)
            .background(AppTheme.card)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

#Preview {
    AddExpenseSheet(store: TripStore())
}
