import SwiftUI

/// Navigation sheet body with peek and expanded layouts.
/// Peek mode shows a compact row with the current instruction and ETA.
/// Expanded mode shows the full step list and a stop button.
struct NavigationSheetContent: View {
    @Bindable var vm: MapViewModel

    private var currentStep: NavigationStep? {
        guard vm.currentStepIndex < vm.navigationSteps.count else { return nil }
        return vm.navigationSteps[vm.currentStepIndex]
    }

    var body: some View {
        switch vm.sheetDetent {
        case .peek:
            peekContent
        case .half, .full:
            expandedContent
        }
    }

    // MARK: - Peek

    private var peekContent: some View {
        HStack(spacing: 8) {
            // Direction icon
            Image(systemName: NavigationHUDView.iconForInstruction(currentStep?.instruction ?? ""))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.sakuraPink)
                .frame(width: 32, height: 32)

            // Instruction + context
            VStack(alignment: .leading, spacing: 4) {
                Text(currentStep?.instruction ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(vm.tripContextLabel)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // ETA
            VStack(alignment: .trailing, spacing: 4) {
                Text(vm.etaString)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.sakuraPink)
                Text("прибытие")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.navigationSteps.enumerated()), id: \.offset) { index, step in
                        StepRow(
                            step: step,
                            index: index,
                            isCurrent: index == vm.currentStepIndex
                        )
                    }
                }
            }

            Divider()

            // Stop navigation button
            Button {
                vm.stopNavigation()
            } label: {
                Text("Завершить навигацию")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                            .fill(AppTheme.sakuraPink)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - StepRow

private struct StepRow: View {
    let step: NavigationStep
    let index: Int
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Accent bar
            Rectangle()
                .fill(isCurrent ? AppTheme.sakuraPink : Color.clear)
                .frame(width: 4, height: 32)

            // Direction icon
            Image(systemName: NavigationHUDView.iconForInstruction(step.instruction))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isCurrent ? AppTheme.sakuraPink : .secondary)
                .frame(width: 24, height: 24)

            // Instruction + distance
            VStack(alignment: .leading, spacing: 4) {
                Text(step.instruction)
                    .font(.system(size: 14, weight: isCurrent ? .semibold : .regular))
                Text(RoutingService.formatDistance(step.distance))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
