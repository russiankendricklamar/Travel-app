import SwiftUI
import LocalAuthentication

struct ModeSwitcherView: View {
    @Binding var isPresented: Bool
    var onModeSelected: (AppMode) -> Void

    @AppStorage("appMode") private var appMode: String = AppMode.personal.rawValue
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue
    @State private var appeared = false
    @State private var authFailed = false

    private var currentMode: AppMode {
        AppMode(rawValue: appMode) ?? .personal
    }

    private var accent: Color {
        (ColorPalette(rawValue: palette) ?? .sakura).accentColor
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Dimmed backdrop
            Color.black.opacity(appeared ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Dropdown card
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.2.swap")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accent)
                    Text("РЕЖИМ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(accent)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }

                modeRow(.personal)
                modeRow(.corporate)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(accent.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .offset(y: appeared ? 0 : -200)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .alert("Не удалось авторизоваться", isPresented: $authFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Для входа в корпоративный режим требуется Face ID")
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }

    private func performSwitch(to mode: AppMode) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
            onModeSelected(mode)
        }
    }

    private func authenticateAndSwitch(to mode: AppMode) async {
        let context = LAContext()
        context.localizedCancelTitle = "Отмена"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // No biometrics — fall back to passcode
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Авторизация для корпоративного режима"
                )
                if success {
                    await MainActor.run { performSwitch(to: mode) }
                }
            } catch {
                await MainActor.run { authFailed = true }
            }
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Авторизация для корпоративного режима"
            )
            if success {
                await MainActor.run { performSwitch(to: mode) }
            }
        } catch {
            await MainActor.run { authFailed = true }
        }
    }

    private func modeRow(_ mode: AppMode) -> some View {
        let isSelected = currentMode == mode
        let isCorp = mode == .corporate

        // Corporate mode disabled — using sakura as placeholder
        let previewColors: [Color] = isCorp
            ? ColorPalette.sakura.backgroundColors
            : (ColorPalette(rawValue: UserDefaults.standard.string(forKey: "savedPersonalPalette") ?? palette) ?? .sakura).backgroundColors

        let modeAccent: Color = isCorp
            ? ColorPalette.sakura.accentColor
            : (ColorPalette(rawValue: UserDefaults.standard.string(forKey: "savedPersonalPalette") ?? palette) ?? .sakura).accentColor

        return Button {
            guard !isSelected else { return }
            if mode == .corporate {
                Task { await authenticateAndSwitch(to: mode) }
            } else {
                performSwitch(to: mode)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                        .fill(
                            LinearGradient(
                                colors: Array(previewColors.prefix(3)),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: mode.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isCorp ? CorporateColors.electricBlue : .white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(mode.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        if isCorp && !isSelected {
                            Image(systemName: "faceid")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Text(mode.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(modeAccent)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(12)
            .background(isSelected ? modeAccent.opacity(0.08) : Color.clear)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(isSelected ? modeAccent.opacity(0.25) : Color.white.opacity(0.08), lineWidth: isSelected ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
