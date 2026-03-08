import SwiftUI

struct WizardStepStyle: View {
    @Binding var styles: [TravelStyle]

    var onGenerate: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.spacingS),
        GridItem(.flexible(), spacing: AppTheme.spacingS)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                stepHeader
                styleGrid

                if !styles.isEmpty {
                    selectedBadge
                }

                Spacer(minLength: 40)

                generateButton
            }
            .padding(AppTheme.spacingM)
        }
    }

    // MARK: - Header

    private var stepHeader: some View {
        VStack(spacing: AppTheme.spacingS) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.sakuraPink)
            Text("Стиль поездки")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
            Text("Выберите один или несколько стилей")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.top, AppTheme.spacingXL)
    }

    // MARK: - Style Grid

    private var styleGrid: some View {
        LazyVGrid(columns: columns, spacing: AppTheme.spacingS) {
            ForEach(TravelStyle.allCases) { style in
                let isSelected = styles.contains(style)
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if isSelected {
                            styles.removeAll { $0 == style }
                        } else {
                            styles.append(style)
                        }
                    }
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: style.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(isSelected ? AppTheme.sakuraPink : .secondary)
                        Text(style.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                            .stroke(
                                isSelected ? AppTheme.sakuraPink.opacity(0.5) : Color.white.opacity(0.2),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
                    .shadow(color: isSelected ? AppTheme.sakuraPink.opacity(0.15) : .clear, radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Selected Badge

    private var selectedBadge: some View {
        let labels = styles.map(\.label).joined(separator: ", ")
        return Text(labels)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.sakuraPink)
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, 8)
            .background(AppTheme.sakuraPink.opacity(0.1))
            .clipShape(Capsule())
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            onGenerate()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                Text("СГЕНЕРИРОВАТЬ ПОЕЗДКУ")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .shadow(color: AppTheme.sakuraPink.opacity(0.3), radius: 12, y: 6)
        }
        .disabled(styles.isEmpty)
        .opacity(styles.isEmpty ? 0.4 : 1)
        .padding(.bottom, AppTheme.spacingM)
    }
}
