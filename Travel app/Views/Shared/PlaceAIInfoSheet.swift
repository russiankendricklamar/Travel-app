import SwiftUI

struct PlaceAIInfoSheet: View {
    let place: Place
    let cityName: String
    @Environment(\.dismiss) private var dismiss

    @State private var info: PlaceInfo?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    // Place header
                    VStack(spacing: 6) {
                        Image(systemName: place.category.systemImage)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppTheme.sakuraPink)
                            .frame(width: 56, height: 56)
                            .background(AppTheme.sakuraPink.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Text(place.name)
                            .font(.system(size: 18, weight: .bold))
                            .multilineTextAlignment(.center)

                        if !place.nameLocal.isEmpty {
                            Text(place.nameLocal)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }

                        CategoryBadge(category: place.category)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppTheme.spacingM)

                    // Content
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(AppTheme.sakuraPink)
                            Text("ИИ изучает место...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if let error {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28))
                                .foregroundStyle(AppTheme.templeGold)
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Повторить") {
                                Task { await fetchInfo() }
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.sakuraPink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if let info {
                        infoContent(info)
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingXL)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ИИ-СПРАВКА")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task { await fetchInfo() }
    }

    private func infoContent(_ info: PlaceInfo) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            if !info.history.isEmpty {
                infoSection(
                    icon: "scroll",
                    title: "ИСТОРИЯ",
                    color: AppTheme.templeGold,
                    text: info.history
                )
            }

            if !info.tips.isEmpty {
                infoSection(
                    icon: "lightbulb",
                    title: "СОВЕТЫ",
                    color: AppTheme.bambooGreen,
                    text: info.tips
                )
            }

            // Source
            HStack {
                Spacer()
                Text("Источник: \(info.source)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    private func infoSection(icon: String, title: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(color)
            }

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.primary)
                .lineSpacing(5)
        }
        .padding(AppTheme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(color.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func fetchInfo() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let result = await PlaceInfoService.shared.fetchInfo(
            placeName: place.name,
            category: place.category.rawValue,
            city: cityName
        )

        if let result {
            info = result
        } else {
            error = PlaceInfoService.shared.lastError ?? String(localized: "Не удалось получить информацию. Проверьте API-ключ в Настройках.")
        }
    }
}
