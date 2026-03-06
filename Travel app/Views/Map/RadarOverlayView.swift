import SwiftUI
import MapKit

struct RadarOverlayView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.showsUserLocation = false
        map.backgroundColor = .clear
        map.isOpaque = false
        map.alpha = 0.55
        map.delegate = context.coordinator

        // Hide base map — only show overlay tiles
        if #available(iOS 16.0, *) {
            map.preferredConfiguration = MKStandardMapConfiguration()
            let config = MKStandardMapConfiguration()
            config.showsTraffic = false
            map.preferredConfiguration = config
        }
        // Make base map invisible so only radar shows
        map.overrideUserInterfaceStyle = .light
        map.mapType = .mutedStandard

        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
        )
        map.setRegion(region, animated: false)

        Task { @MainActor in
            await loadFrames(on: map, coordinator: context.coordinator)
        }

        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    @MainActor
    private func loadFrames(on map: MKMapView, coordinator: Coordinator) async {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(RainViewerMapResponse.self, from: data)
            let host = response.host
            let frames = response.radar.past.suffix(6) // last 30 min (6 × 5min)

            let overlays: [MKTileOverlay] = frames.map { frame in
                let template = "\(host)\(frame.path)/256/{z}/{x}/{y}/6/1_1.png"
                let overlay = MKTileOverlay(urlTemplate: template)
                overlay.canReplaceMapContent = false
                overlay.tileSize = CGSize(width: 256, height: 256)
                overlay.maximumZ = 7
                return overlay
            }

            coordinator.frames = overlays
            coordinator.startAnimation(on: map)
        } catch {}
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var frames: [MKTileOverlay] = []
        private var currentIndex = 0
        private var timer: Timer?

        func startAnimation(on map: MKMapView) {
            guard frames.count > 1 else {
                if let first = frames.first {
                    map.addOverlay(first, level: .aboveRoads)
                }
                return
            }

            map.addOverlay(frames[0], level: .aboveRoads)
            currentIndex = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
                guard let self, !self.frames.isEmpty else { return }
                DispatchQueue.main.async {
                    map.removeOverlay(self.frames[self.currentIndex])
                    self.currentIndex = (self.currentIndex + 1) % self.frames.count
                    map.addOverlay(self.frames[self.currentIndex], level: .aboveRoads)
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        deinit {
            timer?.invalidate()
        }
    }
}

// MARK: - API Models

private struct RainViewerMapResponse: Codable {
    let host: String
    let radar: RainViewerRadarData
}

private struct RainViewerRadarData: Codable {
    let past: [RainViewerFrame]
}

private struct RainViewerFrame: Codable {
    let time: Int
    let path: String
}
