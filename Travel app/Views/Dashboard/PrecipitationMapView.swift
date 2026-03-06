import SwiftUI
import MapKit

// MARK: - RainViewer Radar Overlay

struct PrecipitationMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D

    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsUserLocation = false
        map.delegate = context.coordinator

        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
        )
        map.setRegion(region, animated: false)

        Task { await loadRadarOverlay(on: map, coordinator: context.coordinator) }

        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    @MainActor
    private func loadRadarOverlay(on map: MKMapView, coordinator: Coordinator) async {
        isLoading = true
        defer { isLoading = false }

        guard let frame = await fetchLatestFrame() else { return }

        let template = "\(frame.host)\(frame.path)/256/{z}/{x}/{y}/6/1_1.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = false
        overlay.tileSize = CGSize(width: 256, height: 256)
        overlay.maximumZ = 7

        coordinator.tileOverlay = overlay
        map.addOverlay(overlay, level: .aboveRoads)
    }

    private func fetchLatestFrame() async -> RadarFrame? {
        guard let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(RainViewerResponse.self, from: data)
            guard let latest = response.radar.past.last else { return nil }
            return RadarFrame(host: response.host, path: latest.path)
        } catch {
            return nil
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var tileOverlay: MKTileOverlay?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tile)
                renderer.alpha = 0.6
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - RainViewer API Models

private struct RainViewerResponse: Codable {
    let host: String
    let radar: RadarData
}

private struct RadarData: Codable {
    let past: [RadarTimestamp]
}

private struct RadarTimestamp: Codable {
    let time: Int
    let path: String
}

private struct RadarFrame {
    let host: String
    let path: String
}
