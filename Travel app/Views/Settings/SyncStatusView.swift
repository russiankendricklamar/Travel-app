import SwiftUI

struct SyncStatusView: View {
    private let syncManager = SyncManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status row
            HStack(spacing: 12) {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let last = syncManager.lastSyncDate {
                        Text("Последняя: \(last, style: .relative) назад")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if syncManager.state == .syncing {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))

            // Manual sync button
            Button {
                Task { await syncManager.forceSync() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.oceanBlue, AppTheme.oceanBlue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                    Text("Синхронизировать")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            }
            .disabled(syncManager.state == .syncing)
        }
    }

    private var statusIcon: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    private var statusColor: Color {
        switch syncManager.state {
        case .idle: return syncManager.lastSyncDate != nil ? AppTheme.bambooGreen : .secondary
        case .syncing: return AppTheme.templeGold
        case .error: return AppTheme.toriiRed
        }
    }

    private var statusText: String {
        switch syncManager.state {
        case .idle: return syncManager.lastSyncDate != nil ? String(localized: "Синхронизировано") : String(localized: "Не синхронизировано")
        case .syncing: return String(localized: "Синхронизация...")
        case .error(let msg): return String(localized: "Ошибка") + ": \(msg)"
        }
    }
}
