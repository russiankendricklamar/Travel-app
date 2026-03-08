import SwiftUI

struct SecureVaultView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue
    @AppStorage("vaultDisclaimerAccepted") private var disclaimerAccepted = false

    @State private var service = SecureVaultService.shared
    @State private var isUnlocking = false
    @State private var showAddDocument = false
    @State private var showAddLoyalty = false
    @State private var showDisclaimer = false

    private var accent: Color {
        (ColorPalette(rawValue: palette) ?? .sakura).accentColor
    }

    var body: some View {
        NavigationStack {
            Group {
                if service.isUnlocked {
                    if !disclaimerAccepted {
                        disclaimerView
                    } else {
                        unlockedContent
                    }
                } else {
                    lockedView
                }
            }
            .sakuraGradientBackground()
            .navigationTitle("Документы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ЗАКРЫТЬ") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
            }
            .onDisappear {
                service.lock()
            }
            .sheet(isPresented: $showAddDocument) {
                AddDocumentSheet { doc in
                    try? service.addDocument(doc)
                }
            }
            .sheet(isPresented: $showAddLoyalty) {
                AddLoyaltySheet { program in
                    try? service.addLoyalty(program)
                }
            }
        }
    }

    // MARK: - Locked View

    private var lockedView: some View {
        VStack(spacing: AppTheme.spacingL) {
            Spacer()

            ZStack {
                Circle()
                    .fill(accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Circle()
                    .fill(accent.opacity(0.05))
                    .frame(width: 140, height: 140)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 8) {
                Text("Защищённое хранилище")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Паспорта, визы, страховки\nи программы лояльности")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                unlockVault()
            } label: {
                HStack(spacing: 8) {
                    if isUnlocking {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "faceid")
                            .font(.system(size: 18))
                    }
                    Text("Разблокировать")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: accent.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .disabled(isUnlocking)
            .padding(.horizontal, AppTheme.spacingXL)

            Spacer()
            Spacer()
        }
        .padding(AppTheme.spacingM)
    }

    // MARK: - Disclaimer View

    private var disclaimerView: some View {
        VStack(spacing: AppTheme.spacingL) {
            Spacer()

            VStack(spacing: AppTheme.spacingM) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(accent)

                Text("Безопасность данных")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Мы не передаём ваши данные третьим лицам. Все данные хранятся в строго зашифрованном виде (AES-256) по стандартам безопасности и используются исключительно для улучшения рекомендаций ИИ в обезличенном виде. Вы имеете полное право не заполнять эти данные — функционал приложения от этого не изменится.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(AppTheme.spacingL)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(accent.opacity(0.15), lineWidth: 0.5)
            )
            .padding(.horizontal, AppTheme.spacingM)

            VStack(spacing: AppTheme.spacingS) {
                Button {
                    disclaimerAccepted = true
                } label: {
                    Text("ПОНЯТНО")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: accent.opacity(0.3), radius: 8, x: 0, y: 4)
                }

                Button {
                    dismiss()
                } label: {
                    Text("НЕ СЕЙЧАС")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, AppTheme.spacingL)

            Spacer()
        }
        .padding(AppTheme.spacingM)
    }

    // MARK: - Unlocked Content

    private var unlockedContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingS) {
                // Documents section
                documentsSection

                // Loyalty programs section
                loyaltySection

                // Security footer
                securityFooter
                    .padding(.top, AppTheme.spacingM)

                Spacer(minLength: 40)
            }
            .padding(AppTheme.spacingM)
        }
    }

    // MARK: - Documents Section

    private var documentsSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            HStack {
                GlassSectionHeader(title: "ДОКУМЕНТЫ", color: accent)
                Spacer()
                Button {
                    showAddDocument = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(accent)
                }
                .padding(.trailing, AppTheme.spacingM)
            }

            if let documents = service.vault?.documents, !documents.isEmpty {
                ForEach(documents) { doc in
                    DocumentCard(document: doc) {
                        try? service.removeDocument(id: doc.id)
                    }
                }
            } else {
                emptyState(
                    icon: "doc.text.fill",
                    title: "Нет документов",
                    subtitle: "Добавьте паспорт, визу или страховку"
                )
            }
        }
    }

    // MARK: - Loyalty Section

    private var loyaltySection: some View {
        VStack(spacing: AppTheme.spacingS) {
            HStack {
                GlassSectionHeader(title: "ПРОГРАММЫ ЛОЯЛЬНОСТИ", color: AppTheme.indigoPurple)
                Spacer()
                Button {
                    showAddLoyalty = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.indigoPurple)
                }
                .padding(.trailing, AppTheme.spacingM)
            }

            if let programs = service.vault?.loyaltyPrograms, !programs.isEmpty {
                ForEach(programs) { program in
                    LoyaltyCard(program: program) {
                        try? service.removeLoyalty(id: program.id)
                    }
                }
            } else {
                emptyState(
                    icon: "star.circle.fill",
                    title: "Нет программ",
                    subtitle: "Добавьте бонусные карты авиакомпаний и отелей"
                )
            }
        }
    }

    // MARK: - Security Footer

    private var securityFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
            Text("Ваши данные зашифрованы (AES-256) и не передаются третьим лицам. Используются только для персонализации рекомендаций в обезличенном виде.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineSpacing(2)
        }
        .padding(.horizontal, AppTheme.spacingM)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingL)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Actions

    private func unlockVault() {
        isUnlocking = true
        Task {
            let success = await service.unlock()
            await MainActor.run {
                isUnlocking = false
                if success && !disclaimerAccepted {
                    showDisclaimer = true
                }
            }
        }
    }
}
