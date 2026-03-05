import SwiftUI
import SwiftData

struct JournalEntryCard: View {
    let entry: JournalEntry

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let mood = entry.journalMood

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(mood.emoji)
                    .font(.system(size: 20))
                Text(mood.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(mood.color)
                Spacer()
                Text(timeFormatter.string(from: entry.timestamp))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            if !entry.text.isEmpty {
                Text(entry.text)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
            }

            if let place = entry.place {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10))
                    Text(place.name)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppTheme.oceanBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.oceanBlue.opacity(0.1))
                .clipShape(Capsule())
            }

            if !entry.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entry.photos) { photo in
                            if let uiImage = UIImage(data: photo.thumbnailData ?? photo.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
        .padding(AppTheme.spacingM)
        .padding(.leading, 5)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(alignment: .leading) {
            mood.color
                .frame(width: 5)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: AppTheme.radiusMedium,
                    bottomLeadingRadius: AppTheme.radiusMedium
                ))
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(scheme == .dark ? 0.1 : 0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}
