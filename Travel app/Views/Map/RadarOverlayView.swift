import SwiftUI
import MapKit

/// Full interactive MKMapView with animated RainViewer radar tiles.
/// Replaces the SwiftUI Map when precipitation mode is on.
struct RadarOverlayView: UIViewRepresentable {
    let places: [Place]
    let initialCenter: CLLocationCoordinate2D?
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.isRotateEnabled = true
        map.isPitchEnabled = true
        map.showsCompass = true
        map.showsScale = true
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Wide region to see precipitation patterns
        if let center = initialCenter {
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            )
            map.setRegion(region, animated: false)
        } else if let first = places.first {
            let region = MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            )
            map.setRegion(region, animated: false)
        }

        // Add place annotations
        let annotations = places.map { PlaceAnnotation(place: $0) }
        map.addAnnotations(annotations)

        // Load radar frames
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
            let frames = response.radar.past.suffix(6)

            let overlays: [MKTileOverlay] = frames.map { frame in
                let template = "\(host)\(frame.path)/256/{z}/{x}/{y}/6/1_1.png"
                let overlay = MKTileOverlay(urlTemplate: template)
                overlay.canReplaceMapContent = false
                overlay.tileSize = CGSize(width: 256, height: 256)
                overlay.maximumZ = 12
                return overlay
            }

            coordinator.allFrames = overlays

            // Add ALL overlays at once — no add/remove later
            for overlay in overlays {
                map.addOverlay(overlay, level: .aboveRoads)
            }

            // Start cycling visibility
            coordinator.startAnimation()
        } catch {}
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var allFrames: [MKTileOverlay] = []
        private var renderers: [ObjectIdentifier: MKTileOverlayRenderer] = [:]
        private var currentIndex = 0
        private var timer: Timer?

        func startAnimation() {
            timer?.invalidate()

            guard allFrames.count > 1 else { return }

            currentIndex = 0
            updateRendererVisibility()

            let newTimer = Timer(timeInterval: 1.2, repeats: true) { [weak self] _ in
                guard let self, !self.allFrames.isEmpty else { return }
                self.currentIndex = (self.currentIndex + 1) % self.allFrames.count
                self.updateRendererVisibility()
            }
            RunLoop.main.add(newTimer, forMode: .common)
            timer = newTimer
        }

        private func updateRendererVisibility() {
            for (i, frame) in allFrames.enumerated() {
                let key = ObjectIdentifier(frame)
                if let renderer = renderers[key] {
                    renderer.alpha = (i == currentIndex) ? 0.7 : 0.0
                }
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tile)
                let key = ObjectIdentifier(tile)
                renderers[key] = renderer

                // First frame visible, rest hidden
                let index = allFrames.firstIndex(where: { ObjectIdentifier($0) == key })
                renderer.alpha = (index == 0) ? 0.7 : 0.0

                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let placeAnnotation = annotation as? PlaceAnnotation else { return nil }

            let identifier = "PlacePin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.canShowCallout = true

            let place = placeAnnotation.place
            let color = UIColor(AppTheme.categoryColor(for: place.category.rawValue))
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            let symbol = UIImage(systemName: place.category.systemImage, withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)

            let size: CGFloat = 32
            let imgRenderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            view.image = imgRenderer.image { ctx in
                let rect = CGRect(x: 0, y: 0, width: size, height: size)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
                color.setFill()
                path.fill()

                UIColor.white.setStroke()
                let strokePath = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 7)
                strokePath.lineWidth = 2
                strokePath.stroke()

                if let symbol {
                    let symbolSize = symbol.size
                    let origin = CGPoint(
                        x: (size - symbolSize.width) / 2,
                        y: (size - symbolSize.height) / 2
                    )
                    symbol.draw(at: origin)
                }
            }

            view.centerOffset = CGPoint(x: 0, y: -size / 2)
            return view
        }

        deinit {
            timer?.invalidate()
        }
    }
}

// MARK: - Place Annotation

private class PlaceAnnotation: NSObject, MKAnnotation {
    let place: Place
    var coordinate: CLLocationCoordinate2D { place.coordinate }
    var title: String? { place.name }

    init(place: Place) {
        self.place = place
        super.init()
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
