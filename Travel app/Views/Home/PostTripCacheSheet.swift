import SwiftUI
import SwiftData

struct PostTripCacheSheet: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacingM) {
                Image(systemName: "bookmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.templeGold)

                Text("ПОЕЗДКА ЗАВЕРШЕНА")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(.primary)

                Text("Очистить кэш ИИ-рекомендаций для этой поездки?")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.spacingL)

                Spacer()

                Button {
                    AICacheManager.shared.clearForTrip(trip.id)
                    dismiss()
                } label: {
                    Text("ОЧИСТИТЬ")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.sakuraPink)
                        .clipShape(Capsule())
                }

                Button {
                    dismiss()
                } label: {
                    Text("ОСТАВИТЬ")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 20)
            }
            .padding(AppTheme.spacingM)
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
