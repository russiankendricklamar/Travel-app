import SwiftUI

// MARK: - Glass Text Field Style

struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .foregroundStyle(.primary)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
    }
}

// MARK: - Glass Form Field

struct GlassFormField<Content: View>: View {
    let label: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 12)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(color)
            }

            content()
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(color.opacity(0.15), lineWidth: 0.5)
        )
    }
}

// MARK: - Glass Section Header

struct GlassSectionHeader: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 16)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, 10)
    }
}
