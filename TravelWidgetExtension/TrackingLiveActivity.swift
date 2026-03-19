import ActivityKit
import SwiftUI
import WidgetKit

struct TrackingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrackingActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        trackingCircle(size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GPS-трекинг")
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                            Text(context.attributes.dayLabel)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                        .frame(width: 70, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        statItem(
                            icon: "mappin.and.ellipse",
                            value: "\(context.state.pointCount)",
                            label: "точек"
                        )
                        statItem(
                            icon: "point.topleft.down.to.point.bottomright.curvepath",
                            value: formatDistance(context.state.distanceMeters),
                            label: "км"
                        )
                        statItem(
                            icon: "clock",
                            value: formatDuration(context.state.elapsedSeconds),
                            label: "время"
                        )
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    pulseDot()
                    Text("GPS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                }
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.green)
                    .frame(width: 52)
            } minimal: {
                Image(systemName: "location.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<TrackingActivityAttributes>) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                trackingCircle(size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("GPS-трекинг активен")
                        .font(.system(size: 15, weight: .bold))
                    Text("\(context.attributes.tripName) — \(context.attributes.dayLabel)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(context.attributes.startedAt, style: .timer)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
            }

            HStack(spacing: 0) {
                statBlock(
                    icon: "mappin.and.ellipse",
                    value: "\(context.state.pointCount)",
                    label: "точек"
                )
                Spacer()
                statBlock(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    value: formatDistance(context.state.distanceMeters),
                    label: "км"
                )
                Spacer()
                statBlock(
                    icon: "clock",
                    value: formatDuration(context.state.elapsedSeconds),
                    label: "время"
                )
            }
        }
        .padding(16)
        .background(.black.opacity(0.4))
        .activityBackgroundTint(.black.opacity(0.25))
    }

    // MARK: - Helpers

    private func trackingCircle(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            Image(systemName: "location.fill")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func pulseDot() -> some View {
        Circle()
            .fill(.green)
            .frame(width: 8, height: 8)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.green.opacity(0.8))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
        }
    }

    private func statBlock(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.green.opacity(0.8))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))м"
        }
        return String(format: "%.1f", meters / 1000)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return String(format: "%d:%02d", h, m)
        }
        return String(format: "%d мин", m)
    }
}
