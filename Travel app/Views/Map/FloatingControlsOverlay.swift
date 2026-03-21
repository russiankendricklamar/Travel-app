import SwiftUI
import MapKit

struct FloatingControlsOverlay: View {
    @Bindable var vm: MapViewModel
    var mapScope: Namespace.ID
    var isOfflineWithCache: Bool

    private var isVisible: Bool {
        vm.sheetDetent == .peek && !vm.isNavigating && !vm.showPrecipitation && !isOfflineWithCache
    }

    var body: some View {
        VStack(spacing: 0) {
            // Native compass — auto-hides when north-facing (D-09)
            MapCompass(scope: mapScope)

            Spacer().frame(height: 8) // D-02: gap between compass and container

            // Blur container with 3 buttons (D-03)
            VStack(spacing: 0) {
                transitButton
                divider
                elevationButton
                divider
                locationButton
            }
            .frame(width: 44)  // D-05
            .background(.ultraThinMaterial)  // D-03
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))  // D-03
            .shadow(color: .black.opacity(0.35), radius: 14, y: 4)  // D-07
            .preferredColorScheme(.dark)
        }
        .padding(.trailing, 16)   // D-36
        .padding(.bottom, 88)     // D-37 resolved to 88pt
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .opacity(isVisible ? 1 : 0)  // D-27
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isVisible)  // D-28
    }

    // MARK: - Transit Button (D-13..17)

    private var transitButton: some View {
        Button {
            vm.showTraffic.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()  // D-17
        } label: {
            Image(systemName: "bus.fill")  // D-13
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(vm.showTraffic ? AppTheme.sakuraPink : .white)  // D-16
                .frame(width: 44, height: 44)  // D-06
        }
        .accessibilityLabel("Транспорт")  // D-34
        .accessibilityHint("Включает или выключает отображение транспортных маршрутов")  // D-35
    }

    // MARK: - Elevation Button (D-18..22)

    private var elevationButton: some View {
        Button {
            vm.show3DElevation.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()  // D-22
        } label: {
            Image(systemName: vm.show3DElevation ? "view.2d" : "view.3d")  // D-19
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(vm.show3DElevation ? AppTheme.sakuraPink : .white)  // D-20
                .frame(width: 44, height: 44)  // D-06
                .contentTransition(.symbolEffect(.replace))  // UI-SPEC icon animation
        }
        .accessibilityLabel("3D вид")  // D-34
        .accessibilityHint("Переключает между плоским и объёмным отображением рельефа")  // D-35
    }

    // MARK: - Location Button (D-23..26)

    private var locationButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()  // D-26
            Task {
                if let loc = await LocationManager.shared.requestCurrentLocation() {
                    withAnimation(.easeInOut(duration: 0.4)) {  // existing pattern TripMapView:158
                        vm.cameraPosition = .region(
                            MKCoordinateRegion(
                                center: loc,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)  // D-24
                            )
                        )
                    }
                }
            }
        } label: {
            Image(systemName: "location")  // D-23: outline, not fill
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)  // D-32: always white, no toggle
                .frame(width: 44, height: 44)  // D-06
        }
        .accessibilityLabel("Моё местоположение")  // D-34
        .accessibilityHint("Центрирует карту на вашем текущем положении")  // D-35
    }

    // MARK: - Divider (D-04)

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(height: 0.5)
            .padding(.horizontal, 8) // slight inset for visual refinement
    }
}
