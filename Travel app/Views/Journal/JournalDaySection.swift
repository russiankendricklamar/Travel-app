import SwiftUI

struct JournalDaySection: View {
    let day: TripDay

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "d MMMM"
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            Text(dateFormatter.string(from: day.date).uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.primary)

            Text(day.cityName.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(.white)
                .background(AppTheme.oceanBlue)
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 4) {
                Text("\(day.journalEntries.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.indigoPurple)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.indigoPurple.opacity(0.6))
            }
        }
        .padding(.top, AppTheme.spacingS)
    }
}
