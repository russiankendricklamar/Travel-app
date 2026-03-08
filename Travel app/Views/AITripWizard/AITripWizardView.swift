import SwiftUI

struct AITripWizardView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var destination = ""
    @State private var originIata = "MOW"
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var budget: Double? = 150_000
    @State private var styles: [TravelStyle] = []

    @State private var isGenerating = false
    @State private var generatedTrip: AIGeneratedTrip?
    @State private var showPreview = false
    @State private var errorMessage: String?

    private let service = AITripGeneratorService.shared

    var body: some View {
        ZStack {
            // Background
            Color.clear
                .sakuraGradientBackground()
                .ignoresSafeArea()

            if isGenerating {
                AITripLoadingView(phase: service.generationPhase)
            } else {
                VStack(spacing: 0) {
                    topBar
                    stepIndicator

                    TabView(selection: $step) {
                        WizardStepDestination(
                            destination: $destination,
                            originIata: $originIata,
                            onNext: { withAnimation { step = 1 } }
                        )
                        .tag(0)

                        WizardStepDates(
                            startDate: $startDate,
                            endDate: $endDate,
                            destination: destination,
                            onNext: { withAnimation { step = 2 } }
                        )
                        .tag(1)

                        WizardStepBudget(
                            budget: $budget,
                            onNext: { withAnimation { step = 3 } }
                        )
                        .tag(2)

                        WizardStepStyle(
                            styles: $styles,
                            onGenerate: { generateTrip() }
                        )
                        .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: step)
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            if let trip = generatedTrip {
                AITripPreviewView(
                    trip: trip,
                    budget: budget,
                    onRegenerate: {
                        showPreview = false
                        generateTrip()
                    }
                )
            }
        }
        .alert("Ошибка", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            if step > 0 && !isGenerating {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("НАЗАД")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingS)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? AppTheme.sakuraPink : AppTheme.sakuraPink.opacity(0.2))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .padding(.horizontal, AppTheme.spacingXL)
        .padding(.vertical, AppTheme.spacingS)
    }

    // MARK: - Generate

    private func generateTrip() {
        isGenerating = true
        let input = WizardInput(
            destination: destination,
            originIata: originIata.isEmpty ? "MOW" : originIata,
            startDate: startDate,
            endDate: endDate,
            budget: budget,
            currency: "RUB",
            styles: styles.isEmpty ? [.cultural] : styles
        )

        Task {
            let profileContext = AIPromptHelper.profileContext()
            let result = await service.generateTrip(input: input, profileContext: profileContext)
            isGenerating = false

            if let trip = result {
                generatedTrip = trip
                showPreview = true
            } else {
                errorMessage = service.lastError ?? "Не удалось сгенерировать поездку"
            }
        }
    }
}
