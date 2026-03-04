#if !targetEnvironment(simulator)
import SwiftUI
import RealityKit
import ARKit
import CoreLocation

struct ARViewContainer: UIViewRepresentable {
    let targetCoordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)

        let coordinator = context.coordinator
        coordinator.arView = arView
        arView.session.delegate = coordinator

        // Create anchor and arrow entity
        let anchor = AnchorEntity(world: .zero)
        let arrowEntity = coordinator.createArrowEntity()
        anchor.addChild(arrowEntity)
        arView.scene.addAnchor(anchor)
        coordinator.arrowEntity = arrowEntity

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.targetCoordinate = targetCoordinate
    }

    func makeCoordinator() -> ARCoordinator {
        ARCoordinator(targetCoordinate: targetCoordinate)
    }
}
#endif
