import SwiftUI
import MapKit

/// Floating maneuver card shown during active turn-by-turn navigation.
/// Displays direction icon, current instruction, distance to next step,
/// and a dismiss button. Activates urgent styling when distance < 50m.
struct NavigationHUDView: View {
    @Bindable var vm: MapViewModel
    @Environment(\.colorScheme) private var scheme

    private var currentStep: NavigationStep? {
        guard vm.currentStepIndex < vm.navigationSteps.count else { return nil }
        return vm.navigationSteps[vm.currentStepIndex]
    }

    private var maneuverIcon: String {
        Self.iconForInstruction(currentStep?.instruction ?? "")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Direction icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(vm.isUrgent ? AppTheme.sakuraPink : AppTheme.sakuraPink.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: maneuverIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(vm.isUrgent ? .white : AppTheme.sakuraPink)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.easeInOut(duration: 0.3), value: vm.currentStepIndex)
            }
            .animation(.easeInOut(duration: 0.3), value: vm.isUrgent)

            // Instruction and distance
            VStack(alignment: .leading, spacing: 4) {
                Text(currentStep?.instruction ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: vm.currentStepIndex)
                Text(RoutingService.formatDistance(vm.distanceToNextStep))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(vm.isUrgent ? AppTheme.sakuraPink : .secondary)
                    .animation(.easeInOut(duration: 0.3), value: vm.isUrgent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Dismiss button
            Button {
                vm.stopNavigation()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Завершить навигацию")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous)
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.12 : 0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    // MARK: - Maneuver Icon Mapping

    /// Maps an instruction string to a SF Symbol name.
    static func iconForInstruction(_ instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("налево") || lower.contains("left") {
            return "arrow.turn.up.left"
        } else if lower.contains("направо") || lower.contains("right") {
            return "arrow.turn.up.right"
        } else if lower.contains("разворот") || lower.contains("u-turn") {
            return "arrow.uturn.left"
        } else if lower.contains("слег") && lower.contains("лев") {
            return "arrow.up.left"
        } else if lower.contains("слег") && lower.contains("прав") {
            return "arrow.up.right"
        } else if lower.contains("пункт") || lower.contains("прибыт") || lower.contains("destination") {
            return "mappin.circle.fill"
        } else {
            return "arrow.up"
        }
    }
}
