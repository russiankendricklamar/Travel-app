import SwiftUI

struct LoyaltyCard: View {
    let program: LoyaltyProgram
    let onDelete: () -> Void

    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    private var accent: Color {
        (ColorPalette(rawValue: palette) ?? .sakura).accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                    .fill(AppTheme.indigoPurple.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.indigoPurple)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(program.company)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !program.programName.isEmpty {
                    Text(program.programName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(program.memberNumber)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Tier badge
            if !program.tier.isEmpty {
                Text(program.tier)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.indigoPurple, AppTheme.indigoPurple.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .contextMenu {
            Button {
                UIPasteboard.general.string = program.memberNumber
            } label: {
                Label("Копировать номер", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}
