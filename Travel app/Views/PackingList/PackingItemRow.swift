import SwiftUI

struct PackingItemRow: View {
    let item: PackingItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var categoryEnum: PackingCategory {
        PackingCategory(rawValue: item.category) ?? .other
    }

    var body: some View {
        HStack(spacing: AppTheme.spacingS) {
            Button(action: onToggle) {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(item.isPacked ? AppTheme.bambooGreen : .secondary)
            }

            Image(systemName: categoryEnum.systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(item.isPacked ? AppTheme.bambooGreen.opacity(0.6) : AppTheme.sakuraPink)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(item.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(item.isPacked ? .secondary : .primary)
                .strikethrough(item.isPacked, color: AppTheme.bambooGreen.opacity(0.5))

            Spacer()

            if item.quantity > 1 {
                Text("×\(item.quantity)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            if item.isAISuggested {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.indigoPurple.opacity(0.5))
            }
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(
                    (item.isPacked ? AppTheme.bambooGreen : Color.white).opacity(0.15),
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Удалить", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(action: onEdit) {
                Label("Изменить", systemImage: "pencil")
            }
            .tint(AppTheme.templeGold)
        }
    }
}
