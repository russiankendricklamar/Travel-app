import SwiftUI

struct ProfileSetupView: View {
    var onComplete: () -> Void
    var onSkip: () -> Void

    @State private var step = 0
    @State private var name: String
    @State private var homeCountry = ""
    @State private var homeCity = ""
    @State private var birthDate: Date?
    @State private var showDatePicker = false
    @State private var travelPace: TravelPace = .mixed
    @State private var chronotype: Chronotype = .morning
    @State private var interests: [String] = []
    @State private var customInterest = ""
    @State private var dietaryPreferences: [String] = []
    @State private var visitedCountries: [String] = []
    @State private var currentCountryInput = ""
    @State private var isSaving = false

    private let totalSteps = 3

    private var birthDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy"
        return f
    }

    private let presetInterests = [
        "Архитектура", "Природа", "Еда", "Музеи", "Шоппинг",
        "Ночная жизнь", "Спорт", "Фото", "Искусство", "История"
    ]

    private let presetDietary = [
        "Без ограничений", "Вегетарианство", "Веганство",
        "Халяль", "Кошер", "Без глютена", "Без лактозы"
    ]

    init(initialName: String? = nil, onComplete: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onSkip = onSkip
        _name = State(initialValue: initialName ?? "")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerBar
                progressBar

                TabView(selection: $step) {
                    stepBasic.tag(0)
                    stepStyle.tag(1)
                    stepInterests.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
            }
        }
        .sakuraGradientBackground()
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Button {
                if step > 0 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        step -= 1
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.sakuraPink)
            }
            .opacity(step > 0 ? 1 : 0)

            Spacer()

            Text("ПРОФИЛЬ")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundStyle(AppTheme.sakuraPink)

            Spacer()

            Button {
                onSkip()
            } label: {
                Text("ПРОПУСТИТЬ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingS)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? AppTheme.sakuraPink : AppTheme.sakuraPink.opacity(0.2))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingS)
        .padding(.bottom, AppTheme.spacingM)
    }

    // MARK: - Step 1: Basic

    private var stepBasic: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingM) {
                stepIcon(icon: "person.fill", color: AppTheme.sakuraPink)

                Text("РАССКАЖИТЕ О СЕБЕ")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(.primary)

                Text("Эта информация поможет\nперсонализировать рекомендации")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                GlassFormField(label: "ИМЯ", color: AppTheme.sakuraPink) {
                    TextField("Ваше имя", text: $name)
                        .textFieldStyle(GlassTextFieldStyle())
                }

                GlassFormField(label: "СТРАНА ПРОЖИВАНИЯ", color: AppTheme.oceanBlue) {
                    TextField("Россия", text: $homeCountry)
                        .textFieldStyle(GlassTextFieldStyle())
                }

                GlassFormField(label: "ДОМАШНИЙ ГОРОД", color: AppTheme.bambooGreen) {
                    TextField("Москва", text: $homeCity)
                        .textFieldStyle(GlassTextFieldStyle())
                }

                GlassFormField(label: "ДАТА РОЖДЕНИЯ", color: AppTheme.indigoPurple) {
                    Button {
                        showDatePicker.toggle()
                    } label: {
                        HStack {
                            Text(birthDate.map { birthDateFormatter.string(from: $0) } ?? "Не указана")
                                .foregroundStyle(birthDate != nil ? .primary : .tertiary)
                            Spacer()
                            Image(systemName: "calendar")
                                .foregroundStyle(AppTheme.indigoPurple)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    }
                    .buttonStyle(.plain)

                    if showDatePicker {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { birthDate ?? Calendar.current.date(byAdding: .year, value: -25, to: Date())! },
                                set: { birthDate = $0 }
                            ),
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                        .transition(.opacity)
                    }
                }

                Spacer(minLength: 40)

                nextButton {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        step = 1
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }

    // MARK: - Step 2: Style

    private var stepStyle: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingM) {
                stepIcon(icon: "figure.walk", color: AppTheme.templeGold)

                Text("СТИЛЬ ПУТЕШЕСТВИЙ")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(.primary)

                Text("Как вам нравится путешествовать?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                GlassSectionHeader(title: "ТЕМП", color: AppTheme.templeGold)

                HStack(spacing: AppTheme.spacingS) {
                    ForEach(TravelPace.allCases) { pace in
                        selectorCard(
                            icon: pace.icon,
                            label: pace.label,
                            isSelected: travelPace == pace,
                            color: AppTheme.templeGold
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                travelPace = pace
                            }
                        }
                    }
                }

                GlassSectionHeader(title: "ХРОНОТИП", color: AppTheme.indigoPurple)

                HStack(spacing: AppTheme.spacingS) {
                    ForEach(Chronotype.allCases) { chrono in
                        selectorCard(
                            icon: chrono.icon,
                            label: chrono.label,
                            isSelected: chronotype == chrono,
                            color: AppTheme.indigoPurple
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                chronotype = chrono
                            }
                        }
                    }
                }

                Spacer(minLength: 40)

                nextButton {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        step = 2
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }

    // MARK: - Step 3: Interests

    private var stepInterests: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingM) {
                stepIcon(icon: "sparkles", color: AppTheme.bambooGreen)

                Text("ИНТЕРЕСЫ И ПРЕДПОЧТЕНИЯ")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(.primary)

                Text("Выберите что вам интересно")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                // Interests
                GlassSectionHeader(title: "ИНТЕРЕСЫ", color: AppTheme.sakuraPink)

                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    ProfileFlowLayout(spacing: 6) {
                        ForEach(presetInterests, id: \.self) { interest in
                            chipToggle(interest, isSelected: interests.contains(interest), color: AppTheme.sakuraPink) {
                                toggleArrayItem(&interests, interest)
                            }
                        }
                        ForEach(interests.filter { !presetInterests.contains($0) }, id: \.self) { custom in
                            chipToggle(custom, isSelected: true, color: AppTheme.sakuraPink) {
                                interests.removeAll { $0 == custom }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Свой интерес", text: $customInterest)
                            .textFieldStyle(GlassTextFieldStyle())
                            .onSubmit { addCustomInterest() }
                        Button {
                            addCustomInterest()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(AppTheme.sakuraPink)
                        }
                        .disabled(customInterest.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(customInterest.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
                    }
                }
                .padding(AppTheme.spacingM)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
                )

                // Dietary
                GlassSectionHeader(title: "ДИЕТИЧЕСКИЕ ПРЕДПОЧТЕНИЯ", color: AppTheme.templeGold)

                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    ProfileFlowLayout(spacing: 6) {
                        ForEach(presetDietary, id: \.self) { pref in
                            chipToggle(pref, isSelected: dietaryPreferences.contains(pref), color: AppTheme.templeGold) {
                                toggleArrayItem(&dietaryPreferences, pref)
                            }
                        }
                    }
                }
                .padding(AppTheme.spacingM)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.templeGold.opacity(0.15), lineWidth: 0.5)
                )

                // Visited Countries
                GlassSectionHeader(title: "ПОСЕЩЁННЫЕ СТРАНЫ", color: AppTheme.oceanBlue)

                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    if !visitedCountries.isEmpty {
                        ProfileFlowLayout(spacing: 6) {
                            ForEach(visitedCountries, id: \.self) { country in
                                removableChip(country, color: AppTheme.oceanBlue) {
                                    withAnimation(.spring(response: 0.25)) {
                                        visitedCountries.removeAll { $0 == country }
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Добавить страну", text: $currentCountryInput)
                            .textFieldStyle(GlassTextFieldStyle())
                            .onSubmit { addVisitedCountry() }
                        Button {
                            addVisitedCountry()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(AppTheme.oceanBlue)
                        }
                        .disabled(currentCountryInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(currentCountryInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
                    }
                }
                .padding(AppTheme.spacingM)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
                )

                Spacer(minLength: 40)

                doneButton
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }

    // MARK: - Shared Components

    private func stepIcon(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 80, height: 80)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusXL)
                    .strokeBorder(
                        LinearGradient(
                            colors: [color.opacity(0.4), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: color.opacity(0.15), radius: 16, x: 0, y: 8)
    }

    private func selectorCard(
        icon: String,
        label: String,
        isSelected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isSelected ? .white : color)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacingM)
            .background(isSelected ? color : Color.clear)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(isSelected ? color : color.opacity(0.15), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func chipToggle(_ text: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? color : Color.clear)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color : color.opacity(0.2), lineWidth: isSelected ? 1 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func removableChip(_ text: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private func nextButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("ДАЛЕЕ")
                .font(.system(size: 14, weight: .bold))
                .tracking(4)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: AppTheme.sakuraPink.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var doneButton: some View {
        Button {
            saveProfile()
        } label: {
            if isSaving {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.bambooGreen, AppTheme.bambooGreen.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            } else {
                Text("ГОТОВО")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.bambooGreen, AppTheme.bambooGreen.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.bambooGreen.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .disabled(isSaving)
    }

    // MARK: - Helpers

    private func toggleArrayItem(_ array: inout [String], _ item: String) {
        withAnimation(.spring(response: 0.25)) {
            if let idx = array.firstIndex(of: item) {
                array.remove(at: idx)
            } else {
                array.append(item)
            }
        }
    }

    private func addCustomInterest() {
        let trimmed = customInterest.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !interests.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            withAnimation(.spring(response: 0.25)) {
                interests.append(trimmed)
            }
        }
        customInterest = ""
    }

    private func addVisitedCountry() {
        let trimmed = currentCountryInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let capitalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        if !visitedCountries.contains(where: { $0.lowercased() == capitalized.lowercased() }) {
            withAnimation(.spring(response: 0.25)) {
                visitedCountries.append(capitalized)
            }
        }
        currentCountryInput = ""
    }

    private func saveProfile() {
        isSaving = true
        Task {
            do {
                let profile = UserProfile(
                    name: name.trimmingCharacters(in: .whitespaces),
                    homeCountry: homeCountry.trimmingCharacters(in: .whitespaces),
                    homeCity: homeCity.trimmingCharacters(in: .whitespaces),
                    birthDate: birthDate,
                    travelPace: travelPace,
                    interests: interests,
                    dietaryPreferences: dietaryPreferences,
                    visitedCountries: visitedCountries,
                    chronotype: chronotype
                )
                try await ProfileService.shared.saveProfile(profile)
            } catch {
                print("[ProfileSetupView] save error: \(error)")
            }
            await MainActor.run {
                isSaving = false
                onComplete()
            }
        }
    }
}

// MARK: - Flow Layout (wrapping chips)

struct ProfileFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, containerWidth: proposal.width ?? .infinity)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, containerWidth: bounds.width)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func layout(subviews: Subviews, containerWidth: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > containerWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x - spacing)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
