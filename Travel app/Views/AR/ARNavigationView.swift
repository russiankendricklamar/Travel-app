import SwiftUI
import CoreLocation

struct ARNavigationView: View {
    let place: Place

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if !targetEnvironment(simulator)
        ZStack {
            ARViewContainer(targetCoordinate: place.coordinate)
                .ignoresSafeArea()

            ARHUDView(place: place)

            // Dismiss button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, AppTheme.spacingM)
                }
                .padding(.top, AppTheme.spacingS)
                Spacer()
            }
        }
        .onAppear {
            ARNavigationManager.shared.startSession(to: place.coordinate)
        }
        .onDisappear {
            ARNavigationManager.shared.stopSession()
        }
        #else
        simulatorPlaceholder
        #endif
    }

    #if targetEnvironment(simulator)
    private var simulatorPlaceholder: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: AppTheme.spacingM) {
                Image(systemName: "arkit")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.sakuraPink)

                Text("AR доступна только на устройстве")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(place.name)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Button {
                    dismiss()
                } label: {
                    Text("Закрыть")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppTheme.spacingL)
                        .padding(.vertical, AppTheme.spacingS)
                        .background(AppTheme.sakuraPink)
                        .clipShape(Capsule())
                }
                .padding(.top, AppTheme.spacingM)
            }
            .padding(AppTheme.spacingXL)
        }
    }
    #endif
}
