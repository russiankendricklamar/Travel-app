import SwiftUI

struct DocumentCard: View {
    let document: TravelDocument
    let onDelete: () -> Void

    @State private var isRevealed = false
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    private var accent: Color {
        (ColorPalette(rawValue: palette) ?? .sakura).accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                    .fill(accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: document.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(document.type.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if document.isExpired {
                        expiryBadge(text: "Истёк", color: AppTheme.toriiRed)
                    } else if document.isExpiringSoon {
                        expiryBadge(text: "<6 мес.", color: AppTheme.templeGold)
                    }
                }

                // Number — masked or revealed
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        isRevealed.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isRevealed ? document.number : document.maskedNumber)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Image(systemName: isRevealed ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                if !document.country.isEmpty {
                    Text(document.country)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Expiry date
            if let expiry = document.expiryDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("до")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(expiry, format: .dateTime.day().month(.abbreviated).year())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(document.isExpired ? AppTheme.toriiRed : (document.isExpiringSoon ? AppTheme.templeGold : .secondary))
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(
                    document.isExpired ? AppTheme.toriiRed.opacity(0.3) :
                    (document.isExpiringSoon ? AppTheme.templeGold.opacity(0.2) : Color.white.opacity(0.15)),
                    lineWidth: 0.5
                )
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = document.number
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

    private func expiryBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }
}
