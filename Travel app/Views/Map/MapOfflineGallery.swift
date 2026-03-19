import SwiftUI
import UIKit

struct MapOfflineGallery: View {
    let snapshots: [(day: TripDay, data: Data)]

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: AppTheme.spacingM) {
                    ForEach(snapshots, id: \.day.id) { item in
                        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                            HStack(spacing: 6) {
                                Image(systemName: "map")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.sakuraPink)
                                Text(item.day.cityName.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("ДЕНЬ \(item.day.sortOrder + 1)")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(.tertiary)
                            }

                            if let uiImage = UIImage(data: item.data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(AppTheme.spacingM)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, 50)
                .padding(.bottom, AppTheme.spacingM)
            }

            Text("ОФЛАЙН")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.toriiRed.opacity(0.85))
                .clipShape(Capsule())
                .padding(.top, 8)
        }
    }
}
