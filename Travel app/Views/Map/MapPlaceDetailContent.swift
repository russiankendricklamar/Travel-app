import SwiftUI
import MapKit

/// Детали места / поискового результата / AI рекомендации в bottom sheet (Apple Maps style)
struct MapPlaceDetailContent: View {
    @Bindable var vm: MapViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                switch vm.sheetContent {
                case .placeDetail:
                    if let place = vm.selectedPlace {
                        placeDetailView(place)
                    }
                case .searchItemDetail:
                    if let item = vm.searchedItem {
                        searchItemDetailView(item)
                    }
                case .aiResultDetail:
                    if let rec = vm.selectedAIResult {
                        aiResultDetailView(rec)
                    }
                default:
                    EmptyView()
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Detail Mode Views

    private func placeDetailView(_ place: Place) -> some View {
        unifiedDetailContent(
            name: place.name,
            subtitle: place.nameLocal.isEmpty ? place.category.rawValue : place.nameLocal,
            categoryIconName: categoryIconName(for: place.category),
            actionButtons: { AnyView(placeActionButtons(place: place)) },
            extraContent: {
                AnyView(
                    Group {
                        // Notes
                        if !place.notes.isEmpty {
                            sectionDivider
                            notesSection(place.notes)
                        }

                        // Route error
                        if let error = vm.routeError {
                            routeErrorRow(error)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }
                    }
                )
            },
            visitedBadge: place.isVisited
        )
    }

    private func searchItemDetailView(_ item: MKMapItem) -> some View {
        unifiedDetailContent(
            name: item.name ?? "",
            subtitle: vm.formatSearchAddress(item),
            categoryIconName: "mappin.circle.fill",
            actionButtons: { AnyView(searchActionButtons(item: item)) },
            extraContent: {
                AnyView(
                    Group {
                        // Add to trip button
                        addToTripButton {
                            vm.showDayPickerForAI = PlaceRecommendation.from(mapItem: item)
                        }

                        // Route error
                        if let error = vm.routeError {
                            routeErrorRow(error)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }
                    }
                )
            },
            visitedBadge: false
        )
    }

    private func aiResultDetailView(_ rec: PlaceRecommendation) -> some View {
        unifiedDetailContent(
            name: rec.name,
            subtitle: rec.category,
            categoryIconName: categoryIconNameFromString(rec.category),
            actionButtons: { AnyView(EmptyView()) },
            extraContent: {
                AnyView(
                    Group {
                        // Description
                        Text(rec.description)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)

                        // Address / estimated time
                        if !rec.address.isEmpty || !rec.estimatedTime.isEmpty {
                            sectionDivider
                            VStack(alignment: .leading, spacing: 0) {
                                if !rec.address.isEmpty {
                                    contactRow(icon: "mappin.circle.fill", label: "Адрес", value: rec.address, color: .secondary)
                                }
                                if !rec.estimatedTime.isEmpty {
                                    contactRow(icon: "clock", label: "Время", value: rec.estimatedTime, color: .secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Add to trip button
                        addToTripButton {
                            vm.showDayPickerForAI = rec
                        }
                    }
                )
            },
            visitedBadge: false
        )
    }

    // MARK: - Unified Layout

    private func unifiedDetailContent(
        name: String,
        subtitle: String?,
        categoryIconName: String,
        actionButtons: () -> AnyView,
        extraContent: () -> AnyView,
        visitedBadge: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero section: Look Around or first photo full-width
            heroSection(categoryIcon: categoryIconName)

            // Photo thumbnails below hero
            photoThumbnails

            // Left-aligned header with category icon
            placeHeaderNew(
                name: name,
                subtitle: subtitle,
                categoryIconName: categoryIconName
            )

            // Quick status row: open/closed, rating, price, visited
            quickStatusRow(visitedBadge: visitedBadge)
                .padding(.top, 8)

            // AI description (lazy-loaded inline)
            aiDescriptionSection(name: name, categoryIconName: categoryIconName)
                .padding(.top, 10)

            // Circular action buttons
            actionButtons()
                .padding(.top, 14)

            // Inline hours (today visible, expandable)
            if let detail = vm.googleDetail, !detail.weekdayHours.isEmpty {
                sectionDivider
                inlineHoursSection(hours: detail.weekdayHours)
                    .padding(.horizontal, 16)
            }

            // Merged contact info
            if vm.isLoadingInfo || vm.isLoadingGoogleDetail || hasContactInfo {
                sectionDivider
                mergedContactInfo
            }

            // Reviews
            if let detail = vm.googleDetail, !detail.reviews.isEmpty {
                sectionDivider
                reviewsSection(detail.reviews)
                    .padding(.horizontal, 16)
            }

            // Extra content (notes, add button, description, errors)
            extraContent()
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private func heroSection(categoryIcon: String) -> some View {
        if let scene = vm.lookAroundScene {
            LookAroundPreview(initialScene: scene)
                .frame(height: 200)
                .clipped()
        } else if vm.isLoadingLookAround {
            Color.primary.opacity(0.06)
                .frame(height: 200)
                .overlay { ProgressView() }
        } else if let firstPhoto = vm.googleDetail?.photoURLs.first {
            AsyncImage(url: firstPhoto) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                case .failure:
                    Color.primary.opacity(0.06)
                        .frame(height: 200)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundStyle(.tertiary)
                        }
                case .empty:
                    Color.primary.opacity(0.06)
                        .frame(height: 200)
                        .overlay { ProgressView() }
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            // Gradient placeholder with category icon
            LinearGradient(
                colors: [AppTheme.sakuraPink.opacity(0.15), AppTheme.sakuraPink.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 160)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: categoryIcon)
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.4))
                    Text("Нет фото")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Photo Thumbnails

    @ViewBuilder
    private var photoThumbnails: some View {
        let photos = vm.googleDetail?.photoURLs ?? []
        // Show thumbnails when Look Around is hero and any photos exist,
        // or when Look Around is absent and 2+ photos exist (first is hero)
        let showThumbnails: Bool = {
            if vm.lookAroundScene != nil {
                return !photos.isEmpty
            } else {
                return photos.count > 1
            }
        }()
        let thumbUrls = vm.lookAroundScene != nil ? photos : Array(photos.dropFirst())

        if showThumbnails && !thumbUrls.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(thumbUrls.enumerated()), id: \.offset) { _, url in
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            case .failure, .empty:
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(width: 84, height: 84)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Left-Aligned Header

    private func placeHeaderNew(name: String, subtitle: String?, categoryIconName: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Category icon badge
            Circle()
                .fill(AppTheme.sakuraPink.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: categoryIconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.sakuraPink)
                }

            // Name + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Close button
            Button(action: { vm.clearSelection() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Quick Status Row

    @ViewBuilder
    private func quickStatusRow(visitedBadge: Bool) -> some View {
        let openNow = vm.googleDetail?.openNow
        let rating = vm.googleDetail?.rating
        let ratingCount = vm.googleDetail?.userRatingCount
        let priceLevel = vm.googleDetail?.priceLevel

        let hasContent = openNow != nil || rating != nil || priceLevel != nil || visitedBadge

        if hasContent {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Open / closed capsule
                    if let open = openNow {
                        Text(open ? "Открыто" : "Закрыто")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(open ? AppTheme.bambooGreen : AppTheme.toriiRed)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background((open ? AppTheme.bambooGreen : AppTheme.toriiRed).opacity(0.12))
                            .clipShape(Capsule())
                    }

                    // Star rating with count
                    if let r = rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.templeGold)
                            Text(String(format: "%.1f", r))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            if let count = ratingCount, count > 0 {
                                Text("(\(count))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Price level
                    if let price = priceLevel, let label = priceLevelLabel(price) {
                        Text(label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    // Visited badge
                    if visitedBadge {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Посещено")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.bambooGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.bambooGreen.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func priceLevelLabel(_ level: String) -> String? {
        switch level {
        case "PRICE_LEVEL_FREE": return "Бесплатно"
        case "PRICE_LEVEL_INEXPENSIVE": return "₽"
        case "PRICE_LEVEL_MODERATE": return "₽₽"
        case "PRICE_LEVEL_EXPENSIVE": return "₽₽₽"
        case "PRICE_LEVEL_VERY_EXPENSIVE": return "₽₽₽₽"
        default: return nil
        }
    }

    // MARK: - Circular Action Buttons

    private func placeActionButtons(place: Place) -> some View {
        HStack(spacing: 20) {
            // Route (primary — filled circle)
            Button {
                Task { await vm.calculateDirectionRoute(to: place) }
            } label: {
                circularButton(
                    icon: vm.selectedTransportMode.icon,
                    label: vm.isCalculatingRoute ? "..." : "Маршрут",
                    filled: true
                )
            }
            .disabled(vm.isCalculatingRoute)

            // Phone
            if let phone = vm.appleMapsInfo?.phoneNumber ?? vm.googleDetail?.phone,
               !phone.isEmpty,
               let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))") {
                Link(destination: url) {
                    circularButton(icon: "phone.fill", label: "Вызов", filled: false)
                }
            }

            // Website
            if let url = vm.appleMapsInfo?.website ?? vm.googleDetail?.website.flatMap({ URL(string: $0) }) {
                Link(destination: url) {
                    circularButton(icon: "safari", label: "Сайт", filled: false)
                }
            }

            #if !targetEnvironment(simulator)
            // AR
            Button {
                vm.arPlace = place
            } label: {
                circularButton(icon: "arkit", label: "AR", filled: false, color: AppTheme.indigoPurple)
            }
            #endif
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    private func searchActionButtons(item: MKMapItem) -> some View {
        HStack(spacing: 20) {
            // Transport mode selector
            Menu {
                ForEach(TransportMode.allCases) { mode in
                    Button {
                        vm.selectedTransportMode = mode
                    } label: {
                        Label(mode.label, systemImage: mode.icon)
                    }
                }
            } label: {
                circularButton(
                    icon: vm.selectedTransportMode.icon,
                    label: vm.selectedTransportMode.label,
                    filled: false
                )
            }

            // Route (primary)
            Button {
                Task { await vm.calculateRouteToSearchedItem(item) }
            } label: {
                circularButton(
                    icon: "arrow.triangle.turn.up.right.diamond.fill",
                    label: vm.isCalculatingRoute ? "..." : "Маршрут",
                    filled: true
                )
            }
            .disabled(vm.isCalculatingRoute)

            // Phone
            if let phone = vm.appleMapsInfo?.phoneNumber ?? item.phoneNumber,
               !phone.isEmpty,
               let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))") {
                Link(destination: url) {
                    circularButton(icon: "phone.fill", label: "Вызов", filled: false)
                }
            }

            // Website
            if let url = vm.appleMapsInfo?.website ?? item.url {
                Link(destination: url) {
                    circularButton(icon: "safari", label: "Сайт", filled: false)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    private func circularButton(icon: String, label: String, filled: Bool, color: Color = AppTheme.sakuraPink) -> some View {
        VStack(spacing: 6) {
            ZStack {
                if filled {
                    Circle()
                        .fill(color)
                        .frame(width: 48, height: 48)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        )
                }
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(filled ? .white : color)
            }

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
        }
    }

    // MARK: - AI Description Section

    @ViewBuilder
    private func aiDescriptionSection(name: String, categoryIconName: String) -> some View {
        // Don't show for aiResultDetail (already has rec.description)
        if vm.sheetContent != .aiResultDetail {
            VStack(alignment: .leading, spacing: 8) {
                if vm.isLoadingAIDescription {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("AI описание...")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                } else if let description = vm.inlineAIDescription {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.sakuraPink)
                            Text("AI")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(AppTheme.sakuraPink)
                        }
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                            .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 16)
                }
            }
            .task(id: name) {
                let categoryStr: String = {
                    switch vm.sheetContent {
                    case .placeDetail:
                        return vm.selectedPlace?.category.rawValue ?? ""
                    case .searchItemDetail:
                        return vm.searchedItem?.pointOfInterestCategory?.rawValue ?? ""
                    default:
                        return ""
                    }
                }()
                let city: String? = {
                    switch vm.sheetContent {
                    case .placeDetail:
                        return vm.selectedPlace?.day?.cityName
                    default:
                        return nil
                    }
                }()
                await vm.loadInlineAIDescription(name: name, category: categoryStr, city: city)
            }
        }
    }

    // MARK: - Inline Hours

    private func inlineHoursSection(hours: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Today's hours inline
            let todayLine = todayHoursLine(from: hours)

            Button {
                withAnimation(.spring(response: 0.3)) { vm.showAllHours.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.sakuraPink)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Часы работы")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(todayLine)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: vm.showAllHours ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10)
            }

            // Expanded full schedule
            if vm.showAllHours {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(hours.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 32)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func todayHoursLine(from hours: [String]) -> String {
        // Google weekdayDescriptions is Monday=0 through Sunday=6
        // Calendar weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Convert: Sunday(1)->6, Monday(2)->0, ..., Saturday(7)->5
        let index = (weekday + 5) % 7
        guard index < hours.count else { return hours.first ?? "—" }
        return hours[index]
    }

    // MARK: - Merged Contact Info

    private var hasContactInfo: Bool {
        if let info = vm.appleMapsInfo {
            return info.localAddress != nil || info.phoneNumber != nil || info.website != nil
        }
        if let detail = vm.googleDetail {
            return detail.formattedAddress != nil || detail.phone != nil || detail.website != nil || detail.googleMapsURL != nil
        }
        return false
    }

    @ViewBuilder
    private var mergedContactInfo: some View {
        if vm.isLoadingInfo || vm.isLoadingGoogleDetail {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("Загрузка...")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Address: prefer Apple Maps, fallback Google
                let address = vm.appleMapsInfo?.localAddress ?? vm.googleDetail?.formattedAddress
                if let addr = address, !addr.isEmpty {
                    contactRow(icon: "mappin.circle.fill", label: "Адрес", value: addr, color: .secondary)
                }

                // Phone: prefer Apple Maps, fallback Google (deduplicated)
                let phone = vm.appleMapsInfo?.phoneNumber ?? vm.googleDetail?.phone
                if let ph = phone, !ph.isEmpty {
                    inlineDivider
                    contactRow(icon: "phone.fill", label: "Телефон", value: ph, color: AppTheme.sakuraPink, isLink: true)
                }

                // Website: prefer Apple Maps, fallback Google (deduplicated)
                let website: URL? = vm.appleMapsInfo?.website ?? vm.googleDetail?.website.flatMap { URL(string: $0) }
                if let url = website {
                    inlineDivider
                    contactRow(icon: "globe", label: "Сайт", value: url.host ?? url.absoluteString, color: AppTheme.sakuraPink, isLink: true)
                }

                // Google Maps link
                if let gMapsURL = vm.googleDetail?.googleMapsURL, let gUrl = URL(string: gMapsURL) {
                    inlineDivider
                    Link(destination: gUrl) {
                        contactRow(icon: "map.fill", label: "Google Maps", value: "Открыть", color: AppTheme.sakuraPink, isLink: true)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Reviews Section

    private func reviewsSection(_ reviews: [GooglePlaceReview]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // First review always visible
            if let first = reviews.first {
                reviewRow(first)
            }

            // Expand toggle
            if reviews.count > 1 {
                Button {
                    withAnimation(.spring(response: 0.3)) { vm.showAllReviews.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(vm.showAllReviews ? "Скрыть отзывы" : "Все отзывы (\(reviews.count))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.sakuraPink)
                        Image(systemName: vm.showAllReviews ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }

                if vm.showAllReviews {
                    VStack(spacing: 8) {
                        ForEach(Array(reviews.dropFirst().enumerated()), id: \.offset) { _, review in
                            reviewRow(review)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Add to Trip Button

    private func addToTripButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Добавить в маршрут")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(AppTheme.sakuraPink)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Category Icon Helpers

    private func categoryIconName(for category: PlaceCategory) -> String {
        switch category {
        case .food: return "fork.knife"
        case .museum: return "building.columns.fill"
        case .shopping: return "bag.fill"
        case .accommodation: return "bed.double.fill"
        case .temple, .culture, .palace: return "building.columns"
        case .shrine: return "sparkles"
        case .nature, .park, .garden: return "leaf.fill"
        case .gallery: return "photo.artframe"
        case .transport, .station, .metro: return "tram.fill"
        case .airport: return "airplane"
        case .lake: return "drop.fill"
        case .mountains: return "mountain.2.fill"
        case .sport: return "figure.run"
        case .stadium: return "sportscourt.fill"
        case .viewpoint: return "binoculars.fill"
        }
    }

    private func categoryIconNameFromString(_ category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("ресторан") || lower.contains("еда") || lower.contains("кафе") { return "fork.knife" }
        if lower.contains("музей") { return "building.columns.fill" }
        if lower.contains("шопинг") || lower.contains("магазин") { return "bag.fill" }
        if lower.contains("отель") || lower.contains("жильё") || lower.contains("хостел") { return "bed.double.fill" }
        if lower.contains("храм") || lower.contains("церковь") || lower.contains("собор") { return "building.columns" }
        if lower.contains("парк") || lower.contains("природа") { return "leaf.fill" }
        if lower.contains("транспорт") || lower.contains("вокзал") { return "tram.fill" }
        if lower.contains("аэропорт") { return "airplane" }
        if lower.contains("смотровая") { return "binoculars.fill" }
        return "mappin.circle.fill"
    }

    // MARK: - Shared Components

    private func contactRow(icon: String, label: String, value: String, color: Color, isLink: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(isLink ? AppTheme.sakuraPink : .primary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private var inlineDivider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(height: 0.5)
            .padding(.leading, 48)
    }

    private func routeErrorRow(_ error: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
            Text(error)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .foregroundStyle(AppTheme.toriiRed)
    }

    // MARK: - Review Row

    private func reviewRow(_ review: GooglePlaceReview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: i < review.rating ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundStyle(i < review.rating ? AppTheme.templeGold : Color.gray.opacity(0.3))
                    }
                }
                Text(review.authorName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(review.relativeTime)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Text(review.text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(5)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3)) { vm.isNotesExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("Заметки")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: vm.isNotesExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            if vm.isNotesExpanded {
                Text(notes)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
    }
}
