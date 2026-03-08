import SwiftUI

struct ProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var homeCountry: String = ""
    @State private var homeCity: String = ""
    @State private var travelPace: TravelPace = .mixed
    @State private var chronotype: Chronotype = .morning
    @State private var interests: [String] = []
    @State private var customInterest = ""
    @State private var dietaryPreferences: [String] = []
    @State private var visitedCountries: [String] = []
    @State private var currentCountryInput = ""
    @State private var visitedCities: [VisitedCity] = []
    @State private var showAddCitySheet = false
    @State private var birthDate: Date?
    @State private var showDatePicker = false
    @State private var isSaving = false

    @State private var expandedSection: Section? = .basic
    @State private var showSecureVault = false

    // Corporate profile state
    @State private var corpCompany: String = ""
    @State private var corpDepartment: String = ""
    @State private var corpDivision: String = ""
    @State private var corpPosition: String = ""
    @State private var corpHotelLimit: String = ""
    @State private var corpFlightClass: FlightClass = .economy
    @State private var corpTransportLimit: String = ""
    @State private var corpFoodLimit: String = ""
    @State private var corpVendors: [String] = []
    @State private var corpNewVendor: String = ""
    @State private var corpApprovalManager: String = ""

    // @AppStorage("appMode") private var appMode: String = AppMode.personal.rawValue

    private let profileService = ProfileService.shared
    private let vaultService = SecureVaultService.shared

    // Corporate mode disabled
    private var isCorporate: Bool { false }

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

    enum Section: String, CaseIterable {
        case basic, style, interests, dietary, countries, cities, documents
        case corpCompany, corpLimits, corpVendors, corpManager
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingS) {
                    // Avatar + name header
                    profileHeader

                    // Collapsible sections
                    sectionCard(section: .basic, icon: "person.fill", title: "ОСНОВНОЕ", color: AppTheme.sakuraPink) {
                        if isCorporate {
                            corporateBasicContent
                        } else {
                            basicContent
                        }
                    }

                    if isCorporate {
                        sectionCard(section: .corpCompany, icon: "building.2.fill", title: "КОМПАНИЯ", color: CorporateColors.electricBlue) {
                            corporateCompanyContent
                        }

                        sectionCard(section: .corpLimits, icon: "banknote.fill", title: "ЛИМИТЫ", color: CorporateColors.electricBlue) {
                            corporateLimitsContent
                        }

                        sectionCard(section: .corpVendors, icon: "bag.fill", title: "ВЕНДОРЫ", color: CorporateColors.indigo) {
                            corporateVendorsContent
                        }

                        sectionCard(section: .corpManager, icon: "person.badge.shield.checkmark.fill", title: "МЕНЕДЖЕР", color: CorporateColors.indigo) {
                            corporateManagerContent
                        }

                        sectionCard(section: .documents, icon: "lock.shield.fill", title: "ДОКУМЕНТЫ", color: AppTheme.oceanBlue) {
                            documentsContent
                        }
                    } else {
                        sectionCard(section: .style, icon: "figure.walk", title: "СТИЛЬ", color: AppTheme.templeGold) {
                            styleContent
                        }

                        sectionCard(section: .interests, icon: "sparkles", title: "ИНТЕРЕСЫ", color: AppTheme.sakuraPink) {
                            interestsContent
                        }

                        sectionCard(section: .dietary, icon: "leaf.fill", title: "ДИЕТА", color: AppTheme.templeGold) {
                            dietaryContent
                        }

                        sectionCard(section: .countries, icon: "globe", title: "ПОСЕЩЁННЫЕ СТРАНЫ", color: AppTheme.oceanBlue) {
                            countriesContent
                        }

                        sectionCard(section: .cities, icon: "building.2", title: "ПОСЕЩЁННЫЕ ГОРОДА", color: AppTheme.bambooGreen) {
                            citiesContent
                        }

                        sectionCard(section: .documents, icon: "lock.shield.fill", title: "ДОКУМЕНТЫ", color: AppTheme.oceanBlue) {
                            documentsContent
                        }
                    }

                    saveButton
                        .padding(.top, AppTheme.spacingS)

                    Spacer(minLength: 40)
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ЗАКРЫТЬ") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear { loadProfile() }
            .sheet(isPresented: $showSecureVault) {
                SecureVaultView()
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? "Ваше имя" : name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(name.isEmpty ? .tertiary : .primary)

                let subtitle = [homeCity, homeCountry].filter { !$0.isEmpty }.joined(separator: ", ")
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if let ageText = birthDate.flatMap({ UserProfile(birthDate: $0).ageFormatted }) {
                    Text(ageText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.bottom, AppTheme.spacingS)
    }

    // MARK: - Collapsible Section Card

    private func sectionCard<Content: View>(
        section: Section,
        icon: String,
        title: String,
        color: Color,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Header tap area
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    expandedSection = expandedSection == section ? nil : section
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 20)
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(color)
                    Spacer()

                    // Summary when collapsed
                    if expandedSection != section {
                        sectionSummary(section)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expandedSection == section ? 90 : 0))
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Expandable content
            if expandedSection == section {
                Divider().padding(.horizontal, AppTheme.spacingM)
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    content()
                }
                .padding(AppTheme.spacingM)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(color.opacity(expandedSection == section ? 0.2 : 0.1), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func sectionSummary(_ section: Section) -> some View {
        switch section {
        case .basic:
            Text([homeCity, homeCountry].filter { !$0.isEmpty }.joined(separator: ", "))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        case .style:
            HStack(spacing: 4) {
                Image(systemName: travelPace.icon)
                    .font(.system(size: 9))
                Image(systemName: chronotype.icon)
                    .font(.system(size: 9))
            }
            .foregroundStyle(.tertiary)
        case .interests:
            Text(interests.isEmpty ? "—" : "\(interests.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        case .dietary:
            Text(dietaryPreferences.isEmpty ? "—" : "\(dietaryPreferences.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        case .countries:
            Text(visitedCountries.isEmpty ? "—" : "\(visitedCountries.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        case .cities:
            Text(visitedCities.isEmpty ? "—" : "\(visitedCities.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        case .documents:
            let total = vaultService.documentCount + vaultService.loyaltyCount
            Text(total > 0 ? "\(total)" : "—")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        case .corpCompany:
            Text(corpCompany.isEmpty ? "—" : corpCompany)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        case .corpLimits:
            Text(corpFlightClass.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        case .corpVendors:
            Text(corpVendors.isEmpty ? "—" : "\(corpVendors.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        case .corpManager:
            Text(corpApprovalManager.isEmpty ? "—" : corpApprovalManager)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Section Contents

    private var basicContent: some View {
        VStack(spacing: AppTheme.spacingS) {
            compactField("Имя", text: $name, placeholder: "Ваше имя")
            compactField("Страна", text: $homeCountry, placeholder: "Россия")
            compactField("Город", text: $homeCity, placeholder: "Москва")

            // Birth date
            Button {
                withAnimation(.spring(response: 0.25)) { showDatePicker.toggle() }
            } label: {
                HStack {
                    Text("Дата рождения")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(birthDate.map { birthDateFormatter.string(from: $0) } ?? "Не указана")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(birthDate != nil ? .primary : .tertiary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
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
                .frame(height: 150)
                .clipped()
            }
        }
    }

    // MARK: - Corporate: Basic (name + birth date only)

    private var corporateBasicContent: some View {
        VStack(spacing: AppTheme.spacingS) {
            compactField("Имя", text: $name, placeholder: "Ваше имя")

            // Birth date
            Button {
                withAnimation(.spring(response: 0.25)) { showDatePicker.toggle() }
            } label: {
                HStack {
                    Text("Дата рождения")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(birthDate.map { birthDateFormatter.string(from: $0) } ?? "Не указана")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(birthDate != nil ? .primary : .tertiary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
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
                .frame(height: 150)
                .clipped()
            }
        }
    }

    // MARK: - Corporate: Company

    private var corporateCompanyContent: some View {
        VStack(spacing: AppTheme.spacingS) {
            compactField("Компания", text: $corpCompany, placeholder: "ООО «Название»")
            compactField("Департамент", text: $corpDepartment, placeholder: "IT")
            compactField("Отдел", text: $corpDivision, placeholder: "Разработка")
            compactField("Должность", text: $corpPosition, placeholder: "Менеджер")
        }
    }

    // MARK: - Corporate: Limits

    private var corporateLimitsContent: some View {
        VStack(spacing: AppTheme.spacingS) {
            HStack {
                Text("Отель/ночь")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                TextField("0", text: $corpHotelLimit)
                    .textFieldStyle(GlassTextFieldStyle())
                    .font(.system(size: 13))
                    .keyboardType(.decimalPad)
                Text("₽")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Text("Класс перелёта")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $corpFlightClass) {
                    ForEach(FlightClass.allCases) { fc in
                        Text(fc.label).tag(fc)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }

            HStack {
                Text("Транспорт/день")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .leading)
                TextField("0", text: $corpTransportLimit)
                    .textFieldStyle(GlassTextFieldStyle())
                    .font(.system(size: 13))
                    .keyboardType(.decimalPad)
                Text("₽")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Text("Еда/день")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                TextField("0", text: $corpFoodLimit)
                    .textFieldStyle(GlassTextFieldStyle())
                    .font(.system(size: 13))
                    .keyboardType(.decimalPad)
                Text("₽")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Corporate: Vendors

    private var corporateVendorsContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            if !corpVendors.isEmpty {
                ProfileFlowLayout(spacing: 5) {
                    ForEach(corpVendors, id: \.self) { vendor in
                        removableChip(vendor, color: CorporateColors.indigo) {
                            withAnimation(.spring(response: 0.25)) {
                                corpVendors.removeAll { $0 == vendor }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                TextField("Добавить вендора", text: $corpNewVendor)
                    .textFieldStyle(GlassTextFieldStyle())
                    .font(.system(size: 13))
                    .onSubmit { addVendor() }
                Button { addVendor() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CorporateColors.electricBlue)
                }
                .disabled(corpNewVendor.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(corpNewVendor.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
            }
        }
    }

    // MARK: - Corporate: Approval Manager

    private var corporateManagerContent: some View {
        VStack(spacing: AppTheme.spacingS) {
            compactField("ФИО", text: $corpApprovalManager, placeholder: "Иванов И.И.")
        }
    }

    private var styleContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            Text("ТЕМП")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppTheme.templeGold)

            HStack(spacing: 6) {
                ForEach(TravelPace.allCases) { pace in
                    miniSelector(icon: pace.icon, label: pace.label, isSelected: travelPace == pace, color: AppTheme.templeGold) {
                        withAnimation(.spring(response: 0.3)) { travelPace = pace }
                    }
                }
            }

            Text("ХРОНОТИП")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppTheme.indigoPurple)
                .padding(.top, 4)

            HStack(spacing: 6) {
                ForEach(Chronotype.allCases) { chrono in
                    miniSelector(icon: chrono.icon, label: chrono.label, isSelected: chronotype == chrono, color: AppTheme.indigoPurple) {
                        withAnimation(.spring(response: 0.3)) { chronotype = chrono }
                    }
                }
            }
        }
    }

    private var interestsContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            ProfileFlowLayout(spacing: 5) {
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

            HStack(spacing: 6) {
                TextField("Свой интерес", text: $customInterest)
                    .textFieldStyle(GlassTextFieldStyle())
                    .font(.system(size: 13))
                    .onSubmit { addCustomInterest() }
                Button { addCustomInterest() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                .disabled(customInterest.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(customInterest.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
            }
        }
    }

    private var dietaryContent: some View {
        ProfileFlowLayout(spacing: 5) {
            ForEach(presetDietary, id: \.self) { pref in
                chipToggle(pref, isSelected: dietaryPreferences.contains(pref), color: AppTheme.templeGold) {
                    toggleArrayItem(&dietaryPreferences, pref)
                }
            }
        }
    }

    private var countriesContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            if !visitedCountries.isEmpty {
                ProfileFlowLayout(spacing: 5) {
                    ForEach(visitedCountries, id: \.self) { country in
                        removableChip(country, color: AppTheme.oceanBlue) {
                            withAnimation(.spring(response: 0.25)) {
                                visitedCountries.removeAll { $0 == country }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                TextField("Добавить страну", text: $currentCountryInput)
                    .textFieldStyle(GlassTextFieldStyle())
                    .font(.system(size: 13))
                    .onSubmit { addVisitedCountry() }
                Button { addVisitedCountry() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.oceanBlue)
                }
                .disabled(currentCountryInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(currentCountryInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
            }
        }
    }

    // MARK: - Cities Content

    private var citiesContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            if !visitedCities.isEmpty {
                ProfileFlowLayout(spacing: 5) {
                    ForEach(visitedCities) { city in
                        removableChip(city.name, color: AppTheme.bambooGreen) {
                            withAnimation(.spring(response: 0.25)) {
                                visitedCities.removeAll { $0.id == city.id }
                            }
                        }
                    }
                }
            }

            Button {
                showAddCitySheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Добавить город")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(AppTheme.bambooGreen)
            }
        }
        .sheet(isPresented: $showAddCitySheet) {
            AddVisitedCitySheet { city in
                if !visitedCities.contains(where: { $0.name.lowercased() == city.name.lowercased() }) {
                    withAnimation(.spring(response: 0.25)) {
                        visitedCities.append(city)
                    }
                }
            }
        }
    }

    // MARK: - Documents Content

    private var documentsContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vaultService.documentCount)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Документов")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Divider().frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vaultService.loyaltyCount)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Программ")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            Button {
                showSecureVault = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 13))
                    Text("Открыть хранилище")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [AppTheme.oceanBlue, AppTheme.oceanBlue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: AppTheme.oceanBlue.opacity(0.2), radius: 6, x: 0, y: 3)
            }
        }
    }

    // MARK: - Compact Components

    private func compactField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(GlassTextFieldStyle())
                .font(.system(size: 13))
        }
    }

    private func miniSelector(icon: String, label: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .white : color)
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? color : Color.clear)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(isSelected ? color : color.opacity(0.15), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func chipToggle(_ text: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
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
        HStack(spacing: 3) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var saveButton: some View {
        Button {
            saveProfile()
        } label: {
            if isSaving {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            } else {
                Text("СОХРАНИТЬ")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
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
            withAnimation(.spring(response: 0.25)) { interests.append(trimmed) }
        }
        customInterest = ""
    }

    private func addVendor() {
        let trimmed = corpNewVendor.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !corpVendors.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            withAnimation(.spring(response: 0.25)) { corpVendors.append(trimmed) }
        }
        corpNewVendor = ""
    }

    private func addVisitedCountry() {
        let trimmed = currentCountryInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let capitalized = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        if !visitedCountries.contains(where: { $0.lowercased() == capitalized.lowercased() }) {
            withAnimation(.spring(response: 0.25)) { visitedCountries.append(capitalized) }
        }
        currentCountryInput = ""
    }

    private func loadProfile() {
        guard let p = profileService.profile else { return }
        name = p.name
        homeCountry = p.homeCountry
        homeCity = p.homeCity
        birthDate = p.birthDate
        travelPace = p.travelPace
        chronotype = p.chronotype
        interests = p.interests
        dietaryPreferences = p.dietaryPreferences
        visitedCountries = p.visitedCountries
        visitedCities = p.visitedCities

        if isCorporate {
            loadCorporateProfile()
        }
    }

    private func loadCorporateProfile() {
        Task {
            let unlocked = await vaultService.unlock()
            guard unlocked, let corp = vaultService.corporateProfile else { return }
            await MainActor.run {
                corpCompany = corp.company
                corpDepartment = corp.department
                corpDivision = corp.division
                corpPosition = corp.position
                corpHotelLimit = corp.limits.hotelPerNight > 0 ? String(format: "%.0f", corp.limits.hotelPerNight) : ""
                corpFlightClass = corp.limits.flightClass
                corpTransportLimit = corp.limits.transportDaily > 0 ? String(format: "%.0f", corp.limits.transportDaily) : ""
                corpFoodLimit = corp.limits.foodDaily > 0 ? String(format: "%.0f", corp.limits.foodDaily) : ""
                corpVendors = corp.preferredVendors
                corpApprovalManager = corp.approvalManager
            }
        }
    }

    private func saveProfile() {
        isSaving = true
        Task {
            do {
                let updated = UserProfile(
                    name: name.trimmingCharacters(in: .whitespaces),
                    homeCountry: homeCountry.trimmingCharacters(in: .whitespaces),
                    homeCity: homeCity.trimmingCharacters(in: .whitespaces),
                    birthDate: birthDate,
                    travelPace: travelPace,
                    interests: interests,
                    dietaryPreferences: dietaryPreferences,
                    visitedCountries: visitedCountries,
                    visitedCities: visitedCities,
                    chronotype: chronotype
                )
                try await ProfileService.shared.saveProfile(updated)

                if isCorporate {
                    try saveCorporateProfile()
                }
            } catch {
                print("[ProfileDetailView] save error: \(error)")
            }
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }

    private func saveCorporateProfile() throws {
        let limits = CorporateLimits(
            hotelPerNight: Double(corpHotelLimit) ?? 0,
            flightClass: corpFlightClass,
            transportDaily: Double(corpTransportLimit) ?? 0,
            foodDaily: Double(corpFoodLimit) ?? 0
        )
        let profile = CorporateProfile(
            company: corpCompany.trimmingCharacters(in: .whitespaces),
            department: corpDepartment.trimmingCharacters(in: .whitespaces),
            division: corpDivision.trimmingCharacters(in: .whitespaces),
            position: corpPosition.trimmingCharacters(in: .whitespaces),
            limits: limits,
            preferredVendors: corpVendors,
            approvalManager: corpApprovalManager.trimmingCharacters(in: .whitespaces)
        )
        try vaultService.saveCorporateProfile(profile)
    }
}
