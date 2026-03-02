import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var hasCompletedOnboarding: Bool

    @State private var step: OnboardingStep = .welcome
    @State private var animateIn = false

    // Trip creation fields
    @State private var tripName = ""
    @State private var destination = ""
    @State private var startDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 3, day: 15)
    ) ?? Date()
    @State private var endDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 3, day: 28)
    ) ?? Date()
    @State private var budget = ""
    @State private var flightDateEnabled = false
    @State private var flightDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 3, day: 13, hour: 10, minute: 0)
    ) ?? Date()

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case createTrip
        case permissions
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                progressBar

                switch step {
                case .welcome:
                    welcomeStep
                case .createTrip:
                    createTripStep
                case .permissions:
                    permissionsStep
                }
            }
        }
        .sakuraGradientBackground()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateIn = true
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? AppTheme.sakuraPink : AppTheme.sakuraPink.opacity(0.2))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingS)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("JP")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.sakuraPink)
                .frame(width: 120, height: 120)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusXL)
                        .strokeBorder(
                            LinearGradient(
                                colors: [AppTheme.sakuraPink.opacity(0.5), AppTheme.sakuraPink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: AppTheme.sakuraPink.opacity(0.2), radius: 20, x: 0, y: 10)
                .scaleEffect(animateIn ? 1.0 : 0.5)
                .opacity(animateIn ? 1.0 : 0)

            Spacer().frame(height: AppTheme.spacingXL)

            Text("JAPAN TRAVEL")
                .font(.system(size: 22, weight: .bold))
                .tracking(6)
                .foregroundStyle(.primary)

            Spacer().frame(height: AppTheme.spacingS)

            Text("Планируйте, отслеживайте\nи запоминайте путешествие")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: AppTheme.spacingM)

            featureRow(icon: "map.fill", text: "Маршруты и карта", color: AppTheme.oceanBlue)
            featureRow(icon: "rublesign.circle.fill", text: "Бюджет и расходы", color: AppTheme.templeGold)
            featureRow(icon: "location.fill", text: "GPS-треки маршрутов", color: AppTheme.bambooGreen)

            Spacer()

            actionButton(title: "НАЧАТЬ", color: AppTheme.sakuraPink) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    step = .createTrip
                }
            }

            useSampleDataButton
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingXL)
    }

    private func featureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

            Text(text.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacingS)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, 2)
    }

    // MARK: - Step 2: Create Trip

    private var createTripStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingM) {
                SheetHeader(icon: "airplane", title: "СОЗДАТЬ ПОЕЗДКУ", color: AppTheme.sakuraPink)

                GlassFormField(label: "НАЗВАНИЕ ПОЕЗДКИ", color: AppTheme.sakuraPink) {
                    TextField("Путешествие по Японии", text: $tripName)
                        .textFieldStyle(GlassTextFieldStyle())
                }

                GlassFormField(label: "НАПРАВЛЕНИЕ", color: AppTheme.oceanBlue) {
                    TextField("Япония", text: $destination)
                        .textFieldStyle(GlassTextFieldStyle())
                }

                HStack(spacing: AppTheme.spacingS) {
                    GlassFormField(label: "НАЧАЛО", color: AppTheme.bambooGreen) {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
                    }
                    GlassFormField(label: "КОНЕЦ", color: AppTheme.toriiRed) {
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
                    }
                }

                GlassFormField(label: "БЮДЖЕТ (RUB)", color: AppTheme.templeGold) {
                    TextField("350000", text: $budget)
                        .keyboardType(.numberPad)
                        .textFieldStyle(GlassTextFieldStyle())
                }

                // Flight toggle
                VStack(spacing: 0) {
                    HStack {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppTheme.oceanBlue)
                                .frame(width: 3, height: 12)
                            Text("РЕЙС")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(AppTheme.oceanBlue)
                        }
                        Spacer()
                        Toggle("", isOn: $flightDateEnabled)
                            .tint(AppTheme.sakuraPink)
                            .labelsHidden()
                    }
                    .padding(AppTheme.spacingM)

                    if flightDateEnabled {
                        DatePicker("", selection: $flightDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.sakuraPink)
                            .padding(.horizontal, AppTheme.spacingM)
                            .padding(.bottom, AppTheme.spacingM)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
                )
            }
            .padding(AppTheme.spacingM)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: AppTheme.spacingS) {
                actionButton(title: "ДАЛЕЕ", color: AppTheme.sakuraPink) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        step = .permissions
                    }
                }
                .disabled(!isTripValid)
                .opacity(isTripValid ? 1.0 : 0.5)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        step = .welcome
                    }
                } label: {
                    Text("НАЗАД")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingM)
        }
    }

    private var isTripValid: Bool {
        !tripName.trimmingCharacters(in: .whitespaces).isEmpty
            && !destination.trimmingCharacters(in: .whitespaces).isEmpty
            && endDate > startDate
    }

    // MARK: - Step 3: Permissions

    private var permissionsStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: AppTheme.spacingM) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AppTheme.bambooGreen)
                    .frame(width: 80, height: 80)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusXL)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppTheme.bambooGreen.opacity(0.4), AppTheme.bambooGreen.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: AppTheme.bambooGreen.opacity(0.15), radius: 16, x: 0, y: 8)

                Text("РАЗРЕШЕНИЯ")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(.primary)

                Text("Для лучшей работы приложения")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                permissionCard(
                    icon: "bell.fill",
                    title: "УВЕДОМЛЕНИЯ",
                    description: "Утренний план, напоминания о событиях, бюджет",
                    color: AppTheme.sakuraPink
                ) {
                    NotificationManager.shared.requestPermission()
                }

                permissionCard(
                    icon: "location.fill",
                    title: "ГЕОЛОКАЦИЯ",
                    description: "GPS-треки маршрутов в стиле Strava",
                    color: AppTheme.oceanBlue
                ) {
                    LocationManager.shared.requestPermission()
                }
            }
            .padding(.horizontal, AppTheme.spacingM)

            Spacer()

            VStack(spacing: AppTheme.spacingS) {
                actionButton(title: "ГОТОВО", color: AppTheme.bambooGreen) {
                    createTripAndFinish()
                }

                Button {
                    createTripAndFinish()
                } label: {
                    Text("ПРОПУСТИТЬ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }

    private func permissionCard(
        icon: String,
        title: String,
        description: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingS) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }

                Spacer()

                Text("РАЗРЕШИТЬ")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(color)
                    .clipShape(Capsule())
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(color.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Shared Components

    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .tracking(4)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var useSampleDataButton: some View {
        Button {
            SampleData.seed(into: modelContext)
            hasCompletedOnboarding = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12, weight: .bold))
                Text("ДЕМО-ДАННЫЕ ЯПОНИИ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
            }
            .foregroundStyle(.tertiary)
            .padding(.top, AppTheme.spacingM)
        }
    }

    // MARK: - Actions

    private func createTripAndFinish() {
        let budgetValue = Double(budget) ?? 350000
        let trip = Trip(
            name: tripName.trimmingCharacters(in: .whitespaces),
            destination: destination.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: endDate,
            budget: budgetValue,
            currency: "RUB",
            coverSystemImage: "airplane",
            flightDate: flightDateEnabled ? flightDate : nil
        )
        modelContext.insert(trip)

        Task { await NotificationManager.shared.scheduleAll(for: trip) }

        hasCompletedOnboarding = true
    }
}

#if DEBUG
#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .modelContainer(for: Trip.self, inMemory: true)
}
#endif
