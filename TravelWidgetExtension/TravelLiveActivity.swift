import ActivityKit
import SwiftUI
import WidgetKit

struct TravelLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TravelActivityAttributes.self) { context in
            // Lock Screen presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        categoryCircle(icon: context.attributes.categoryIcon)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.eventTitle)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                            Text(context.attributes.eventSubtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startTime...context.attributes.endTime, countsDown: true)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.pink)
                        .frame(width: 70, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.white.opacity(0.15))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [.pink, .pink.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, geo.size.width * context.state.progress), height: 6)
                            }
                        }
                        .frame(height: 6)

                        // Time range
                        HStack {
                            Text(context.attributes.startTime, style: .time)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(context.state.isOngoing ? "Сейчас" : "Скоро")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(context.state.isOngoing ? .pink : .orange)
                            Spacer()
                            Text(context.attributes.endTime, style: .time)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                categoryCircle(icon: context.attributes.categoryIcon, size: 24)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startTime...context.attributes.endTime, countsDown: true)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.pink)
                    .frame(width: 52)
            } minimal: {
                Image(systemName: context.attributes.categoryIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.pink)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<TravelActivityAttributes>) -> some View {
        VStack(spacing: 10) {
            // Header: icon + title + timer
            HStack(spacing: 10) {
                categoryCircle(icon: context.attributes.categoryIcon, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.eventTitle)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                    Text(context.attributes.eventSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Countdown
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timerInterval: context.attributes.startTime...context.attributes.endTime, countsDown: true)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.pink)
                    Text(context.state.isOngoing ? "осталось" : "до начала")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.pink, .pink.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * context.state.progress), height: 8)
                }
            }
            .frame(height: 8)

            // Time range footer
            HStack {
                timeLabel(date: context.attributes.startTime, icon: "play.fill")
                Spacer()
                timeLabel(date: context.attributes.endTime, icon: "stop.fill")
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.black.opacity(0.4))
        .activityBackgroundTint(.black.opacity(0.25))
    }

    // MARK: - Helpers

    private func categoryCircle(icon: String, size: CGFloat = 28) -> some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.pink, .pink.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(Circle())
    }

    private func timeLabel(date: Date, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(date, style: .time)
        }
    }
}
