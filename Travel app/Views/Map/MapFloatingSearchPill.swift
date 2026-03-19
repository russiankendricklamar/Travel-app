import SwiftUI

/// Поисковая таблетка над tab bar (1:1 Apple Maps idle state)
/// Это НЕ текстовое поле — при тапе раскрывает bottom sheet с реальным поиском
struct MapFloatingSearchPill: View {
    @Bindable var vm: MapViewModel
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("Поиск на карте")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
