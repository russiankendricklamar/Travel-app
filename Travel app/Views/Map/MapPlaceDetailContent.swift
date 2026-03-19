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

    // MARK: - Place Detail

    private func placeDetailView(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo carousel
            if let photos = vm.googleDetail?.photoURLs, !photos.isEmpty {
                photoCarousel(photos)
            }

            // Header (centered like Apple Maps)
            placeHeader(
                name: place.name,
                subtitle: place.nameLocal.isEmpty ? place.category.rawValue : place.nameLocal,
                close: { vm.clearSelection() }
            )

            // Action buttons row (Apple Maps style)
            actionButtonsRow(place: place)
                .padding(.top, 12)

            // Quick info row (hours / rating / distance)
            quickInfoRow(place: place)
                .padding(.top, 14)

            // Google Places details
            if vm.isLoadingGoogleDetail || vm.googleDetail != nil {
                sectionDivider
                googlePlaceDetailsBlock
            }

            // Apple Maps info (address, phone, website)
            if vm.isLoadingInfo || vm.appleMapsInfo != nil || !place.address.isEmpty {
                sectionDivider
                contactInfoBlock(place: place)
            }

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
    }

    // MARK: - Search Item Detail

    private func searchItemDetailView(_ item: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo carousel
            if let photos = vm.googleDetail?.photoURLs, !photos.isEmpty {
                photoCarousel(photos)
            }

            placeHeader(
                name: item.name ?? "",
                subtitle: vm.formatSearchAddress(item),
                close: { vm.clearSelection() }
            )

            // Route action row
            searchActionRow(item: item)
                .padding(.top, 12)

            // Contact info
            if item.phoneNumber != nil || item.url != nil {
                sectionDivider
                VStack(alignment: .leading, spacing: 0) {
                    if let phone = item.phoneNumber, !phone.isEmpty {
                        contactRow(icon: "phone.fill", label: "Телефон", value: phone, color: AppTheme.sakuraPink)
                    }
                    if let url = item.url {
                        contactRow(icon: "globe", label: "Сайт", value: url.host ?? url.absoluteString, color: AppTheme.sakuraPink)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Add to trip button
            Button {
                vm.showDayPickerForAI = PlaceRecommendation.from(mapItem: item)
            } label: {
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

            if let error = vm.routeError {
                routeErrorRow(error)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - AI Result Detail

    private func aiResultDetailView(_ rec: PlaceRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            placeHeader(
                name: rec.name,
                subtitle: rec.category,
                close: { vm.clearSelection() }
            )

            Text(rec.description)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 10)

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

            Button {
                vm.showDayPickerForAI = rec
            } label: {
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
    }

    // MARK: - Photo Carousel

    private func photoCarousel(_ urls: [URL]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(urls.enumerated()), id: \.offset) { _, url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: urls.count == 1 ? UIScreen.main.bounds.width - 32 : 260, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        case .failure:
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                                .frame(width: 260, height: 180)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.tertiary)
                                }
                        case .empty:
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                                .frame(width: 260, height: 180)
                                .overlay { ProgressView() }
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Header (Apple Maps centered style)

    private func placeHeader(name: String, subtitle: String?, close: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            // Close + title row
            ZStack {
                // Close button — left (share in Apple Maps, we use close)
                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }

                // Centered title
                VStack(spacing: 3) {
                    Text(name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 44) // room for buttons
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Action Buttons (Apple Maps pill style)

    private func actionButtonsRow(place: Place) -> some View {
        HStack(spacing: 8) {
            // Route button (primary — filled)
            Button {
                Task { await vm.calculateDirectionRoute(to: place) }
            } label: {
                actionPill(
                    icon: vm.selectedTransportMode.icon,
                    label: vm.isCalculatingRoute ? "..." : "Маршрут",
                    filled: true,
                    color: AppTheme.sakuraPink
                )
            }
            .disabled(vm.isCalculatingRoute)

            // Phone button
            if let phone = vm.appleMapsInfo?.phoneNumber ?? extractPhone(for: place),
               let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))") {
                Link(destination: url) {
                    actionPill(icon: "phone.fill", label: "Вызов", filled: false, color: AppTheme.sakuraPink)
                }
            }

            // Website button
            if let url = vm.appleMapsInfo?.website ?? vm.googleDetail?.website.flatMap({ URL(string: $0) }) {
                Link(destination: url) {
                    actionPill(icon: "safari", label: "Веб-сайт", filled: false, color: AppTheme.sakuraPink)
                }
            }

            #if !targetEnvironment(simulator)
            // AR button
            Button {
                vm.arPlace = place
            } label: {
                actionPill(icon: "arkit", label: "AR", filled: false, color: AppTheme.indigoPurple)
            }
            #endif
        }
        .padding(.horizontal, 16)
    }

    private func actionPill(icon: String, label: String, filled: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(filled ? .white : color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(filled ? color : color.opacity(0.15))
        )
    }

    // MARK: - Quick Info Row

    private func quickInfoRow(place: Place) -> some View {
        HStack(spacing: 0) {
            // Hours status
            if let openNow = vm.googleDetail?.openNow {
                quickInfoItem(
                    title: "Часы работы",
                    value: openNow ? "открыто" : "закрыто",
                    valueColor: openNow ? AppTheme.bambooGreen : AppTheme.toriiRed
                )

                quickInfoDivider
            }

            // Rating
            let ratingValue: Double? = vm.googleDetail?.rating ?? place.rating.map(Double.init)
            if let rating = ratingValue {
                quickInfoItem(
                    title: "\(vm.googleDetail?.userRatingCount ?? 0) оценок",
                    value: String(format: "%.1f", rating),
                    icon: "star.fill",
                    iconColor: AppTheme.templeGold
                )

                quickInfoDivider
            }

            // Category badge
            quickInfoItem(
                title: "Категория",
                value: place.category.rawValue,
                valueColor: AppTheme.categoryColor(for: place.category.rawValue)
            )

            if place.isVisited {
                quickInfoDivider
                quickInfoItem(
                    title: "Статус",
                    value: "посещено",
                    icon: "checkmark.circle.fill",
                    iconColor: AppTheme.bambooGreen
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private func quickInfoItem(title: String, value: String, icon: String? = nil, iconColor: Color? = nil, valueColor: Color? = nil) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(iconColor ?? .primary)
                }
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(valueColor ?? .primary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var quickInfoDivider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Search Action Row

    private func searchActionRow(item: MKMapItem) -> some View {
        HStack(spacing: 8) {
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
                actionPill(
                    icon: vm.selectedTransportMode.icon,
                    label: vm.selectedTransportMode.label,
                    filled: false,
                    color: AppTheme.sakuraPink
                )
            }

            // Route button
            Button {
                Task { await vm.calculateRouteToSearchedItem(item) }
            } label: {
                actionPill(
                    icon: "arrow.triangle.turn.up.right.diamond.fill",
                    label: vm.isCalculatingRoute ? "..." : "Маршрут",
                    filled: true,
                    color: AppTheme.sakuraPink
                )
            }
            .disabled(vm.isCalculatingRoute)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Contact Info Block

    private func contactInfoBlock(place: Place) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if vm.isLoadingInfo {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Загрузка...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else if let info = vm.appleMapsInfo {
                if let addr = info.localAddress {
                    contactRow(icon: "mappin.circle.fill", label: "Адрес", value: addr, color: .secondary)
                }
                if let phone = info.phoneNumber, !phone.isEmpty {
                    inlineDivider
                    contactRow(icon: "phone.fill", label: "Телефон", value: phone, color: AppTheme.sakuraPink, isLink: true)
                }
                if let url = info.website {
                    inlineDivider
                    contactRow(icon: "globe", label: "Сайт", value: url.host ?? url.absoluteString, color: AppTheme.sakuraPink, isLink: true)
                }
            } else if !place.address.isEmpty {
                contactRow(icon: "mappin.circle.fill", label: "Адрес", value: place.address, color: .secondary)
            }
        }
        .padding(.horizontal, 16)
    }

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

    // MARK: - Google Places Block

    @ViewBuilder
    private var googlePlaceDetailsBlock: some View {
        if vm.isLoadingGoogleDetail {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text("Google Places...")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        } else if let detail = vm.googleDetail {
            VStack(alignment: .leading, spacing: 0) {
                // Hours (collapsible)
                if !detail.weekdayHours.isEmpty {
                    collapsibleSection(
                        title: "Часы работы",
                        icon: "clock",
                        isExpanded: vm.showAllHours,
                        toggle: { vm.showAllHours.toggle() }
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(detail.weekdayHours, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Reviews (collapsible)
                if !detail.reviews.isEmpty {
                    inlineDivider
                    collapsibleSection(
                        title: "Отзывы (\(detail.reviews.count))",
                        icon: "text.quote",
                        isExpanded: vm.showAllReviews,
                        toggle: { vm.showAllReviews.toggle() }
                    ) {
                        VStack(spacing: 8) {
                            ForEach(Array(detail.reviews.enumerated()), id: \.offset) { _, review in
                                reviewRow(review)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Shared Components

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

    // MARK: - Collapsible Section

    private func collapsibleSection<Content: View>(
        title: String,
        icon: String,
        isExpanded: Bool,
        toggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3)) { toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
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

    // MARK: - Helpers

    private func extractPhone(for place: Place) -> String? {
        vm.googleDetail?.phone
    }
}

