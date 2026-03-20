import SwiftUI
import SwiftData

enum PrecacheState {
    case idle
    case loading
    case done
}

struct OfflinePrecacheButton: View {
    let day: TripDay
    let tripID: UUID
    @Environment(\.modelContext) private var modelContext

    @State private var state: PrecacheState = .idle
    @State private var progress: Double = 0

    private var isOnline: Bool { OfflineCacheManager.shared.isOnline }

    var body: some View {
        Group {
            switch state {
            case .idle:
                idleView
            case .loading:
                loadingView
            case .done:
                doneView
            }
        }
        .onAppear {
            checkCacheStatus()
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 4) {
            Button {
                Task { await startPrecaching() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("ПОДГОТОВИТЬ ОФЛАЙН")
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(AppTheme.sakuraPink.opacity(isOnline ? 1.0 : 0.4))
                )
            }
            .disabled(!isOnline)

            if !isOnline {
                Text("Недоступно без сети")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AppTheme.sakuraPink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.sakuraPink)
            }
            .frame(width: 44, height: 44)

            Text("Загрузка маршрутов...")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Done State

    private var doneView: some View {
        Button {
            // Re-trigger precache (refresh)
            state = .idle
            Task { await startPrecaching() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .transition(.scale.combined(with: .opacity))
                Text("МАРШРУТЫ ГОТОВЫ")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(AppTheme.bambooGreen)
            )
        }
    }

    // MARK: - Actions

    private func startPrecaching() async {
        withAnimation(.easeInOut(duration: 0.2)) { state = .loading }
        progress = 0

        await OfflineCacheManager.shared.preCacheDay(
            day,
            tripID: tripID,
            context: modelContext,
            progress: { newProgress in
                self.progress = newProgress
            }
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            state = .done
        }
    }

    private func checkCacheStatus() {
        if RoutingCacheService.shared.isDayCached(day, tripID: tripID, context: modelContext) {
            state = .done
        }
    }
}
