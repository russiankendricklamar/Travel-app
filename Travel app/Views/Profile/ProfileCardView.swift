import SwiftUI

struct ProfileCardView: View {
    var onTap: () -> Void
    var onSetup: () -> Void
    var onLongPress: (() -> Void)?

    private let profileService = ProfileService.shared
    private let authManager = AuthManager.shared

    // @AppStorage("appMode") private var appMode: String = AppMode.personal.rawValue

    // Corporate mode disabled
    // private var isCorporate: Bool {
    //     AppMode(rawValue: appMode) == .corporate
    // }

    var body: some View {
        Group {
            if let profile = profileService.profile, profile.hasData {
                filledCard(profile)
            } else {
                emptyCard
            }
        }
    }

    // MARK: - Filled Card

    private func filledCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    // Corporate badge (disabled)
                    // if isCorporate {
                    //     Image(systemName: "building.2.fill")
                    //         ...
                    // }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !profile.homeCity.isEmpty || !profile.homeCountry.isEmpty {
                        Text([profile.homeCity, profile.homeCountry].filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Corporate mode indicator (disabled)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
            }

            // Mini badges
            HStack(spacing: 8) {
                if let ageText = profile.ageFormatted {
                    badgeItem(icon: "birthday.cake.fill", text: ageText)
                }
                badgeItem(icon: profile.chronotype.icon, text: profile.chronotype.label)
                badgeItem(icon: profile.travelPace.icon, text: profile.travelPace.label)
                if !profile.visitedCountries.isEmpty {
                    badgeItem(icon: "globe", text: "\(profile.visitedCountries.count) стран")
                }
                Spacer()
            }
            .padding(.top, 10)
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress?()
        }
    }

    private func badgeItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.7))
            Text(text)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.sakuraPink.opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - Empty Card

    private var emptyCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.sakuraPink.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.sakuraPink.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("ЗАПОЛНИТЬ ПРОФИЛЬ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("Персонализируйте рекомендации")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSetup()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress?()
        }
    }
}
