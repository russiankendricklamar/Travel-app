import SwiftUI
import MapKit

@available(iOS 18.0, *)
struct MapItemDetailView: UIViewControllerRepresentable {
    let mapItem: MKMapItem

    func makeUIViewController(context: Context) -> MKMapItemDetailViewController {
        MKMapItemDetailViewController(mapItem: mapItem)
    }

    func updateUIViewController(_ uiViewController: MKMapItemDetailViewController, context: Context) {}
}
